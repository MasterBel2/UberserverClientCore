//
//  TASServer.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 25/6/19.
//  Copyright © 2019 MasterBel2. All rights reserved.
//

import Foundation
import ServerAddress

/// Handles the socket connection to a TASServer.
///
/// Lobbyserver protocol is described at http://springrts.com/dl/LobbyProtocol
/// See here for an implementation in C++ https://github.com/cleanrock/flobby/tree/master/src/model
public final class TASServer: NSObject, SocketDelegate {

    // MARK: - Associated Objects

    /// The TASServer's delegate object.
    private unowned var client: Client

    // MARK: - Command handling

    /// A dictionary specifying data structures relating to the server commands that the command handler will handle.
    private var incomingCommands: [String : SCCommand.Type] = [:]
    /// Blocks to be executed when a command with a specific ID is received.
    ///
    /// internal access provided due to a current bug where command IDs don't properly register the "ACCEPTED"/"DENIED" commands, see `SCLoginAcceptedCommand.execute(on:)` and `SCLoginDeniedCommand.execute(on:)`.
    var specificCommandHandlers: [Int : (SCCommand) -> ()] = [:]

    // MARK: - Connection Properties

    /// The socket that connects to the remote server.
    private(set) var socket: Socket
    /// The delay after which the keepalive "PING" should be sent in order to maintain the server connection.
    /// A delay of 30 seconds is reccomended by TASServer documentation.
    static let keepaliveDelay: TimeInterval = 30

    // MARK: - Lifecycle

    /// Initialiser for the TASServer object.
    ///
    /// - parameter address: The IP address or domain name of the server.
    /// - parameter port: The port on which the socket should connect.
    init(address: ServerAddress, client: Client, defaultProtocol: ServerProtocol = .unknown) {
        socket = Socket(address: address)
        self.client = client
        super.init()

        socket.delegate = self
        setProtocol(defaultProtocol)
    }

    // MARK: - TASServing

    /// Initiates the socket connection and begins the keepalive loop.
    func connect() {
        socket.connect()
        perform(#selector(TASServer.sendPing), with: nil, afterDelay: 30)
    }

    /// Terminates the connection to the server, and with it the keepalive loop.
    func disconnect() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(TASServer.sendPing), object: nil)
        socket.disconnect()
    }

    /// Closes the connection to one server, and connects to the new address
    func redirect(to serverAddress: ServerAddress, defaultProtocol: ServerProtocol = .unknown) {
        disconnect()
        socket = Socket(address: serverAddress)
        socket.delegate = self
        setProtocol(defaultProtocol)
        connect()
    }

    /// The ID of the next message to be sent to the server, corresponding to the number of messages previously sent.
    private var count = 0
    /// Sends an encoded command over the socket and delays the keepalive to avoid sending superfluous messages to the server.
    ///
    /// Command handlers should not contain any strong references to objects in the case a command is never responded to.
    public func send(_ command: CSCommand, specificHandler: ((SCCommand) -> ())? = nil) {
        Logger.log("Sending: " + command.description, tag: .General)
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(TASServer.sendPing), object: nil)

        specificCommandHandlers[count] = specificHandler
        socket.send(message: "#\(count) \(command.description)\n")

        perform(#selector(TASServer.sendPing), with: nil, afterDelay: TASServer.keepaliveDelay)

        count += 1
    }

    // MARK: - SocketDelegate

    /// A message was received over the socket.
    func socket(_ socket: Socket, didReceive message: String) {
        let messages = message.components(separatedBy: "\n")

        for message in messages {
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
            let description = components.dropFirst(1 + commandIndex).joined(separator: " ")
            guard components.count > (commandIndex + 1),
                  let recognisedCommand = incomingCommands[components[commandIndex].uppercased()],
                  let command = recognisedCommand.init(description: description) else {
                Logger.log("Failed to decode command", tag: .ServerError)
                continue
            }
            if let messageID = messageID {
                specificCommandHandlers[messageID]?(command)
                specificCommandHandlers.removeValue(forKey: messageID)
            }
            command.execute(on: client)
        }
    }

    func socketDidClose(_ socket: Socket) {
        client.reset()
        setProtocol(.unknown)
    }

    /// Identifies a protocol that the command handler can handle.
    enum ServerProtocol {
        case unknown
        case tasServer(version: Float)
        case zeroKServer
    }

    /// Sets a protocol that has been identified such that following commands may be processed.
    func setProtocol(_ serverProtocol: ServerProtocol) {
        switch serverProtocol {
        case .unknown:
            incomingCommands = [
                "TASSERVER" : TASServerCommand.self
            ]
        case .tasServer(_):
            incomingCommands = [
                "TASSERVER" : TASServerCommand.self,
                "REDIRECT" : SCRedirectCommand.self,
                "MOTD" : MOTDCommand.self,
                "SERVERMSG" : SCServerMessageCommand.self,
                "SERVERMSGBOX" : SCServerMessageBoxCommand.self,
                "COMPFLAGS" : SCCompFlagsCommand.self,
                "FAILED" : SCFailedCommand.self,
                "JSON" : SCJSONCommand.self,
                "PONG" : SCPongCommand.self,
                "OK" : SCOKCommand.self,

                // Interaction commands
                "RING" : SCRingCommand.self,
                "IGNORE" : SCIgnoreCommand.self,
                "UNIGNORE" : SCUnignoreCommand.self,
                "IGNORELIST" : SCIgnoreListCommand.self,
                "IGNORELISTEND" : SCCIgnoreListEndCommand.self,

                // Account commands
                "ACCEPTED" : SCLoginAcceptedCommand.self,
                "DENIED" : SCLoginDeniedCommand.self,
                "LOGININFOEND" : SCLoginInfoEndCommand.self,
                "REGISTRATIONDENIED" : SCRegistrationDeniedCommand.self,
                "REGISTRATIONACCEPTED" : SCRegistrationAcceptedCommand.self,
                "AGREEMENT" : SCAgreementCommand.self,
                "AGREEMENTEND" : SCAgreementEndCommand.self,
                "CHANGEEMAILREQUESTACCEPTED" : SCChangeEmailRequestAcceptedCommand.self,
                "CHANGEEMAILREQUESTDENIED" : SCChangeEmailRequestDeniedCommand.self,
                "CHANGEEMAILACCEPTED" : SCChangeEmailAcceptedCommand.self,
                "CHANGEEMAILDENIED" : SCChangeEmailDeniedCommand.self,
                "RESENDVERIFICATIONACCEPTED" : SCResendVerificationAcceptedCommand.self,
                "RESENDVERIFICATIONDENIED" : SCResendVerificationDeniedCommand.self,
                "RESETPASSWORDREQUESTACCEPTED" : SCResetPasswordRequestAcceptedCommand.self,
                "RESETPASSWORDREQUESTDENIED" : SCResetPasswordRequestDeniedCommand.self,
                "RESETPASSWORDACCEPTED" : SCResetPasswordAcceptedCommand.self,
                "RESETPASSWORDDENIED" : SCResetPasswordDeniedCommand.self,

                // User commands
                "ADDUSER" : SCAddUserCommand.self,
                "REMOVEUSER" : SCRemoveUserCommand.self,
                "CLIENTSTATUS" : SCClientStatusCommand.self,

                // Client bridging commands
                "BRIDGECLIENTFROM" : SCBridgeClientFromCommand.self,
                "UNBRIDGECLIENTFROM" : SCUnbridgeClientFromCommand.self,
                "JOINEDFROM" : SCJoinedFromCommand.self,
                "LEFTFROM" : SCLeftFromCommand.self,
                "SAIDFROM" : SCSaidFromCommand.self,
                "CLIENTSFROM" : SCClientsFromCommand.self,

                // Channel commands
                "JOIN" : SCJoinCommand.self,
                "JOINED" : SCJoinedCommand.self,
                "JOINFAILED" : SCJoinFailedCommand.self,
                "CLIENTS" : SCClientsCommand.self,
                "CHANNELTOPIC" : SCChannelTopicCommand.self,
                "CHANNELMESSAGE" : SCChannelMessageCommand.self,
                "SAID" : SCSaidCommand.self,
                "SAIDEX" : SCSaidExCommand.self,
                "CHANNEL" : SCChannelCommand.self,
                "ENDOFCHANNELS" : SCEndOfChannelsCommand.self,

                // Private Message Commands
                "SAYPRIVATE" : SCSayPrivateCommand.self,
                "SAYPRIVATEEX" : SCSayPrivateEXCommand.self,
                "SAIDPRIVATE" : SCSaidPrivateCommand.self,
                "SAIDPRIVATEEX" : SCSaidPrivateEXCommand.self,

                // Battle commands
                "BATTLEOPENED" : SCBattleOpenedCommand.self,
                "BATTLECLOSED" : SCBattleClosedCommand.self,
                "JOINEDBATTLE" : SCJoinedBattleCommand.self,
                "LEFTBATTLE" : SCLeftBattleCommand.self,
                "JOINBATTLE" : SCJoinBattleCommand.self,
                "JOINBATTLEFAILED" : SCJoinBattleFailedCommand.self,
                "FORCEQUITBATTLE" : SCForceQuitBattleCommand.self,
                "CLIENTBATTLESTATUS" : SCClientBattleStatusCommand.self,
                // Commented out, since we do not respond to this command.
                // Since we know when we've joined a battle, we don't need to
                // send our status.
//                "REQUESTBATTLESTATUS" : SCRequestBattleStatusCommand.self,
                "UPDATEBATTLEINFO" : SCUpdateBattleInfoCommand.self,
                "ADDBOT" : SCAddBotCommand.self,
                "REMOVEBOT" : SCRemoveBotCommand.self,
                "ADDSTARTRECT" : SCAddStartRectCommand.self,
                "REMOVESTARTRECT" : SCRemoveStartRectCommand.self,
                "SETSCRIPTTAGS" : SCSetScriptTagsCommand.self,
                "REMOVESCRIPTTAGS" : SCRemoveScriptTagsCommand.self,
                "DISABLEUNITS" : SCDisableUnitsCommand.self,
                "ENABLEUNITS" : SCEnableUnitsCommand.self,

                "HOSTPORT" : SCHostPortCommand.self,
                "UDPSOURCEPORT" : SCUDPSourcePortCommand.self,

                // Hosting commands
                "OPENBATTLE" : SCOpenBattleCommand.self,
                "OPENBATTLEFAILED" : SCOpenBattleFailedCommand.self,
                "JOINBATTLEREQUEST" : SCJoinBattleRequestCommand.self,
                "CLIENTIPPORT" : SCClientIPPortCommand.self,
                "KICKFROMBATTLE" : SCKickFromBattleCommand.self,
            ]
        default:
            break
        }
    }

    // MARK: - Helper functions

    /// Sends a keepalive message and queues the next.
    @objc private func sendPing() {
        socket.send(message: "PING\n")
        perform(#selector(TASServer.sendPing), with: nil, afterDelay: TASServer.keepaliveDelay)
    }
}
