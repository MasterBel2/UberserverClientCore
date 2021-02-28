//
//  Connection.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 25/6/19.
//  Copyright © 2019 MasterBel2. All rights reserved.
//

import Foundation
import ServerAddress

public protocol ReceivesTASServerUpdates {
    /// Indicates that the server has sent information about its protocol, which may be used to determine available features.
    func connection(_ connection: Connection, willUseCommandProtocolWithFeatureAvailability availability: ProtocolFeatureAvailability)

    /// Indicates that the connection has been instructed to disconnect from the server, and connect to a new address.
    func connection(_ connection: Connection, willRedirectTo newAddress: ServerAddress)
    /// Indicates that the connection has successfully connected to a new server after being instructed to redirect.
    func connection(_ connection: Connection, didSuccessfullyRedirectTo newAddress: ServerAddress)

    /// Indicates the connection will attempt to connect to a server following this call.
    func connection(_ connection: Connection, willConnectTo newAddress: ServerAddress)
    /// Indicates the connection has initiated communication with a server.
    func connection(_ connection: Connection, didSuccessfullyConnectTo newAddress: ServerAddress)

    /// Indicates the connectioon has ended communication with the server.
    func connectionDidDisconnect(_ connection: Connection)

    /// Indicates the connection has become authenticated with the server, and provides
    /// an `AuthenticatedClient` object that will describe the server's state.
    func connection(_ connection: Connection, didBecomeAuthenticated authenticatedClient: AuthenticatedClient)
    /// Indicates the connection is no longer authenticated with the server, and will no longer
    /// receive information about its state.
    func connectionDidBecomeUnauthenticated(_ connection: Connection)
}

public extension ReceivesTASServerUpdates {
    func connection(_ connection: Connection, willUseCommandProtocolWithFeatureAvailability availability: ProtocolFeatureAvailability) {}
    
    func connection(_ connection: Connection, willRedirectTo newAddress: ServerAddress) {}
    func connection(_ connection: Connection, didSuccessfullyRedirectTo newAddress: ServerAddress) {}
    
    func connection(_ connection: Connection, willConnectTo newAddress: ServerAddress) {}
    func connection(_ connection: Connection, didSuccessfullyConnectTo newAddress: ServerAddress) {}
    
    func connectionDidDisconnect(_ connection: Connection) {}

    func connection(_ connection: Connection, didBecomeAuthenticated authenticatedClient: AuthenticatedClient) {}
    func connectionDidBecomeUnauthenticated(_ connection: Connection) {}
}

/// Handles the socket connection to a TASServer.
///
/// Lobbyserver protocol is described at http://springrts.com/dl/LobbyProtocol
/// See here for an implementation in C++ https://github.com/cleanrock/flobby/tree/master/src/model
public final class Connection: NSObject, SocketDelegate, UpdateNotifier {

    // MARK: - Associated Objects

    /// The TASServer's delegate object.
    private unowned var client: Client
    public let userAuthenticationController: UserAuthenticationController
    public internal(set) var authenticatedClient: AuthenticatedClient? {
        didSet {
            if let authenticatedClient = authenticatedClient {
                applyActionToChainedObjects({ $0.connection(self, didBecomeAuthenticated: authenticatedClient) })
            } else {
                applyActionToChainedObjects({ $0.connectionDidBecomeUnauthenticated(self) })
            }
        }
    }

    // MARK: - Command handling

    /// A dictionary specifying data structures relating to the server commands that the command handler will handle.
    private var incomingCommands: [String : SCCommand.Type] = [:]
    /// Blocks to be executed when a command with a specific ID is received. Return true if the expected response has been received.
    ///
    /// internal access provided due to a current bug where command IDs don't properly register the "ACCEPTED"/"DENIED" commands, see `SCLoginAcceptedCommand.execute(on:)` and `SCLoginDeniedCommand.execute(on:)`.
    var specificCommandHandlers: [Int : (SCCommand) -> (Bool)] = [:]

    // MARK: - Connection Properties

    /// The socket that connects to the remote server.
    private(set) var socket: Socket
    /// The delay after which the keepalive "PING" should be sent in order to maintain the server connection.
    /// A delay of 30 seconds is reccomended by TASServer documentation.
    private static let keepaliveDelay: TimeInterval = 30

    /// The address the client is connected to.
    public var address: ServerAddress {
        return socket.address
    }

    /// A directory in which various clients may store information relating to the server they are connected to.
    private let baseCacheDirectory: URL
    /// A directory in which the client associated with this connection may store information relating to the server it is connected to.
    public var cacheDirectory: URL {
        return baseCacheDirectory.appendingPathComponent(address.description)
    }

    // MARK: - Lifecycle

    /// Initialiser for the TASServer object.
    ///
    /// - parameter address: The IP address or domain name of the server, along with the port it should connect on.
    /// - parameter defaultProtocol: The protocol the connection will assume the server will communicate with. Use `.unknown` for the client to detect the protocol.
    init(address: ServerAddress, client: Client, userAuthenticationController: UserAuthenticationController, baseCacheDirectory: URL, defaultProtocol: ServerProtocol = .unknown) {
        self.baseCacheDirectory = baseCacheDirectory
        self.userAuthenticationController = userAuthenticationController
        
        socket = Socket(address: address)
        self.client = client
        super.init()

        socket.delegate = self
        setProtocol(defaultProtocol)
    }
    
    deinit {
        disconnect()
    }

    // MARK: - Connection to Servers

    /// Initiates the socket connection and begins the keepalive loop.
    func connect() {
        applyActionToChainedObjects({ $0.connection(self, willConnectTo: address) })
        socket.connect()
        applyActionToChainedObjects({ $0.connection(self, didSuccessfullyConnectTo: address) })
        perform(#selector(Connection.sendPing), with: nil, afterDelay: 30)
    }

    /// Terminates the connection to the server, and with it the keepalive loop.
    func disconnect() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(Connection.sendPing), object: nil)
        socket.disconnect()
    }

    /// Closes the connection to one server, and connects to the new address
    func redirect(to serverAddress: ServerAddress, defaultProtocol: ServerProtocol = .unknown) {

        applyActionToChainedObjects({ $0.connection(self, willRedirectTo: serverAddress) })

        disconnect()

        socket = Socket(address: serverAddress)
        socket.delegate = self
        setProtocol(defaultProtocol)

        connect()

        applyActionToChainedObjects({ $0.connection(self, didSuccessfullyRedirectTo: serverAddress) })
    }

    // MARK: - Handling Messages

    /// The ID of the next message to be sent to the server, corresponding to the number of messages previously sent.
    private var count = 0
    /// Sends an encoded command over the socket and delays the keepalive to avoid sending superfluous messages to the server.
    ///
    /// Command handlers should not contain any strong references to objects in the case a command is never responded to.
    public func send(_ command: CSCommand, specificHandler: ((SCCommand) -> (Bool))? = nil) {
        Logger.log("Sending: #\(count) " + command.description, tag: .General)
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(Connection.sendPing), object: nil)

        specificCommandHandlers[count] = specificHandler
        socket.send(message: "#\(count) \(command.description)\n")

        perform(#selector(Connection.sendPing), with: nil, afterDelay: Connection.keepaliveDelay)

        count += 1
    }

    /// Sends a keepalive message and queues the next.
    @objc private func sendPing() {
        socket.send(message: "PING\n")
        perform(#selector(Connection.sendPing), with: nil, afterDelay: Connection.keepaliveDelay)
    }

    // MARK: - SocketDelegate

    /// A message was received over the socket.
    func socket(_ socket: Socket, didReceive message: String) {
        let messages = message.components(separatedBy: "\n")

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
            let description = components.dropFirst(1 + commandIndex).joined(separator: " ")
            guard components.count > (commandIndex + 1),
                  let recognisedCommand = incomingCommands[components[commandIndex].uppercased()],
                  let command = recognisedCommand.init(description: description) else {
                Logger.log("Failed to decode command", tag: .ServerError)
                continue
            }
            if let messageID = messageID {
                if let specificHandler = specificCommandHandlers[messageID],
                   specificHandler(command) {
                    specificCommandHandlers.removeValue(forKey: messageID)
                }
            }
            command.execute(on: client)
        }
    }

    /// The socket will no longer receive information from the server.
    func socketDidClose(_ socket: Socket) {
        client.reset()
        setProtocol(.unknown)
        applyActionToChainedObjects({ $0.connectionDidDisconnect(self) })
    }

    // MARK: - Protocol

    /// Identifies a protocol that the command handler can handle.
    enum ServerProtocol {
        case unknown
        case tasServer(version: Float)
        case zeroKServer
    }

    /// Describes the features available with the connected server.
    public private(set) var featureAvailability: ProtocolFeatureAvailability?

    /// Sets a protocol that has been identified such that following commands may be processed.
    func setProtocol(_ serverProtocol: ServerProtocol) {
        let featureAvailability = ProtocolFeatureAvailability(serverProtocol: serverProtocol)
        
        switch serverProtocol {
        case .unknown:
            incomingCommands = [
                "TASSERVER" : TASServerCommand.self
            ]
        case .tasServer:
            incomingCommands = Connection.tasServerSCCommands
        default:
            break
        }

        applyActionToChainedObjects({ $0.connection(self, willUseCommandProtocolWithFeatureAvailability: featureAvailability) })

        self.featureAvailability = featureAvailability
    }
    
    // MARK: - UpdateNotifier

    public var objectsWithLinkedActions: [() -> ReceivesTASServerUpdates?] = []
    
    // MARK: - Protocol commands

    /// A set of commands expected to be received when using the TASServer protocol.
    private static let tasServerSCCommands: [String : SCCommand.Type] = [
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
}
