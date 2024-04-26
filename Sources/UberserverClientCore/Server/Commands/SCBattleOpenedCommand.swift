//
//  BattleOpenedCommand.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 30/6/19.
//  Copyright © 2019 MasterBel2. All rights reserved.
//

import Foundation

/// See https://springrts.com/dl/LobbyProtocol/ProtocolDescription.html#BATTLEOPENED:server
public struct SCBattleOpenedCommand: SCCommand {

    public static let title = "BATTLEOPENED"

    public let battleID: Int

    public let isReplay: Bool
    public let natType: Battle.NATType
    public let founder: String
    public let ip: String
    public let port: Int
    public let maxPlayers: Int
    public let passworded: Bool
    public let rank: Int
    public let mapHash: Int32

    public let engineName: String
    public let engineVersion: String
    public let mapName: String
    public let title: String
    public let gameName: String
    public let channel: String

    // MARK: - Lifecycle
    
    public init?(payload: String) {
        do {
            // 10 words:
            // battleID type natType founder ip port maxPlayers passworded rank mapHash

            // 6 sentences:
            // {engineName} {engineVersion} {map} {title} {gameName} {channel}

            let (words, sentences) = try wordsAndSentences(for: payload, wordCount: 10, sentenceCount: 6)

            guard let battleID = Int(words[0]),
                let port = Int(words[5]),
                let maxPlayers = Int(words[6]),
                let rank = Int(words[8]),
                let mapHash = Int32(words[9])
                else {
                    return nil
            }
            self.battleID = battleID
            self.port = port
            self.maxPlayers = maxPlayers
            self.rank = rank
            self.mapHash = mapHash

            isReplay = words[1] == "1"

            switch words[2] {
            case "1":
                natType = .holePunching
            case "2":
                natType = .fixedSourcePorts
            default:
                natType = .none
            }

            passworded = words[7] == "1"

            ip = words[4]
            founder = words[3]

            engineName = sentences[0]
            engineVersion = sentences[1]
            mapName = sentences[2]
            title = sentences[3]
            gameName = sentences[4]
            channel = sentences[5]
        } catch {
            Logger.log("Failed to parse battle from payload \"\(payload)\": \(error.localizedDescription)", tag: .GeneralError)
            return nil
        }
    }
    
    // MARK: - Behaviour
    
    public func execute(on lobby: TASServerLobby) {
        guard case let .authenticated(authenticatedSession) = lobby.session,
              let founderID = authenticatedSession.id(forPlayerNamed: founder) else {
            return
        }
        let battle = Battle(
            serverUserList: authenticatedSession.userList,
            isReplay: isReplay,
            natType: natType,
            founder: founder,
            founderID: founderID,
            ip: ip,
            port: port,
            maxPlayers: maxPlayers,
            hasPassword: passworded,
            rank: rank,
            mapHash: mapHash,
            engineName: engineName,
            engineVersion: engineVersion,
            mapName: mapName,
            title: title,
            gameName: gameName,
            channel: channel,
            scriptPasswordCacheDirectory: lobby.connection.cacheDirectory.appendingPathComponent("Script Passwords"),
            resourceManager: lobby.connection.resourceManager
        )

        authenticatedSession.battleList.addItem(battle, with: battleID)
    }

    // MARK: - String representation

    public var payload: String {
        #warning("TODO")
        return ""
    }
}

/**
 Sent to a client who previously sent an OPENBATTLE command, if the client's request to open a new battle has been approved.

 Note that the corresponding BATTLEOPENED command is sent before this command is used to reflect the successful OPENBATTLE command back to the client.

 After sending this command, the server will send a JOINBATTLE (to notify the founding client that they have joined their own battle) followed by a REQUESTBATTLESTATUS.
 */
public struct SCOpenBattleCommand: SCCommand {

    public static let title = "OPENBATTLE"

    /// The ID of the opened battle.
	public let battleID: Int
	
	// MARK: - Manual Construction
	
	init(battleID: Int) {
		self.battleID = battleID
	}
	
	// MARK: - SCCommand
	
    public init?(payload: String) {
		guard let battleID = Int(payload) else {
			return nil
		}
		self.battleID = battleID
	}
	
    public func execute(on lobby: TASServerLobby) {}
	
    public var payload: String {
		return String(battleID)
	}
	
}

public struct SCOpenBattleFailedCommand: SCCommand {

    public static let title = "OPENBATTLEFAILED"
	
	public let reason: String
	
	// MARK: - Manual Construction
	
	public init(reason: String) {
		self.reason = reason
	}
	
	// MARK: - SCCommand
	
    public init?(payload: String) {
		reason = payload
	}
	
    public func execute(on lobby: TASServerLobby) {}
	
    public var payload: String {
		return reason
	}
}

public struct CSOpenBattleCommand: CSCommand {

    public static let title = "OPENBATTLE"

    let isReplay: Bool
    let natType: Battle.NATType
    let password: String?
    let port: Int
    let maxPlayers: Int
    let gameHash: Int32
    let rank: Int
    let mapHash: Int32

    let engineName: String
    let engineVersion: String
    let mapName: String
    let title: String
    let gameName: String

    public init(isReplay: Bool, natType: Battle.NATType, password: String?, port: Int, maxPlayers: Int, gameHash: Int32, rank: Int, mapHash: Int32, engineName: String = "Spring", engineVersion: String, mapName: String, title: String, gameName: String) {
        self.isReplay = isReplay
        self.natType = natType
        self.password = password
        self.port = port
        self.maxPlayers = maxPlayers
        self.gameHash = gameHash
        self.rank = rank
        self.mapHash = mapHash
        self.engineName = engineName
        self.engineVersion = engineVersion
        self.mapName = mapName
        self.title = title
        self.gameName = gameName
    }

    public init?(payload: String) {
        guard let (words, sentences) = try? wordsAndSentences(for: payload, wordCount: 8, sentenceCount: 5),
              let port = Int(words[3]),
              let maxPlayers = Int(words[4]),
              let gameHash = Int32(words[5]),
              let rank = Int(words[6]),
              let mapHash = Int32(words[7]) else {
            return nil
        }

        self.isReplay = words[0] == "1"
        switch words[1] {
        case "0":
            natType = .none
        case "1":
            natType = .holePunching
        case "2":
            natType = .fixedSourcePorts
        default:
            return nil
        }

        self.password = words[2] == "*" ? nil : words[2]
        self.port = port
        self.maxPlayers = maxPlayers
        self.gameHash = gameHash
        self.rank = rank
        self.mapHash = mapHash
        self.engineName = sentences[0]
        self.engineVersion = sentences[1]
        self.mapName = sentences[2]
        self.title = sentences[3]
        self.gameName = sentences[4]
    }

    public var payload: String {
        return "\(isReplay ? "1" : "0") \(String(natType.rawValue)) \(password ?? "*") \(String(port)) \(String(maxPlayers)) \(String(gameHash)) \(String(rank)) \(String(mapHash)) \([engineName, engineVersion, mapName, title, gameName].joined(separator: "\t"))"
    }

    public func execute(on server: LobbyServer) {
        // TODO
    }
}

public struct CSUpdateBattleInfoCommand: CSCommand {

    public static let title = "UPDATEBATTLEINFO"

    let spectatorCount: Int
    let locked: Bool
    let mapName: String
    let mapHash: Int32

    public init(spectatorCount: Int, locked: Bool, mapName: String, mapHash: Int32) {
        self.spectatorCount = spectatorCount
        self.locked = locked
        self.mapHash = mapHash
        self.mapName = mapName
    }

    public init?(payload: String) {
        guard let (words, sentences) = try? wordsAndSentences(for: payload, wordCount: 3, sentenceCount: 1),
              let spectatorCount = Int(words[0]),
              let mapHash = Int32(words[2]) else {
            return nil
        }
        self.spectatorCount = spectatorCount
        self.locked = words[1] == "1"
        self.mapHash = mapHash
        self.mapName = sentences[0]
    }

    public var payload: String {
        return "\(spectatorCount) \(locked ? "1" : "0") \(mapHash) \(mapName)"
    }

    public func execute(on server: LobbyServer) {
        // TODO
    }
}

/**
 Sent by the founder of the battle, to tell the server to kick a client from the battle. 
 The server removes the target client from the battle and notifies the target client via FORCEQUITBATTLE command. 
 */
public struct CSKickFromBattleCommand: CSCommand {

    public static let title = "KICKFROMBATTLE"

    public let username: String

    // MARK: - Manual construction

    public init(username: String) {
        self.username = username
    }

    // MARK: - SCCommand

    public init?(payload: String) {
        if payload == "" { return nil }
        self.username = payload
    }

    public var payload: String {
        return username
    }

    public func execute(on server: LobbyServer) {
        // TODO
    }
}

/**
 Sent by the founder of a battle to change the team number of a user. 
 The server will update the client's battle status automatically. 
 */
public struct CSForceTeamNumberCommand: CSCommand {

    public static let title = "FORCETEAMNO"

    public let username: String
    public let teamNumber: Int

    // MARK: - Manual construction

    public init(username: String, teamNumber: Int) {
        self.username = username
        self.teamNumber = teamNumber
    }

    // MARK: - SCCommand

    public init?(payload: String) {
        guard let (words, _) = try? wordsAndSentences(for: payload, wordCount: 2, sentenceCount: 0),
              let teamNumber = Int(words[1]) else {
            return nil
        }
        self.username = words[0]
        self.teamNumber = teamNumber
    }

    public var payload: String {
        return "\(username) \(teamNumber)"
    }

    public func execute(on server: LobbyServer) {
        // TODO
    }
}

/**
 Sent by the founder of a battle to change the ally team number of a user. 
 The server will update the client's battle status automatically. 
 */
public struct CSForceAllyNumberCommand: CSCommand {

    public static let title = "FORCEALLYNO"

    public let username: String
    public let allyNumber: Int

    // MARK: - Manual construction

    public init(username: String, allyNumber: Int) {
        self.username = username
        self.allyNumber = allyNumber
    }

    // MARK: - SCCommand

    public init?(payload: String) {
        guard let (words, _) = try? wordsAndSentences(for: payload, wordCount: 2, sentenceCount: 0),
              let allyNumber = Int(words[1]) else {
            return nil
        }
        self.username = words[0]
        self.allyNumber = allyNumber
    }

    public var payload: String {
        return "\(username) \(allyNumber)"
    }

    public func execute(on server: LobbyServer) {
        // TODO
    }
}

/**
 Sent by the founder of a battle to change the team colour of a team. 
 The server will update the client's battle status automatically.

 - Parameter color:  Should be a 32-bit signed integer in decimal form (e.g. 255 and not FF)
                     where each color channel should occupy 1 byte (e.g. in hexdecimal: $00BBGGRR, B = blue, G = green, R = red). 
                     Example: 255 stands for $000000FF. 
 */
public struct CSForceTeamColorCommand: CSCommand {

    public static let title = "FORCETEAMCOLOR"

    public let username: String
    public let color: Int32

    // MARK: - Manual construction

    public init(username: String, color: Int32) {
        self.username = username
        self.color = color
    }

    // MARK: - SCCommand

    public init?(payload: String) {
        guard let (words, _) = try? wordsAndSentences(for: payload, wordCount: 2, sentenceCount: 0),
              let color = Int32(words[1]) else {
            return nil
        }
        self.username = words[0]
        self.color = color
    }

    public var payload: String {
        return "\(username) \(color)"
    }

    public func execute(on server: LobbyServer) {
        // TODO
    }
}

/**
 Sent by the founder of a battle to force a given user to become a spectator.
 The server will update the client's battle status automatically.
 */
public struct CSForceSpectatorModeCommand: CSCommand {

    public static let title = "FORCESPECTATORMODE"

    public let username: String

    // MARK: - Manual construction

    public init(username: String) {
        self.username = username
    }

    // MARK: - SCCommand

    public init?(payload: String) {
        guard payload != "" else {
            return nil
        }
        username = payload
    }

    public var payload: String {
        return username
    }

    public func execute(on server: LobbyServer) {
        // TODO
    }
}

/**
 Adds a start rectangle for the 'allyno' ally team. 
 Only the battle foudner may use this command. 
 See lobby client implementations and Spring docs for more info on this one. "left", "top", "right" and "bottom" refer to a virtual rectangle that is 200x200 in size, where coordinates should be in the interval [0, 200]. 
 */
public struct CSAddStartRectCommand: CSCommand {

    public static let title = "ADDSTARTRECT"

    public let allyNumber: Int
    public let rect: StartRect

    // MARK: - Manual construction

    public init(allyNumber: Int, rect: StartRect) {
        self.allyNumber = allyNumber
        self.rect = rect
    }

    // MARK: - SCCommand

    public init?(payload: String) {
        guard let (words, _) = try? wordsAndSentences(for: payload, wordCount: 5, sentenceCount: 0) else {
            return nil
        }
        let integers = words.compactMap({ Int($0 )})
        guard integers.count == 5 else { return nil }
        allyNumber = integers[0]
        rect = StartRect(left: integers[1], top: integers[2], right: integers[3], bottom: integers[4])
    }

    public var payload: String {
        return "\(allyNumber) \(rect.left) \(rect.top) \(rect.right) \(rect.bottom)"
    }

    public func execute(on server: LobbyServer) {
        // TODO
    }
}

/**
  Removing a start rectangle the for 'allyNo' ally team. Sent by the host of the battle. 
  See client implementations and Spring docs for more info on this one. 
 */
public struct CSRemoveStartRectCommand: CSCommand {

    public static let title = "REMOVESTARTRECT"

    public let allyNumber: Int

    // MARK: - Manual construction

    public init(allyNumber: Int) {
        self.allyNumber = allyNumber
    }

    // MARK: - SCCommand

    public init?(payload: String) {
        guard let allyNumber = Int(payload) else {
            return nil
        }
        self.allyNumber = allyNumber
    }

    public var payload: String {
        return String(allyNumber)
    }

    public func execute(on server: LobbyServer) {
        // TODO
    }
}

/**
 Sent by a client (battle host), to inform other clients about current battle configuration (start positions type, mod options, map options...). 
 Only the battle host itself needs to write the corresponding script tags into script.txt, other battle clients should merely use them for display purposes. 
 The [pair] format is "key=value can have spaces". 
 Keys may not contain spaces, and are expected to use the '/' character to separate tables, see example:

    ```
    SETSCRIPTTAGS game/startmetal=1000
    SETSCRIPTTAGS game/startenergy=1000
    SETSCRIPTTAGS game/maxunits=500
    SETSCRIPTTAGS game/startpostype=1
    SETSCRIPTTAGS game/gamemode=0
    SETSCRIPTTAGS game/limitdgun=1
    SETSCRIPTTAGS game/diminishingmms=0
    SETSCRIPTTAGS game/ghostedbuildings=1
    ```

 Though in reality, all tags are joined together in a single command. 
 Note that when specifying multiple key+value pairs, they must be separated by TAB characters. 
 All keys are made lowercase by the server. See the examples bellow. 
 */
public struct CSSetScriptTagsCommand: CSCommand {

    public static let title = "SETSCRIPTTAGS"

    public let scriptTags: [String]

    // MARK: - Manual construction

    public init(scriptTags: [String]) {
        self.scriptTags = scriptTags
    }

    // MARK: - SCCommand

    public init?(payload: String) {
        scriptTags = payload.split(separator: "\t").map({ String($0) })
    }

    public var payload: String {
        return scriptTags.joined(separator: "\t")
    }

    public func execute(on server: LobbyServer) {
        // TODO
    }
}

/**
 Sent by a client (battle host), to inform other clients that a battle 
 configuration setting has been removed (this is mainly usefull when 
 changing map with map options). 
 */
public struct CSRemoveScriptTagsCommand: CSCommand {

    public static let title = "REMOVESCRIPTTAGS"

    public let keys: [String]

    // MARK: - Manual construction

    public init(keys: [String]) {
        self.keys = keys
    }

    // MARK: - SCCommand

    public init?(payload: String) {
        keys = payload.split(separator: "\t").map({ String($0) })
    }

    public var payload: String {
        return keys.joined(separator: "\t")
    }

    public func execute(on server: LobbyServer) {
        // TODO
    }
}
