//
//  AuthenticatedClient.swift
//  
//
//  Created by MasterBel2 on 28/2/21.
//

import Foundation

/// A set of functions called by an `AuthenticatedClient` when it updates.
public protocol ReceivesAuthenticatedClientUpdates {
    /// Indicates that the user has joined a battleroom.
    func authenticatedClient(_ authenticatedClient: AuthenticatedClient, didJoin battleroom: Battleroom)
    /// Indicates that the user has left the joined battleroom.
    func authenticatedClientDidLeaveBattleroom(_ authenticatedClient: AuthenticatedClient)
}

public extension ReceivesAuthenticatedClientUpdates {
    func authenticatedClient(_ authenticatedClient: AuthenticatedClient, didJoin battleroom: Battleroom) {}
    func authenticatedClientDidLeaveBattleroom(_ authenticatedClient: AuthenticatedClient) {}
}

/// Describes the state of the server that an authenticated user has access to.
public class AuthenticatedClient: UpdateNotifier {

    // MARK: - Associated Objects

    /// The server connection this object is associated with.
    private unowned let connection: Connection
    public var objectsWithLinkedActions: [() -> ReceivesAuthenticatedClientUpdates?] = []

    // MARK: - Data

    /// The username this user is identified by.
    public let username: String
    /// The password the user used to log in.
    ///
    /// This property is internal-only as a privacy and security precaution.
    internal let password: String

    /// The channels the user is participating in.
    public let channelList = List<Channel>(title: "All Channels", property: { $0.title })
    /// The private message conversations the user is engaging in.
    public let privateMessageList = List<Channel>(title: "Private Messages", property: { $0.title })
    /// The set of forwarded conversations the user is receiving.
    public let forwardedMessageList = List<Channel>(title: "Forwarded Messages", property: { $0.title })
    /// The users that are authenticated on the server.
    public let userList = List<User>(title: "All Users", property: { $0.status.rank })
    /// The battles currently published on the server.
    public let battleList = List<Battle>(title: "All Battles", property: { $0.playerCount })

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

    // MARK: - Creating an AuthenticatedClient
    
    init(username: String, password: String, connection: Connection) {
        self.username = username
        self.password = password
        self.connection = connection
    }

    // MARK: - Player IDs

    /// The ID of the account the user has used to connect to the server.
    public var myID: Int? {
        return id(forPlayerNamed: username)
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
        connection.send(CSJoinCommand(channelName: channelName, key: nil))

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
            channel = Channel(title: username, rootList: userList, sendAction: { [weak connection] channel, message in
                connection?.send(CSSayPrivateCommand(intendedRecipient: username, message: message))
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
            connection.send(CSJoinBattleCommand(battleID: battleID, password: nil, scriptPassword: battle.myScriptPassword))
        }
    }
    
    /// Removes the player from the battle; first locally, then with a message to the server.
    public func leaveBattle() {
        guard battleroom != nil else { return }
        battleroom = nil

        connection.send(CSLeaveBattleCommand())
    }

    // MARK: - Interacting with Other Users

    /// Instructs the server to ring another user.
    public func ring(_ id: Int) {
        if let recipient = userList.items[id] {
            connection.send(CSRingCommand(target: recipient.profile.fullUsername))
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
