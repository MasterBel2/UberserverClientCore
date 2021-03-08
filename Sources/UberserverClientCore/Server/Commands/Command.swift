//
//  Command.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 1/9/19.
//  Copyright © 2019 MasterBel2. All rights reserved.
//

import Foundation

/**
 Commands sent from a server to a client should be prefixed with "SC"; commands sent from a client
 to a server should be prefixed with "CS". See `CSCommand` and `SCCommand`.
 */
public protocol Command: CustomStringConvertible {
    init?(description: String)
    func updateDisplay(for client: Client)
}

extension Command {
    public func updateDisplay(for client: Client) {} 
}

/**
 Represents the structure of a lobby server.
 */
public protocol LobbyServer {
    /// The complete list of accounts registered on the server.
    var accounts: Array<ServerAccount> { get }
    /// The complete list of users connected to the server.
    var clients: Array<ServerClient> { get }
    /// The complete list of battles open on the server.
    var battles: Array<ServerBattle> { get }
    /// The complete list of channels open on the server.
    var channels: Array<ServerChannel> { get }
}

public final class ServerAccount: Codable {
    /// The account's unique ID
    let id: Int
    /// The current username of the account.
    var username: String
    /// The number of minutes the user has spent with the "ingame" status.
    var ingameTime: Int
    /// The md5-encrypted password of the account.
    var password: String
    /// Whether the account is a moderator or not.
    var isModerator: Bool
    /// Whether the account is registered as an automated account.
    var isAutomated: Bool

}

public final class ServerClient {
    let account: ServerAccount

    // MARK: - Status

    var away: Bool = false
    var ingame: Bool = false

    // MARK: - Other data

    /// The client's Local IP. Set to "*" if it is undeterminable.
    let localIP: String
    /// A client-generated string describbing their lobby client, including its version. This is to
    /// allow better user support over the lobby channels.
    let lobbyNameAndVersion: String
    /// A unique user identification number provided by the client-side software. It has to be an
    /// unsigned 32 bit integer which is generated by calculating the crc32 from the binary mac
    /// address of the primary network interface. If it can't be determinated it has to be set to 0.
    let userID: UInt32

    let compatabilityFlags: [CompatabilityFlag]

    init(account: ServerAccount, localIP: String, lobbyNameAndVersion: String, userID: UInt32, compatabilityFlags: [CompatabilityFlag]) {
        self.account = account
        self.localIP = localIP
        self.lobbyNameAndVersion = lobbyNameAndVersion
        self.userID = userID
        self.compatabilityFlags = compatabilityFlags
    }
}

enum CompatabilityFlag: String {
    case lobbyIDInAddUser = "l"
    case channelTopicOmitsTime = "t"
    case sayForBattleChatAndSayFrom = "u"
    case scriptPasswords = "sp"
    case springEngineVersionAndNameInBattleOpened = "cl"
    case joinBattleRequestAcceptDeny = "b"
}

public final class ServerBattle {
    let host: ServerClient
    var players: [ServerClient]
    var spectators: [ServerClient] = []

    /// A dictionary of clients' statuses, indexed by their ID. If a client has no id, a
    /// `CSRequestBattleStatus` command should be sent to request the client's status.
    var battleStatus: [Int : Status] = [:]
    /// The name of the map to be played.
    var mapName: String
    /// The hash value associated with the map. Clients should use the Unitsync library to generate
    /// this value.
    var mapHash: Int
    /// The name of the game to be played. This may not be changed once the battle is opened.
    let gameName: String
    /// The name of the engine to be run. This may not be changed once the battle is opened.
    let engineName: String
    /// The version string of the engine to be run. This may not be changed once the battle is opened.
    let engineVersion: String

    /// The script tags associated with this battle. Set by the host.
    var scriptTags: [String : String] = [:]

    // MARK: - Lifecycle

    init(host: ServerClient, mapName: String, mapHash: Int, gameName: String, engineName: String, engineVersion: String) {
        self.host = host
        self.players = [host]
        self.mapName = mapName
        self.mapHash = mapHash
        self.gameName = gameName
        self.engineName = engineName
        self.engineVersion = engineVersion
    }

    struct Status {
        /// Indicates whether player is ready to play the next game. Usually, games may only start
        /// if all players are ready.
        var ready: Bool = false
        /// The "team" of units the player will control. Players with the same team must have the
        /// same `allyTeam` for this value to have an effect.
        var team: Int
        /// The alliance the player will be a part of.
        var allyTeam: Int
        /// The percentage resource bonus. Valid values are 0 - 100.
        var handicap: Int = 0
        /// Indicates whether the user is synced, unsynced, or whether that information is unknown.
        var syncStatus: SyncStatus = .unknown
        /// The side index. Valid values are 0 - 15.
        var side: Int = 0

        /// A set of values indicating whether a player is synced.
        enum SyncStatus {
            /// The player's sync status is not known.
            case unknown
            /// The player is synced.
            case synced
            /// The player is unsynced.
            case unsynced
        }
    }
}

public final class ServerChannel {
    let history = ServerChannelHistory()
    let name: String

    init(name: String) {
        self.name = name
    }
}
struct ServerChannelHistory: Hashable {

}

/**
 */
public protocol CSCommand: Command {
    func execute(on server: LobbyServer)
}

/**
 A `Command` received by a client, sent by the server.

 See `CSCommand` for client-to-server commands.
 */
public protocol SCCommand: Command {
    /// Updates the client's data and triggers UI updates. (The UI knows how to update itself.)
    func execute(on connection: ThreadUnsafeConnection)
}
