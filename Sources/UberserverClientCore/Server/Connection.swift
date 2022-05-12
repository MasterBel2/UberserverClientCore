//
//  Connection.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 25/6/19.
//  Copyright © 2019 MasterBel2. All rights reserved.
//

import Foundation
import ServerAddress

public protocol ReceivesConnectionUpdates {
    /// Indicates that the server has sent information about its protocol, which may be used to determine available features.
    func connection(_ connection: ThreadUnsafeConnection, willUseCommandProtocolWithFeatureAvailability availability: ProtocolFeatureAvailability)

    /// Indicates the connectioon has ended communication with the server.
    func connectionDidDisconnect(_ connection: ThreadUnsafeConnection)

    /// Indicates the connection has become authenticated with the server, and provides
    /// an `AuthenticatedClient` object that will describe the server's state.
    func connection(_ connection: ThreadUnsafeConnection, didBecomeAuthenticated authenticatedClient: AuthenticatedSession)
    /// Indicates the connection is no longer authenticated with the server, and will no longer
    /// receive information about its state.
    func connectionDidBecomeUnauthenticated(_ connection: ThreadUnsafeConnection)

    /// Indicates the interval since the last Ping and its responding Pong, in microseconds.
    func connection(_ connection: ThreadUnsafeConnection, didReceivePongAfter delay: Int)
}

public extension ReceivesConnectionUpdates {
    func connection(_ connection: ThreadUnsafeConnection, willUseCommandProtocolWithFeatureAvailability availability: ProtocolFeatureAvailability) {}
    
    func connectionDidDisconnect(_ connection: ThreadUnsafeConnection) {}

    func connection(_ connection: ThreadUnsafeConnection, didBecomeAuthenticated authenticatedClient: AuthenticatedSession) {}
    func connection(_ connection: ThreadUnsafeConnection, didBecomeUnauthenticated unauthenticatedClient: UnauthenticatedSession) {}

    func connection(_ connection: ThreadUnsafeConnection, didReceivePongAfter delay: Int) {}
}

public typealias ThreadUnsafeConnection = Connection._Connection

/// Handles the socket connection to a lobbyserver.
///
/// Lobbyserver protocol is described at http://springrts.com/dl/LobbyProtocol
/// See here for an implementation in C++ https://github.com/cleanrock/flobby/tree/master/src/model
public final class Connection: SocketDelegate {

    /// Stores state relating to the authenticated/unauthenticated session with the server.
    public var session: Session {
        get {
            return _connection.sync(block: { return $0.session })
        }
        set {
            _connection.sync(block: { $0.session = newValue })
        }
    }

    var specificCommandHandlers: [Int : (SCCommand) -> Bool] {
        get {
            return _connection.sync(block: { return $0.specificCommandHandlers })
        }
        set {
            _connection.sync(block: { $0.specificCommandHandlers = newValue })
        }
    }

    public private(set) var featureAvailability: ProtocolFeatureAvailability? {
        get {
            return _connection.sync(block: { return $0.featureAvailability })
        }
        set {
            _connection.sync(block: { $0.featureAvailability = newValue })
        }
    }

    /**
     Contains the state for `Connection`, such that it can be forced to operate on a single thread.

     If you need to store a reference to `_Connection`, make sure it is `ThreadLocked`.
     */
    public class _Connection: UpdateNotifier {

        init(queue: DispatchQueue, socket: Socket, defaultProtocol: ServerProtocol, client: Client, resourceManager: ResourceManager, cacheDirectory: URL, preferencesController: PreferencesController) {
            self.queue = queue
            self.socket = socket
            self.client = client
            self.resourceManager = resourceManager
            self.cacheDirectory = cacheDirectory

            let unauthenticatedSession = UnauthenticatedSession(preferencesController: preferencesController)
            self.session = .unauthenticated(unauthenticatedSession)
            unauthenticatedSession.connection = MakeUnownedQueueLocked(lockedObject: self, queue: queue)

            setProtocol(defaultProtocol)
        }

        deinit {
            socket.close()
        }

        /// Stores state relating to the authenticated/unauthenticated session with the server.
        public internal(set) var session: Session {
            didSet {
                switch session {
                case let .authenticated(session):
                    applyActionToChainedObjects({ $0.connection(self, didBecomeAuthenticated: session) })
                case let .unauthenticated(session):
                    applyActionToChainedObjects({ $0.connection(self, didBecomeUnauthenticated: session) })
                }
            }
        }

        // MARK: - Cache

        /// The directory where all cache information associated with the connected server should be written.
        public let cacheDirectory: URL

        // MARK: - Update Notifier

        public var objectsWithLinkedActions: [() -> ReceivesConnectionUpdates?] = []

        // MARK: - Dependencies

        /// The client that owns this connection.
        private unowned var client: Client
        /// The resource manager providing resource information to this connection.
        let resourceManager: ResourceManager

        // MARK: - Thread-safety

        /// _Connection is queue-locked on the queue. Use this only for async calls.
        public let queue: DispatchQueue

        // MARK: - Socket connection

        /// The socket that connects to the remote server.
        let socket: Socket

        /// The ID of the next message to be sent to the server, corresponding to the number of messages previously sent.
        private var idOfNextCommand = 0

        /// Sends a command to the connected server.
        ///
        /// The command's specificHandler will
        public func send(_ command: CSCommand, specificHandler: ((SCCommand) -> (Bool))? = nil) {
            cancelPing()
            schedulePing()

            Logger.log("Sending: #\(idOfNextCommand) " + command.description, tag: .General)

            specificCommandHandlers[idOfNextCommand] = specificHandler
            socket.send(message: "#\(idOfNextCommand) \(command.description)\n")

            idOfNextCommand += 1
        }

        /// The time the last ping was received, in microseconds.
        public private(set) var lastPingTime: Int?

        func setLastPingTime(_ pingTime: Int) {
            lastPingTime = pingTime
            applyActionToChainedObjects({ $0.connection(self, didReceivePongAfter: pingTime) })
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
            queue.asyncAfter(deadline: DispatchTime.now() + DispatchTimeInterval.seconds(30), execute: workItem)
        }

        /// Cancels the next ping operation.
        private func cancelPing() {
            currentPingWorkItem?.cancel()
        }

        /// A dictionary specifying which commands will be processed.
        private var incomingCommands: [String : SCCommand.Type] = [:]

        /// Blocks to be executed when a command with a specific ID is received. Return true if the expected response has been received.
        ///
        /// internal access provided due to a current bug where command IDs don't properly register the "ACCEPTED"/"DENIED" commands, see `SCLoginAcceptedCommand.execute(on:)` and `SCLoginDeniedCommand.execute(on:)`.
        var specificCommandHandlers: [Int : (SCCommand) -> (Bool)] = [:]


        private var previousTail = ""
        /// A message was received over the socket.
        func socket(_ socket: Socket, didReceive message: String) {

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
                      let recognisedCommand = incomingCommands[components[commandIndex].uppercased()],
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

        func socket(_ socket: Socket, didFailWithError error: Error?) {
            applyActionToChainedObjects({ $0.connectionDidDisconnect(self) })
        }

        func redirect(to newAddress: ServerAddress) {
            client.redirect(to: newAddress)
        }

        // MARK: - Protocol

        /// Describes the features available with the connected server.
        var featureAvailability: ProtocolFeatureAvailability?

        /// Sets a protocol that has been identified such that following commands may be processed.
        func setProtocol(_ serverProtocol: ServerProtocol) {
            let featureAvailability = ProtocolFeatureAvailability(serverProtocol: serverProtocol)

            switch serverProtocol {
            case .unknown:
                incomingCommands = Connection.protocolInfoCommands
            case .tasServer:
                incomingCommands = Connection.tasServerSCCommands
            default:
                break
            }

            applyActionToChainedObjects({ $0.connection(self, willUseCommandProtocolWithFeatureAvailability: featureAvailability) })

            self.featureAvailability = featureAvailability
        }
    }

    public let _connection: QueueLocked<_Connection>

    // MARK: - Connection Properties

    /// The address the client is connected to.
    public var address: ServerAddress {
        return _connection.sync(block: { return $0.socket.address })
    }

    /// A directory in which the client associated with this connection may store information relating to the server it is connected to.
    public let cacheDirectory: URL

    // MARK: - Lifecycle

    /// Initialiser for the TASServer object.
    ///
    /// - parameter address: The IP address or domain name of the server, along with the port it should connect on.
    /// - parameter defaultProtocol: The protocol the connection will assume the server will communicate with. Use `.unknown` for the client to detect the protocol.
    init?(address: ServerAddress, client: Client, resourceManager: ResourceManager, preferencesController: PreferencesController, baseCacheDirectory: URL, defaultProtocol: ServerProtocol = .unknown) {
        guard let socket = Socket(address: address) else {
            return nil
        }

        let queue = DispatchQueue(label: "com.believeandrise.connection", qos: .userInteractive, target: DispatchQueue.global(qos: .userInteractive))

        let _connection = _Connection(
            queue: queue,
            socket: socket,
            defaultProtocol: defaultProtocol,
            client: client,
            resourceManager: resourceManager,
            cacheDirectory: baseCacheDirectory.appendingPathComponent(address.description),
            preferencesController: preferencesController
        )

        self._connection = QueueLocked(
            lockedObject: _connection,
            queue: queue
        )

        self.cacheDirectory = baseCacheDirectory.appendingPathComponent(address.description)

        socket.delegate = self
        socket.open()
    }

    // MARK: - Handling Messages

    /// Sends an encoded command over the socket and delays the keepalive to avoid sending superfluous messages to the server.
    ///
    /// Command handlers should not contain any strong references to objects in the case a command is never responded to.
    public func send(_ command: CSCommand, specificHandler: ((SCCommand) -> (Bool))? = nil) {
        _connection.async(block: { $0.send(command, specificHandler: specificHandler) })
    }

    // MARK: - Socket Events

    /// A message was received over the socket.
    func socket(_ socket: Socket, didReceive message: String) {
        _connection.async(block: { $0.socket(socket, didReceive: message)})
    }

    /// The socket will no longer receive information from the server.
    func socket(_ socket: Socket, didFailWithError error: Error?) {
        _connection.async(block: { $0.socket(socket, didFailWithError: error) })
    }

    // MARK: - Session

    /// States the possible sessions that may be maintained with the server.
    public enum Session {
        case authenticated(AuthenticatedSession)
        case unauthenticated(UnauthenticatedSession)
    }

    // MARK: - Server Protocol

    /// Identifies a protocol that the command handler can handle.
    enum ServerProtocol {
        case unknown
        case tasServer(version: Float)
        case zeroKServer
    }

    private static let protocolInfoCommands: [String : SCCommand.Type] = [
        "TASSERVER" : TASServerCommand.self
    ]

    /// A set of commands expected to be received when using the TASServer protocol.
    private static let tasServerSCCommands: [String : SCCommand.Type] = {
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
