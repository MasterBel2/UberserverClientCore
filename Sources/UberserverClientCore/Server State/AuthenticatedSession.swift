//
//  AuthenticatedSession.swift
//  
//
//  Created by MasterBel2 on 28/2/21.
//

import Foundation

/// A set of functions called by an `AuthenticatedSession` when it updates.
public protocol ReceivesAuthenticatedClientUpdates: AnyObject {
    /// Indicates that the user has joined a battleroom.
    func authenticatedClient(_ authenticatedSession: AuthenticatedSession, didJoin battleroom: Battleroom)
    /// Indicates that the user has left the joined battleroom.
    func authenticatedClientDidLeaveBattleroom(_ authenticatedSession: AuthenticatedSession)

    func asAnyReceivesAuthenticatedClientUpdates() -> AnyReceivesAuthenticatedClientUpdates
}

public extension ReceivesAuthenticatedClientUpdates {
    func authenticatedClient(_ authenticatedSession: AuthenticatedSession, didJoin battleroom: Battleroom) {}
    func authenticatedClientDidLeaveBattleroom(_ authenticatedSession: AuthenticatedSession) {}

    func asAnyReceivesAuthenticatedClientUpdates() -> AnyReceivesAuthenticatedClientUpdates {
        return AnyReceivesAuthenticatedClientUpdates(wrapping: self)
    }
}

public final class AnyReceivesAuthenticatedClientUpdates: ReceivesAuthenticatedClientUpdates, Box {
    public let wrapped: ReceivesAuthenticatedClientUpdates
    public var wrappedAny: AnyObject {
        return wrapped
    }

    public init(wrapping: ReceivesAuthenticatedClientUpdates) {
        self.wrapped = wrapping
    }

    public func authenticatedClient(_ authenticatedSession: AuthenticatedSession, didJoin battleroom: Battleroom) {
        wrapped.authenticatedClient(authenticatedSession, didJoin: battleroom)
    }

    public func authenticatedClientDidLeaveBattleroom(_ authenticatedSession: AuthenticatedSession) {
        wrapped.authenticatedClientDidLeaveBattleroom(authenticatedSession)
    }

    public func asAnyReceivesAuthenticatedClientUpdates() -> AnyReceivesAuthenticatedClientUpdates {
        return self
    }
}

/// Describes the state of the server that an authenticated user has access to.
public class AuthenticatedSession: UpdateNotifier {

    // MARK: - Associated Objects

    /// The server connection this object is associated with.
    public unowned let lobby: TASServerLobby
    public var objectsWithLinkedActions: [AnyReceivesAuthenticatedClientUpdates] = []

    // MARK: - Data

    /// The username this user is identified by.
    public let username: String
    /// The password the user used to log in.
    ///
    /// This property is internal-only as a privacy and security precaution.
    internal let password: String

    /// The channels the user is participating in.
    public let channelList = List<Channel>()
    /// The private message conversations the user is engaging in.
    public let privateMessageList = List<Channel>()
    /// The set of forwarded conversations the user is receiving.
    public let forwardedMessageList = List<Channel>()
    /// The users that are authenticated on the server.
    public let userList = List<User>()
    /// The battles currently published on the server.
    public let battleList = List<Battle>()

    /// The battleroom the user has joined.
    public internal(set) var battleroom: Battleroom? {
        didSet {
            guard oldValue !== battleroom else { return }
            if let battleroom = battleroom {
                applyActionToChainedObjects({ $0.authenticatedClient(self, didJoin: battleroom) })
            } else {
                applyActionToChainedObjects({ $0.authenticatedClientDidLeaveBattleroom(self) })
            }
        }
    }

    public let accountInfoController = AccountInfoController()

    // MARK: - Creating an AuthenticatedClient
    
    init(username: String, password: String, lobby: TASServerLobby) {
        self.username = username
        self.password = password
        self.lobby = lobby

        accountInfoController.authenticatedClient = self
        accountInfoController.lobby = lobby
    }

    // MARK: - Player IDs

    /// The ID of the account the user has used to connect to the server.
    public var myID: Int? {
        return id(forPlayerNamed: username)
    }

    public var myUser: User? {
        return myID.flatMap({ userList.items[$0] })
    }

    /// Returns ID of a player, if they are online.
    public func id(forPlayerNamed username: String) -> Int? {
        return userList.items.first { (_, user) in
            return user.profile.fullUsername.lowercased() == username.lowercased()
        }?.key
    }

    // MARK: - Channels

    /// Contains metadata describing channels listed by the server.
    public struct ChannelSummary {
        public let title: String
        public let description: String
        public let members: String
        public let isPrivate: Bool
    }

    /// The unique integer ID of channels, keyed by their name.
    private var channelIDs: [String : Int] = [:]

    /// A local cache of information about channels listed by the server.
    public internal(set) var channels: [ChannelSummary] = []

    /// Retrieves the unique integer ID for a channel.
    public func id(forChannelnamed channelName: String) -> Int {
        if let id = channelIDs[channelName] {
            return id
        } else {
            let id = channelIDs.count
            channelIDs[channelName] = id
            return id
        }
    }

    /// Sends a message to the server requesting to join a channel.
    ///
    /// If the listed channel is private, a prompt will be presented indicating that a password is required.
    public func joinChannel(_ channelName: String) {
        lobby.send(CSJoinCommand(channelName: channelName, key: nil))

        if channels.first(where: { $0.title == channelName })?.isPrivate == true {
            // TODO: Present a prompt
        }
    }

    /// Returns the channel object describing the private conversation between two users.
    public func privateMessageChannel(withUserNamed username: String, userID: Int) -> Channel? {
        guard let myID = myID else { return nil }

        let channelID = id(forChannelnamed: username)
        
        let channel: Channel
        if let cachedChannel = privateMessageList.items[channelID] {
            channel = cachedChannel
        } else {
            channel = Channel(title: username, rootList: userList, sendAction: { [weak lobby] channel, message in
                lobby?.send(CSSayPrivateCommand(intendedRecipient: username, message: message))
            })
            channel.userlist.addItemFromParent(id: userID)
            channel.userlist.addItemFromParent(id: myID)

            privateMessageList.addItem(channel, with: channelID)
        }
        return channel
    }
    
    // MARK: - Battleroom

    /// Sends a request to join a battle, leaving the current battle if necessary.
    public func joinBattle(_ battleID: Int) {
        guard let battle = battleList.items[battleID],
              battle !== battleroom?.battle else {
            return
        }
        
        if battleroom != nil {
            leaveBattle()
        }
        
        if battle.hasPassword {
            // TODO: Prompt for password
        } else {
            lobby.send(CSJoinBattleCommand(battleID: battleID, password: nil, scriptPassword: battle.myScriptPassword))
        }
    }
    
    /// Removes the player from the battle; first locally, then with a message to the server.
    public func leaveBattle() {
        guard battleroom != nil else { return }
        battleroom = nil

        lobby.send(CSLeaveBattleCommand())
    }

    public func hostBattle(title: String, password: String?, maxPlayers: Int, minRank: Int, port: Int, engine: Engine, gameArchive: QueueLocked<UnitsyncModArchive>, mapArchive: QueueLocked<UnitsyncMapArchive>, resultHandler: @escaping (Result<Int, ServerError>) -> Void) {
        guard battleroom == nil else { return }

        Logger.log("About to send...", tag: .General)

        let (gameName, gameHash) = gameArchive.sync(block: { return ($0.name, $0.completeChecksum) })
        let (mapName, mapHash) = mapArchive.sync(block: { return ($0.name, $0.completeChecksum) })

        Logger.log("Got map/game info...", tag: .General)

        lobby.send(CSOpenBattleCommand(
            isReplay: false,
            natType: .none,
            password: password,
            port: port,
            maxPlayers: maxPlayers,
            gameHash: gameHash,
            rank: minRank,
            mapHash: mapHash,
            engineName: "Spring",
            engineVersion: engine.syncVersion,
            mapName: mapName,
            title: title,
            gameName: gameName
        ), specificHandler: { [weak self] command in
            // if let successCommand = command as? SCOpenBattleCommand {
            //     resultHandler(.success(successCommand.battleID))
            //     return true
            guard let self = self else { return true }
            if let successCommand = command as? SCBattleOpenedCommand {
                guard let founderID = self.id(forPlayerNamed: successCommand.founder) else { return false }
                let battle = Battle(
                    serverUserList: self.userList, 
                    isReplay: successCommand.isReplay, 
                    natType: successCommand.natType, 
                    founder: successCommand.founder, 
                    founderID: founderID, 
                    ip: successCommand.ip, 
                    port: successCommand.port, 
                    maxPlayers: successCommand.maxPlayers, 
                    hasPassword: successCommand.passworded, 
                    rank: successCommand.rank, 
                    mapHash: successCommand.mapHash, 
                    engineName: successCommand.engineName, 
                    engineVersion: successCommand.engineVersion, 
                    mapName: successCommand.mapName, 
                    title: successCommand.title, 
                    gameName: successCommand.gameName, 
                    channel: successCommand.channel, 
                    scriptPasswordCacheDirectory: self.lobby.connection.cacheDirectory.appendingPathComponent("Script Passwords"), 
                    resourceManager: self.lobby.connection.resourceManager
                )
                self.battleList.addItem(battle, with: successCommand.battleID)

                guard let myID = self.myID else { return true }

                #warning("Dummy value for hash code; value received in a separate command, which is too difficult so I just gave up")
                self.battleroom = Battleroom(
                    battle: battle,
                    channel: Channel(title: successCommand.channel, rootList: self.userList, sendAction: { [weak self] channel, message in
                        self?.lobby.send(CSSayCommand(channelName: channel.title, message: message))
                    }),
                    sendCommandBlock: { [weak self] command in self?.lobby.send(command) },
                    hashCode: 0, 
                    myID: myID,
                    hostAPI: HostAPI(session: self, engine: engine, mapArchive: mapArchive, gameArchive: gameArchive)
                )
                return true
            } else if let failureCommand = command as? SCOpenBattleFailedCommand {
                resultHandler(.failure(.openBattleFailed(reason: failureCommand.reason)))
                return true
            }
            return false
        })
        Logger.log("sent!", tag: .General)
    }

    // MARK: - Interacting with Other Users

    /// Instructs the server to ring another user.
    public func ring(_ id: Int) {
        if let recipient = userList.items[id] {
            lobby.send(CSRingCommand(target: recipient.profile.fullUsername))
        }
    }

    /// [Verifies the intent, and] instructs the server to add a user to the ignore list.
    public func ignoreUser(_ id: Int) {
        // 1. Present a prompt asking for a reason ???? Should this be delegated somewhere else?

        // 2. Allow discarding of message and cancelling of the ignore action on

        // 3. Send message on prompt completion
    }

    /// Removes a user from the list of ignored users.
    public func unignoreUser(_ id: Int) {
        // TODO
    }
}
