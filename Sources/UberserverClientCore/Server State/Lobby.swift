//
//  Lobby.swift
//  UberserverClientCore
//
//  Created by MasterBel2 on 15/5/2022.
//

import Foundation

public protocol Lobby {
    func connection(_ connection: ThreadUnsafeConnection, didReceive message: Data)
}

final public class TachyonLobby: Lobby {
    public func connection(_ connection: ThreadUnsafeConnection, didReceive message: Data) {}
}


public protocol ReceivesTASServerLobbyUpdates {
    /// Indicates that the server has sent information about its protocol, which may be used to determine available features.
    func lobby(_ lobby: TASServerLobby, willUseCommandProtocolWithFeatureAvailability availability: ProtocolFeatureAvailability)
    /// Indicates the connection has become authenticated with the server, and provides
    /// an `AuthenticatedSession` object that will describe the server's state.
    func lobby(_ lobby: TASServerLobby, didBecomeAuthenticated authenticatedSession: AuthenticatedSession)
    /// Indicates the connection is no longer authenticated with the server, and will no longer
    /// receive information about its state.
    func lobby(_ lobby: TASServerLobby, didBecomeUnauthenticated unauthenticatedSession: UnauthenticatedSession)
    /// Indicates the connection has begun authentication with the server, but requires further confirmation
    /// befure full authentication is completed.
    func lobby(_ lobby: TASServerLobby, didBecomePreAgreement preAgreementSession: PreAgreementSession)

    /// Indicates the interval since the last Ping and its responding Pong, in microseconds.
    func lobby(_ lobby: TASServerLobby, didReceivePongAfter delay: Int)
}
final public class TASServerLobby: Lobby, UpdateNotifier {
    public var objectsWithLinkedActions: [() -> ReceivesTASServerLobbyUpdates?] = []

    unowned public internal(set) var connection: ThreadUnsafeConnection

    /// The ID of the next message to be sent to the server, corresponding to the number of messages previously sent.
    private var idOfNextCommand = 0

    /// Sends a command to the connected server.
    ///
    /// The command's specificHandler will
    public func send(_ command: CSCommand, specificHandler: ((SCCommand) -> (Bool))? = nil) {
        guard let data = "#\(idOfNextCommand) \(command.description)\n".data(using: .utf8) else {
            return
        }
        cancelPing()
        schedulePing()

        Logger.log("Sending: #\(idOfNextCommand) " + command.description, tag: .General)

        specificCommandHandlers[idOfNextCommand] = specificHandler

        connection.socket.send(message: data)

        idOfNextCommand += 1
    }

    /// The time the last ping was received, in microseconds.
    public private(set) var lastPingTime: Int?

    func setLastPingTime(_ pingTime: Int) {
        lastPingTime = pingTime
        applyActionToChainedObjects({ $0.lobby(self, didReceivePongAfter: pingTime) })
    }

    private(set) var pingTimer = Timer()

    private var currentPingWorkItem: DispatchWorkItem?

    /// Sends a keepalive message and queues the next.
    private func schedulePing() {
        let workItem = DispatchWorkItem(qos: .utility, flags: .enforceQoS, block: { [weak self] in
            guard let self = self else { return }
            self.pingTimer = Timer()
            self.send(CSPingCommand(), specificHandler: { [weak self] response in
                guard let self = self else { return true }
                if response is SCPongCommand {
                    self.setLastPingTime(self.pingTimer.intervalFromStart)
                    return true
                }
                return false
            })
            self.schedulePing()
        })
        currentPingWorkItem = workItem
        // A delay of 30 seconds is reccomended by TASServer documentation.
        // After 60 seconds the server will terminate the connection.
        connection.queue.asyncAfter(deadline: DispatchTime.now() + DispatchTimeInterval.seconds(30), execute: workItem)
    }

    /// Cancels the next ping operation.
    private func cancelPing() {
        currentPingWorkItem?.cancel()
    }

    private var previousTail = ""

    public func connection(_ connection: ThreadUnsafeConnection, didReceive data: Data) {
        guard let message = String(data: data, encoding: .utf8) else {
            return
        }

        // Input may be split over multiple input rounds, so if we don't have a newline, assume there's more to come!
        var messages = (previousTail + message).components(separatedBy: "\n")
        guard messages.count > 0 else { return }
        previousTail = messages.removeLast()

        for message in messages where message != "" {
            Logger.log("Received: " + message, tag: .General)
            let components = message.components(separatedBy: " ")
            let messageID = components.first.flatMap({ (id: String) -> Int? in
                if id.first == "#" {
                    return Int(id.dropFirst())
                } else {
                    return nil
                }
            })

            let commandIndex = (messageID != nil) ? 1 : 0
            let payload = components.dropFirst(1 + commandIndex).joined(separator: " ")

            guard components.count >= (commandIndex + 1),
                  let recognisedCommand = TASServerLobby.incomingCommands[components[commandIndex].uppercased()],
                  let command = recognisedCommand.init(payload: payload) else {
                      Logger.log("Failed to decode command", tag: .ServerError)
                      continue
                  }

            if let messageID = messageID {
                if let specificHandler = specificCommandHandlers[messageID],
                   specificHandler(command) {
                    specificCommandHandlers.removeValue(forKey: messageID)
                }
            }
            command.execute(on: self)
        }
    }

    /// Describes the features available with the connected server.
    var featureAvailability: ProtocolFeatureAvailability?

    init(queue: DispatchQueue, preferencesController: PreferencesController, connection: ThreadUnsafeConnection) {
        self.connection = connection

        let unauthenticatedSession = UnauthenticatedSession(preferencesController: preferencesController)

        unauthenticatedSession.lobby = MakeUnownedQueueLocked(lockedObject: self, queue: connection.queue)
        self.session = .unauthenticated(unauthenticatedSession)
    }

    /// States the possible sessions that may be maintained with the server.
    public enum Session {
        case authenticated(AuthenticatedSession)
        case preAgreement(PreAgreementSession)
        case unauthenticated(UnauthenticatedSession)
    }

    /// Blocks to be executed when a command with a specific ID is received. Return true if the expected response has been received.
    ///
    /// internal access provided due to a current bug where command IDs don't properly register the "ACCEPTED"/"DENIED" commands, see `SCLoginAcceptedCommand.execute(on:)` and `SCLoginDeniedCommand.execute(on:)`.
    var specificCommandHandlers: [Int : (SCCommand) -> (Bool)] = [:]

    /// Stores state relating to the authenticated/unauthenticated session with the server.
    public internal(set) var session: Session! {
        didSet {
            switch session {
            case let .authenticated(session):
                applyActionToChainedObjects({ $0.lobby(self, didBecomeAuthenticated: session) })
            case let .unauthenticated(session):
                applyActionToChainedObjects({ $0.lobby(self, didBecomeUnauthenticated: session) })
            case let .preAgreement(session):
                applyActionToChainedObjects({ $0.lobby(self, didBecomePreAgreement: session) })
            case .none:
                fatalError()
            }
        }
    }

    // MARK: - Protocol

    /// Sets a protocol that has been identified such that following commands may be processed.
    func setVersion(_ protocolVersion: String) {
        let protocolFloat: Float

        if let version = Float(String(protocolVersion.prefix(while: { "0.123456789".contains($0) }))) {
            protocolFloat = version
        } else {
            // Default to latest available version
            protocolFloat = 0.38
        }

        let featureAvailability = ProtocolFeatureAvailability(serverProtocol: .tasServer(version: protocolFloat))

        applyActionToChainedObjects({ $0.lobby(self, willUseCommandProtocolWithFeatureAvailability: featureAvailability) })

        self.featureAvailability = featureAvailability
    }

    /// A set of commands expected to be received when using the TASServer protocol.
    private static let incomingCommands: [String : SCCommand.Type] = {
        var dict: [String : SCCommand.Type] = [:]
        [
            TASServerCommand.self,
            SCRedirectCommand.self,
            MOTDCommand.self,
            SCServerMessageCommand.self,
            SCServerMessageBoxCommand.self,
            SCCompFlagsCommand.self,
            SCFailedCommand.self,
            SCJSONCommand.self,
            SCPongCommand.self,
            SCOKCommand.self,

            // Interaction commands
            SCRingCommand.self,
            SCIgnoreCommand.self,
            SCUnignoreCommand.self,
            SCIgnoreListCommand.self,
            SCCIgnoreListEndCommand.self,

            // Account commands
            SCLoginAcceptedCommand.self,
            SCLoginDeniedCommand.self,
            SCLoginInfoEndCommand.self,
            SCRegistrationDeniedCommand.self,
            SCRegistrationAcceptedCommand.self,
            SCAgreementCommand.self,
            SCAgreementEndCommand.self,
            SCChangeEmailRequestAcceptedCommand.self,
            SCChangeEmailRequestDeniedCommand.self,
            SCChangeEmailAcceptedCommand.self,
            SCChangeEmailDeniedCommand.self,
            SCResendVerificationAcceptedCommand.self,
            SCResendVerificationDeniedCommand.self,
            SCResetPasswordRequestAcceptedCommand.self,
            SCResetPasswordRequestDeniedCommand.self,
            SCResetPasswordAcceptedCommand.self,
            SCResetPasswordDeniedCommand.self,

            // User commands
            SCAddUserCommand.self,
            SCRemoveUserCommand.self,
            SCClientStatusCommand.self,

            // Client bridging commands
            SCBridgeClientFromCommand.self,
            SCUnbridgeClientFromCommand.self,
            SCJoinedFromCommand.self,
            SCLeftFromCommand.self,
            SCSaidFromCommand.self,
            SCClientsFromCommand.self,

            // Channel commands
            SCJoinCommand.self,
            SCJoinedCommand.self,
            SCJoinFailedCommand.self,
            SCClientsCommand.self,
            SCChannelTopicCommand.self,
            SCChannelMessageCommand.self,
            SCSaidCommand.self,
            SCSaidExCommand.self,
            SCChannelCommand.self,
            SCEndOfChannelsCommand.self,

            // Private Message Commands
            SCSayPrivateCommand.self,
            SCSayPrivateEXCommand.self,
            SCSaidPrivateCommand.self,
            SCSaidPrivateEXCommand.self,

            // Battle commands
            SCBattleOpenedCommand.self,
            SCBattleClosedCommand.self,
            SCJoinedBattleCommand.self,
            SCLeftBattleCommand.self,
            SCJoinBattleCommand.self,
            SCJoinBattleFailedCommand.self,
            SCForceQuitBattleCommand.self,
            SCClientBattleStatusCommand.self,
            // Commented out, since we do not respond to this command.
            // Since we know when we've joined a battle, we don't need to
            // send our status.
            //                "REQUESTBATTLESTATUS" : SCRequestBattleStatusCommand.self,
            SCUpdateBattleInfoCommand.self,
            SCAddBotCommand.self,
            SCRemoveBotCommand.self,
            SCAddStartRectCommand.self,
            SCRemoveStartRectCommand.self,
            SCSetScriptTagsCommand.self,
            SCRemoveScriptTagsCommand.self,
            SCDisableUnitsCommand.self,
            SCEnableUnitsCommand.self,

            SCHostPortCommand.self,
            SCUDPSourcePortCommand.self,

            // Hosting commands
            SCOpenBattleCommand.self,
            SCOpenBattleFailedCommand.self,
            SCJoinBattleRequestCommand.self,
            SCClientIPPortCommand.self,
            SCKickFromBattleCommand.self,
        ].forEach({ dict[$0.title] = $0 })

        return dict
    }()
}

final public class UnknownLobby: Lobby {
    public init() {}

    public func connection(_ connection: ThreadUnsafeConnection, didReceive data: Data) {
        guard let line = String(data: data, encoding: .utf8) else { return }

        if let first = line.firstIndex(of: " "),
           line[..<first] == TASServerCommand.title {
            let command = TASServerCommand(payload: String(line.suffix(from: line.index(after: first))))
        }
    }
}
