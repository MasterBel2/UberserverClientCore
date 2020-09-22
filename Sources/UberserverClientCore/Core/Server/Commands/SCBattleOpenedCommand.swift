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
    private let battleID: Int

    private let isReplay: Bool
    private let natType: NATType
    private let founder: String
    private let ip: String
    private let port: Int
    private let maxPlayers: Int
    private let passworded: Bool
    private let rank: Int
    private let mapHash: Int32

    private let engineName: String
    private let engineVersion: String
    private let mapName: String
    private let title: String
    private let gameName: String
    private let channel: String

    // MARK: - Lifecycle
    
    public init?(description: String) {
        do {
            // 10 words:
            // battleID type natType founder ip port maxPlayers passworded rank mapHash

            // 6 sentences:
            // {engineName} {engineVersion} {map} {title} {gameName} {channel}

            let (words, sentences) = try wordsAndSentences(for: description, wordCount: 10, sentenceCount: 6)

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
            print(error)
            return nil
        }
    }
    
    // MARK: - Behaviour
    
    public func execute(on client: Client) {
        guard let founderID = client.id(forPlayerNamed: founder) else {
            fatalError("Could not find battle host with username \(founder)")
        }
        let battle = Battle(
            serverUserList: client.userList,
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
            channel: channel
        )

        client.battleList.addItem(battle, with: battleID)
    }

    // MARK: - String representation

    public var description: String {
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

    /// The ID of the opened battle.
	public let battleID: Int
	
	// MARK: - Manual Construction
	
	init(battleID: Int) {
		self.battleID = battleID
	}
	
	// MARK: - SCCommand
	
    public init?(description: String) {
		guard let battleID = Int(description) else {
			return nil
		}
		self.battleID = battleID
	}
	
    public func execute(on client: Client) {
		#warning("TODO")
	}
	
    public var description: String {
		return "OPENBATTLE \(battleID)"
	}
	
}

public struct SCOpenBattleFailedCommand: SCCommand {
	
	public let reason: String
	
	// MARK: - Manual Construction
	
	public init(reason: String) {
		self.reason = reason
	}
	
	// MARK: - SCCommand
	
    public init?(description: String) {
		reason = description
	}
	
    public func execute(on client: Client) {
		client.receivedError(.openBattleFailed(reason: reason))
	}
	
    public var description: String {
		return "OPENBATTLEFAILED \(reason)"
	}
}

public struct CSOpenBattleCommand: CSCommand {
    let isReplay: Bool
    let natType: NATType
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

    public init(isReplay: Bool, natType: NATType, password: String?, port: Int, maxPlayers: Int, gameHash: Int32, rank: Int, mapHash: Int32, engineName: String = "Spring", engineVersion: String, mapName: String, title: String, gameName: String) {
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

    public init?(description: String) {
        guard let (words, sentences) = try? wordsAndSentences(for: description, wordCount: 8, sentenceCount: 5),
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

    public var description: String {
        return "OPENBATTLE \(isReplay ? "1" : "0") \(String(natType.rawValue)) \(password ?? "*") \(String(port)) \(String(maxPlayers)) \(String(gameHash)) \(String(rank)) \(String(mapHash)) \([engineName, engineVersion, mapName, title, gameName].joined(separator: "\t"))"
    }

    public func execute(on server: LobbyServer) {
        // TODO
    }
}

public struct CSUpdateBattleInfoCommand: CSCommand {
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

    public init?(description: String) {
        guard let (words, sentences) = try? wordsAndSentences(for: description, wordCount: 3, sentenceCount: 1),
              let spectatorCount = Int(words[0]),
              let mapHash = Int32(words[2]) else {
            return nil
        }
        self.spectatorCount = spectatorCount
        self.locked = words[1] == "1"
        self.mapHash = mapHash
        self.mapName = sentences[0]
    }

    public var description: String {
        return "UPDATEBATTLEINFO \(spectatorCount) \(locked ? "1" : "0") \(mapHash) \(mapName)"
    }

    public func execute(on server: LobbyServer) {
        // TODO
    }
}
