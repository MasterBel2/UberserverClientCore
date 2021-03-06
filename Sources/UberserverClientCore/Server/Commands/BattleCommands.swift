//
//  BattleCommands.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 12/11/19.
//  Copyright © 2019 MasterBel2. All rights reserved.
//

import Foundation

/**
 Sent by a client requesting to join a battle.
*/
struct CSJoinBattleCommand: CSCommand {
	
	let battleID: Int
	let password: String?
	/// A random, client-generated string (which is used to avoid account spoofing ingame, and will appear in script.txt).
	/// Note that if this argument is sent, a password must be sent too. If the battle is not passworded then an empty password should be sent.
	let scriptPassword: String?
	
	// MARK: - Manual Construction
	
	init(battleID: Int, password: String?, scriptPassword: String?) {
		self.battleID = battleID
		self.password = password
		self.scriptPassword = scriptPassword 
	}
	
	// MARK: - CSCommand
	
	init?(description: String) {
		guard let (words, _) = try? wordsAndSentences(for: description, wordCount: 1, sentenceCount: 0, optionalWords: 2, optionalSentences: 0),
			let battleID = Int(words[0]) else {
			return nil
		}
		self.battleID = battleID
		if words.count > 1 {
			password = words[1]
			scriptPassword = words.count == 3 ? words[2] : nil
		} else {
			password = nil
			scriptPassword = nil
		}
	}
	
	func execute(on server: LobbyServer) {
		#warning("TODO")
	}
	
	var description: String {
		return "JOINBATTLE \(battleID) \(password ?? "") \(scriptPassword ?? "")"
	}
}

/**
Sent by the client when he leaves a battle.

When this command is by the founder of a battle, it notifies that the battle is now closed.

If sent by the founder, the server responds with a BATTLECLOSED command.
*/
struct CSLeaveBattleCommand: CSCommand {
	
	// MARK: - Manual Construction
	
	init() {}
	
	// MARK: - CSCommand
	
	init?(description: String) {}
	
	func execute(on server: LobbyServer) {}
	
	var description: String {
		return "LEAVEBATTLE"
	}
}

/**
 Sent by a client to the server, telling him his battle status changed.

 # String Representation

 battleStatus: An integer, but with limited range: 0..2147483647 (use signed int and consider only positive values and zero) This number is sent as text. Each bit has its meaning:
 - b0 = undefined (reserved for future use)
 - b1 = ready (0=not ready, 1=ready)
 - b2..b5 = team no. (from 0 to 15. b2 is LSB, b5 is MSB)
 - b6..b9 = ally team no. (from 0 to 15. b6 is LSB, b9 is MSB)
 - b10 = mode (0 = spectator, 1 = normal player)
 - b11..b17 = handicap (7-bit number. Must be in range 0..100). Note: Only host can change handicap values of the players in the battle (with HANDICAP command). These 7 bits are always ignored in this command. They can only be changed using HANDICAP command.
 - b18..b21 = reserved for future use (with pre 0.71 versions these bits were used for team color index)
 - b22..b23 = sync status (0 = unknown, 1 = synced, 2 = unsynced)
 - b24..b27 = side (e.g.: arm, core, tll, ... Side index can be between 0 and 15, inclusive)
 - b28..b31 = undefined (reserved for future use)


 myTeamColor: Should be a 32-bit signed integer in decimal form (e.g. 255 and not FF) where each color channel should occupy 1 byte (e.g. in hexdecimal: $00BBGGRR, B = blue, G = green, R = red). Example: 255 stands for $000000FF.

 # Response
 The status change will communicated to relevant users via the CLIENTBATTLESTATUS and UPDATEBATTLEINFO commands.
 */
struct CSMyBattleStatusCommand: CSCommand {

    let battleStatus: Battleroom.UserStatus
    let color: Int32

    // MARK: - Manual Construction

    init(battleStatus: Battleroom.UserStatus, color: Int32) {
        self.battleStatus = battleStatus
        self.color = color
    }

    // MARK: - CSCommand

    init?(description: String) {
        guard let (words, _) = try? wordsAndSentences(for: description, wordCount: 2, sentenceCount: 0),
            let statusAsInt = Int(words[0]),
            let battleStatus = Battleroom.UserStatus(statusValue: statusAsInt),
            let color = Int32(words[1]) else {
            return nil
        }
        self.init(battleStatus: battleStatus, color: color)
    }

    func execute(on server: LobbyServer) {
        #warning("Serverside: TODO")
    }

    var description: String {
        return "MYBATTLESTATUS \(battleStatus.integerValue) \(color)"
    }
}

/**
 Notifies a client that their request to JOINBATTLE was successful, and that they have just joined the battle.

 Clients in the battle will be notified of the new user via JOINEDBATTLE.

 Next, the server will send a series of commands to the newly joined client, which might include DISABLEUNITS, ADDBOT, ADDSTARTRECT, SETSCRIPTTAGS and so on, along with multiple CLIENTBATTLESTATUS, in order to describe the current state of the battle to the joining client.

 If the battle has natType>0, the server will also send the clients IP port to the host, via the CLIENTIPPORT command. Someone who knows more about this should write more!
*/
struct SCJoinBattleCommand: SCCommand {
	
	let battleID: Int
	let hashCode: Int32
    let channelName: String
	
	// MARK: - Manual Construction
	
    init(battleID: Int, hashCode: Int32, channelName: String) {
		self.battleID = battleID
		self.hashCode = hashCode
        self.channelName = channelName
	}
	
	// MARK: - SCCommand
	
	init?(description: String) {
		guard let (words, _) = try? wordsAndSentences(for: description, wordCount: 3, sentenceCount: 0),
		let battleID = Int(words[0]),
		let hashCode = Int32(words[1]) else {
			return nil
		}
		
		self.battleID = battleID
		self.hashCode = hashCode
        channelName = words[2]
	}
	
	var description: String {
		return "JOINBATTLE \(battleID) \(hashCode) \(channelName)"
	}
    
    public func execute(on connection: ThreadUnsafeConnection) {
        guard case let .authenticated(authenticatedSession) = connection.session,
              let myID = authenticatedSession.myID else {
            return
        }
        guard authenticatedSession.battleroom == nil else {
            debugOnlyPrint("Was instructed to join a battleroom when already in one!")
            return
        }
        guard let battle = authenticatedSession.battleList.items[battleID] else {
            debugOnlyPrint("Was instructed to join a battleroom that doesn't exist!")
            return
        }

        // Must use client.userlist instead of battle.userlist because the client is added to the channel before he receives notification of a successful join of the battle.
        let battleroomChannel = Channel(title: battle.channel, rootList: authenticatedSession.userList, sendAction: { [weak connection] channel, message in
            connection?.send(CSSayCommand(channelName: battle.channel, message: message))
        })
        authenticatedSession.channelList.addItem(battleroomChannel, with: authenticatedSession.id(forChannelnamed: battleroomChannel.title))
        let battleroom = Battleroom(
            battle: battle,
            channel: battleroomChannel,
            sendCommandBlock: { [weak connection] command in
                connection?.send(command)
            },
            hashCode: hashCode,
            myID: myID
        )
        authenticatedSession.battleroom = battleroom
    }
}

/**
 Notifies a client that their request to JOINBATTLE was denied.
*/
struct SCJoinBattleFailedCommand: SCCommand {
	
	let reason: String
	
	// MARK: - Manual Construction
	
	init(reason: String) {
		self.reason = reason
	}
	
	// MARK: - SCCommand
	
	init?(description: String) {
		self.reason = description
	}
	
    func execute(on connection: ThreadUnsafeConnection) {}
	
	var description: String {
		return "JOINBATTLEFAILED \(reason)"
	}
}

struct SCClientBattleStatusCommand: SCCommand {
	
	let username: String
	let battleStatus: Battleroom.UserStatus
	let teamColor: Int32
	
	// MARK: - Manual Construction
	
	init(username: String, battleStatus: Battleroom.UserStatus, teamColor: Int32) {
		self.username = username
		self.battleStatus = battleStatus
		self.teamColor = teamColor
	}
	
	// MARK: - SCClientBattleStatusCommand
	
	init?(description: String) {
		guard let (words, _) = try? wordsAndSentences(for: description, wordCount: 3, sentenceCount: 0),
			let statusAsInt = Int(words[1]),
			let battleStatus = Battleroom.UserStatus(statusValue: statusAsInt),
			let teamColor = Int32(words[2]) else {
			return nil
		}
		self.init(username: words[0], battleStatus: battleStatus, teamColor: teamColor)
	}

    func execute(on connection: ThreadUnsafeConnection) {
        guard case let .authenticated(authenticatedSession) = connection.session,
              let battleroom = authenticatedSession.battleroom,
              let userID = authenticatedSession.id(forPlayerNamed: username) else {
            return
        }
        battleroom.updateUserStatus(battleStatus, forUserIdentifiedBy: userID)
        battleroom.colors[userID] = teamColor
    }

    var description: String {
        return "CLIENTBATTLESTATUS \(username) \(battleStatus.integerValue) \(teamColor)"
	}
}

struct SCRequestBattleStatusCommand: SCCommand {
	
	// MARK: - Manual Construction
	
	init() {}
	
	// MARK: - SCCommand
	
	init?(description: String) {}

    func execute(on connection: ThreadUnsafeConnection) {
        guard case let .authenticated(authenticatedSession) = connection.session,
              let battleroom = authenticatedSession.battleroom else {
            return
        }
        connection.send(CSMyBattleStatusCommand(
            battleStatus: battleroom.myBattleStatus,
            color: battleroom.myColor
        ))
    }

    var description: String {
        return "REQUESTBATTLESTATUS"
    }
}

struct SCAddBotCommand: SCCommand {
	
	let battleID: Int
	let name: String
	let owner: String
	let battleStatus: Battleroom.UserStatus
	let teamColor: Int32
	let aiDll: String
	
	// MARK: - Manual Construction
	
	init(battleID: Int, name: String, owner: String, battleStatus: Battleroom.UserStatus, teamColor: Int32, aiDll: String) {
		self.battleID = battleID
		self.name = name
		self.owner = owner
		self.battleStatus = battleStatus
		self.teamColor = teamColor
		self.aiDll = aiDll
	}
	
	// MARK: - SCCommand
	
	init?(description: String) {
		guard let (words, sentences) = try? wordsAndSentences(for: description, wordCount: 5, sentenceCount: 1),
			let battleID = Int(words[0]),
			let statusValue = Int(words[3]),
			let battleStatus = Battleroom.UserStatus(statusValue: statusValue),
			let teamColor = Int32(words[4])
		else {
			return nil
		}
		self.battleID = battleID
		name = words[1]
		owner = words[2]
		self.battleStatus = battleStatus
		self.teamColor = teamColor
		aiDll = sentences[0]
	}

    public func execute(on connection: ThreadUnsafeConnection) {
        guard case let .authenticated(authenticatedSession) = connection.session,
              let battleroom = authenticatedSession.battleroom,
              let ownerID = authenticatedSession.id(forPlayerNamed: owner),
              let ownerUser = authenticatedSession.userList.items[ownerID] else {
            return
        }
        let bot = Battleroom.Bot(name: name, owner: ownerUser, status: battleStatus, color: teamColor)
        battleroom.bots.append(bot)
	}
	
	var description: String {
		return "ADDBOT \(battleID) \(name) \(owner) \(battleStatus.integerValue) \(teamColor) \(aiDll)"
	}
}

struct SCRemoveBotCommand: SCCommand {
	
	let botName: String
	
	// MARK: - Manual Construction
	
	init(botName: String) {
		self.botName = botName
	}
	
	// MARK: - SCCommand
	
	init?(description: String) {
		guard let (words, _) = try? wordsAndSentences(for: description, wordCount: 1, sentenceCount: 0) else {
			return nil
		}
		self.botName = words[0]
	}
	
    public func execute(on connection: ThreadUnsafeConnection) {
        guard case let .authenticated(authenticatedSession) = connection.session,
              let battleroom = authenticatedSession.battleroom else {
            return
        }
        battleroom.bots = battleroom.bots.filter { $0.name != botName }
	}
	
	var description: String {
		return "REMOVEBOT \(botName)"
	}
}

struct SCUpdateBotCommand: SCCommand {
	
	let battleID: Int
	let name: String
	let battleStatus: Battleroom.UserStatus
	let teamColor: Int32
	
	// MARK: - Manual Construction
	
	init(battleID: Int, name: String, battleStatus: Battleroom.UserStatus, teamColor: Int32) {
		self.battleID = battleID
		self.name = name
		self.battleStatus = battleStatus
		self.teamColor = teamColor
	}
	
	// MARK: - SCCommand
	
	init?(description: String) {
		guard let (words, _) = try? wordsAndSentences(for: description, wordCount: 4, sentenceCount: 0),
			let battleID = Int(words[0]),
			let statusValue = Int(words[2]),
			let battleStatus = Battleroom.UserStatus(statusValue: statusValue),
			let teamColor = Int32(words[3]) else {
			return nil
		}
		self.battleID = battleID
		name = words[1]
		self.battleStatus = battleStatus
		self.teamColor = teamColor
	}
	
    func execute(on connection: ThreadUnsafeConnection) {
        guard case let .authenticated(authenticatedSession) = connection.session,
              let bot = authenticatedSession.battleroom?.bots.first(where: { $0.name == name }) else {
            return
        }

        bot.status = battleStatus
        bot.color = teamColor
	}
	
	var description: String {
		return "UPDATEBOT \(name)"
	}
}

public struct StartRect {
	public let left: Int
	public let top: Int
	public let right: Int
	public let bottom: Int
	
	public func scaled<F: FloatingPoint>() -> (x: F, y: F, width: F, height: F) {
		let floatLeft = F(left)
		let floatRight = F(right)
		let floatTop = F(top)
		let floatBottom = F(bottom)
		// y = 0 correlates to bottom = 200.
		return (x: floatLeft / 200, y: (200 - floatBottom) / 200, width: (floatRight - floatLeft) / 200, height: (floatBottom - floatTop) / 200)
	}
}

struct SCAddStartRectCommand: SCCommand {
	
	let allyNo: Int
	let rect: StartRect
	
	// MARK: - Manual Construction
	
	init(rect: StartRect, allyNo: Int) {
		self.rect = rect
		self.allyNo = allyNo
	}
	
	// MARK: - SCCommand
	
	init?(description: String) {
		guard let (words, _) = try? wordsAndSentences(for: description, wordCount: 5, sentenceCount: 0) else {
			return nil
		}
		let integers = words.compactMap { Int($0) }
		guard integers.count == 5 else {
			return nil
		}
		self.allyNo = integers[0]
		rect = StartRect(
			left: integers[1],
			top: integers[2],
			right: integers[3],
			bottom: integers[4]
		)
	}
	
    func execute(on connection: ThreadUnsafeConnection) {
        guard case let .authenticated(authenticatedSession) = connection.session,
              let battleroom = authenticatedSession.battleroom else {
            return
        }
        battleroom.addStartRect(rect, for: allyNo)
	}
	
	var description: String {
		return "ADDSTARTRECT \(allyNo) \(rect.left) \(rect.top) \(rect.right) \(rect.bottom)"
	}
}

struct SCRemoveStartRectCommand: SCCommand {
	
	let allyNo: Int
	
	// MARK: - Manual Construction
	
	init(allyNo: Int) {
		self.allyNo = allyNo
	}
	
	// MARK: - SCCommand
	
	init?(description: String) {
		guard let (words, _) = try? wordsAndSentences(for: description, wordCount: 1, sentenceCount: 0),
			let allyNo = Int(words[0]) else {
			return nil
		}
		self.allyNo = allyNo
	}
	
    func execute(on connection: ThreadUnsafeConnection) {
        guard case let .authenticated(authenticatedSession) = connection.session,
              let battleroom = authenticatedSession.battleroom else {
            return
        }
        battleroom.removeStartRect(for: allyNo)

	}
	
	var description: String {
		return "REMOVESTARTRECT \(allyNo)"
	}
}

struct SCSetScriptTagsCommand: SCCommand {

	let tags: [ScriptTag]

	// MARK: - Manual Construction

	init(tags: [ScriptTag]) {
		self.tags = tags
	}

	// MARK: - SCCommand

	init?(description: String) {
        tags = description.split(separator: "\t").compactMap({ ScriptTag(String($0)) })
	}

    public func execute(on connection: ThreadUnsafeConnection) {
        guard case let .authenticated(authenticatedSession) = connection.session,
              let battleroom = authenticatedSession.battleroom else {
            return
        }
        for tag in tags {
            switch tag.category {
            case "players":
                guard tag.path[3] == "skill",
                      let playerID = authenticatedSession.id(forPlayerNamed: tag.path[2]) else {
                    continue
                }
                battleroom.trueSkills[playerID] = tag.value
                (battleroom.allyTeamLists + [battleroom.spectatorList]).filter({ $0.sortedItemsByID.contains(playerID)}).forEach({ $0.respondToUpdatesOnItem(identifiedBy: playerID) })
            case "modoptions":
                battleroom.modOptions[tag.path[1]] = tag.value
            default:
                print("Unrecognised script tag: \(tag)")
            }
        }
    }

	var description: String {
        return "SETSCRIPTTAGS \(tags.map({ $0.description }).joined(separator: "\t"))"
	}
}

struct ScriptTag: CustomStringConvertible {
    let path: [String]
    let value: String

    var category: String {
        return path[1]
    }

    init?(_ string: String) {
        let parts = string.split(separator: "=")
        guard parts.count == 2 else { return nil }
        path = parts[0].split(separator: "/").map({ String($0) })
        guard path.count > 2 else {
            return nil
        }
        value = String(parts[1])
    }
    var description: String {
        return "\(path.joined(separator: "/"))=\(value)"
    }
}

struct SCRemoveScriptTagsCommand: SCCommand {

	let keys: [[String]]

	// MARK: - Manual Construction

	init(keys: [[String]]) {
		self.keys = keys
	}

	// MARK: - SCCommand

	init?(description: String) {
        keys = description.split(separator: "\t").map({ $0.split(separator: "/").map({ String($0) }) })
	}

    func execute(on connection: ThreadUnsafeConnection) {
        guard case let .authenticated(authenticatedSession) = connection.session,
              let battleroom = authenticatedSession.battleroom else { return }
        for key in keys {
            guard key.count >= 2 else { continue }
            switch key[1] {
            case "players":
                guard key.count == 4, key[3] == "skill",
                      let playerID = authenticatedSession.id(forPlayerNamed: key[2]) else {
                    continue
                }
                battleroom.trueSkills.removeValue(forKey: playerID)
            case "modOptions":
                guard key.count == 3 else { continue }
                battleroom.modOptions.removeValue(forKey: key[2])
            default:
                continue
            }
        }
    }

    var description: String {
        return "REMOVESCRIPTTAGS \(keys.map({ $0.joined(separator: "/") }).joined(separator: " "))"
    }
}
struct SCJoinBattleRequestCommand: SCCommand {
	
	let username: String
	let ip: String
	
	// MARK: - Manual Construction
	
	init(username: String, ip: String) {
		self.username = username
		self.ip = ip
	}
	
	// MARK: - SCCommand
	
	init?(description: String) {
		guard let (words, _) = try? wordsAndSentences(for: description, wordCount: 2, sentenceCount: 0) else {
			return nil
		}
		username = words[0]
		ip = words[1]
	}
	
    func execute(on connection: ThreadUnsafeConnection) {
		#warning("TODO")
	}
	
	var description: String {
		return "JOINBATTLEREQUEST \(username) \(ip)"
	}
}

struct SCJoinedBattleCommand: SCCommand {
	
	let battleID: Int
	let username: String
	let scriptPassword: String?
	
	// MARK: - Manual Construction
	
	init(battleID: Int, username: String, scriptPassword: String?) {
		self.battleID = battleID
		self.username = username
		self.scriptPassword = scriptPassword
	}
	
	// MARK: - SCCommand
	
	init?(description: String) {
		guard let (words, _) = try? wordsAndSentences(for: description, wordCount: 2, sentenceCount: 0, optionalWords: 1),
			let battleID = Int(words[0]) else {
			return nil
		}
		self.battleID = battleID
		self.username = words[1]
		scriptPassword = words.count == 3 ? words[2] : nil
	}
	
    func execute(on connection: ThreadUnsafeConnection) {
        guard case let .authenticated(authenticatedSession) = connection.session,
              let battle = authenticatedSession.battleList.items[battleID],
              let userID = authenticatedSession.id(forPlayerNamed: username) else {
            return
        }
        battle.userList.addItemFromParent(id: userID)
        authenticatedSession.battleList.respondToUpdatesOnItem(identifiedBy: battleID)
    }
	
	var description: String {
		var string = "JOINEDBATTLE \(battleID) \(username)"
		if let scriptPassword = scriptPassword {
			string += " \(scriptPassword)"
		}
		return string
	}
}

/**
 Sent by the server to all users when a client left a battle (or got disconnected from the server). 
 */
struct SCLeftBattleCommand: SCCommand {
	
	let battleID: Int
	let username: String
	
	// MARK: - Manual Construction
	
	init(battleID: Int, username: String) {
		self.battleID = battleID
		self.username = username
	}
	
	// MARK: - SCCommand
	
	init?(description: String) {
		guard let (words, _) = try? wordsAndSentences(for: description, wordCount: 2, sentenceCount: 0),
			let battleID = Int(words[0]) else {
			return nil
		}
		self.battleID = battleID
		self.username = words[1]
	}
	
    func execute(on connection: ThreadUnsafeConnection) {
        guard case let .authenticated(authenticatedSession) = connection.session,
              let battle = authenticatedSession.battleList.items[battleID],
              let userID = authenticatedSession.id(forPlayerNamed: username) else {
            return
        }
        battle.userList.removeItem(withID: userID)
        authenticatedSession.battleList.respondToUpdatesOnItem(identifiedBy: battleID)
    }
	
	var description: String {
		return "LEFTBATTLE \(battleID) \(username)"
	}
}

/**
 Sent to all users to notify that a battle has been closed.

 When a battle host sends a `CSLeaveBattleCommand`, the server will respond with a `SCBattleClosedCommand`.
 */
struct SCBattleClosedCommand: SCCommand {
	
	let battleID: Int
	
	// MARK: - Manual Construction
	
	init(battleID: Int) {
		self.battleID = battleID
	}
	
	// MARK: - SCCommand
	
	init?(description: String) {
		guard let (words, _) = try? wordsAndSentences(for: description, wordCount: 1, sentenceCount: 0),
			let battleID = Int(words[0]) else {
			return nil
		}
		self.battleID = battleID
	}
	
    func execute(on connection: ThreadUnsafeConnection) {
        guard case let .authenticated(authenticatedSession) = connection.session else {
            return
        }
        if let battleroom = authenticatedSession.battleroom,
           battleroom.battle === authenticatedSession.battleList.items[battleID] {
            authenticatedSession.battleroom = nil
        }
        authenticatedSession.battleList.removeItem(withID: battleID)
	}
	
	var description: String {
		return "BATTLECLOSED \(battleID)"
	}
}

/// Sent as a response to a client's UDP packet (used with "hole punching" NAT traversal technique).
struct SCUDPSourcePortCommand: SCCommand {
	
	let port: Int
	
	// MARK: - Manual Construction
	
	init(port: Int) {
		self.port = port
	}
	
	// MARK: - SCCommand
	
	init?(description: String) {
		guard let (words, _) = try? wordsAndSentences(for: description, wordCount: 1, sentenceCount: 0),
			let port = Int(words[0]) else {
			return nil
		}
		self.port = port
	}
	
    func execute(on connection: ThreadUnsafeConnection) {
		#warning("todo")
	}
	
	var description: String {
		return "UDPSOURCEPORT \(port)"
	}
}

struct SCClientIPPortCommand: SCCommand {
	
	let username: String
	let ip: String
	let port: Int
	
	// MARK: - Manual Construction
	
	init(username: String, ip: String, port: Int) {
		self.username = username
		self.ip = ip
		self.port = port
	}
	
	// MARK: - SCCommand
	
	init?(description: String) {
		guard let (words, _) = try? wordsAndSentences(for: description, wordCount: 3, sentenceCount: 0),
			let port = Int(words[2]) else {
			return nil
		}
		self.username = words[0]
		self.ip = words[1]
		self.port = port
	}
	
    func execute(on connection: ThreadUnsafeConnection) {
		#warning("todo")
	}
	
	var description: String {
		return "HOSTPORT \(port)"
	}
}



/// Sent by the server to all clients participating in the battle, except for the host, notifying them about the (possibly new) host port.
struct SCHostPortCommand: SCCommand {
	
	let port: Int
	
	// MARK: - Manual Construction
	
	init(port: Int) {
		self.port = port
	}
	
	// MARK: - SCCommand
	
	init?(description: String) {
		guard let (words, _) = try? wordsAndSentences(for: description, wordCount: 1, sentenceCount: 0),
			let port = Int(words[0]) else {
			return nil
		}
		self.port = port
	}
	
    func execute(on connection: ThreadUnsafeConnection) {
		#warning("todo")
	}
	
	var description: String {
		return "HOSTPORT \(port)"
	}
}

/**
 Sent by the server to all registered clients, telling them some of the parameters of the battle changed. A battle's internal changes, like starting metal, energy, starting position etc., are sent only to clients participating in the battle (via the SETSCRIPTTAGS command). 
*/
struct SCUpdateBattleInfoCommand: SCCommand {
	
	let battleID: Int
	let spectatorCount: Int
	let locked: Bool
	let mapHash: Int32
	let mapName: String
	
	// MARK: - Manual Construction
	
	init(battleID: Int, spectatorCount: Int, locked: Bool, mapHash: Int32, mapName: String) {
		self.battleID = battleID
		self.spectatorCount = spectatorCount
		self.mapName = mapName
		self.mapHash = mapHash
		self.locked = locked
	}
	
	// MARK: - SCCommand
	
	init?(description: String) {
		guard let (words, sentences) = try? wordsAndSentences(for: description, wordCount: 4, sentenceCount: 1),
			let battleID = Int(words[0]),
			let spectatorCount = Int(words[1]),
			let mapHash = Int32(words[3]) else {
			return nil
		}
		self.battleID = battleID
		self.spectatorCount = spectatorCount
		locked = words[2] == "1"
		self.mapHash = mapHash
		mapName = sentences[0]
	}
	
    func execute(on connection: ThreadUnsafeConnection) {
        guard case let .authenticated(authenticatedSession) = connection.session,
              let battle = authenticatedSession.battleList.items[battleID] else {
            return
        }
        battle.spectatorCount = spectatorCount
        battle.isLocked = locked
        battle.mapIdentification = Battle.MapIdentification(name: mapName, hash: mapHash)
        authenticatedSession.battleList.respondToUpdatesOnItem(identifiedBy: battleID)
    }

	var description: String {
		return "UPDATEBATTLEINFO \(battleID) \(spectatorCount) \(locked ? 1 : 0) \(mapHash) \(mapName)"
	}
}

/// Sent by the server to notify the battle host that the named user should be kicked from the battle in progress.
struct SCKickFromBattleCommand: SCCommand {
	
	let battleID: Int
	let username: String
	
	// MARK: - Manual Construction
	
	init(battleID: Int, username: String) {
		self.battleID = battleID
		self.username = username
	}
	
	// MARK: - SCCommand
	
	init?(description: String) {
		guard let (words, _) = try? wordsAndSentences(for: description, wordCount: 2, sentenceCount: 0),
			let battleID = Int(words[0]) else {
			return nil
		}
		self.battleID = battleID
		username = words[1]
	}
	
    func execute(on connection: ThreadUnsafeConnection) {
        guard case let .authenticated(authenticatedSession) = connection.session else { return }
        if authenticatedSession.battleroom != nil {
            authenticatedSession.battleroom = nil
            #warning("todo: Notify the user")
        }
	}
	
	var description: String {
		return "KICKFROMBATTLE \(battleID) \(username)"
	}
}

/**
Sent to a client that was kicked from their current battle by the battle founder.

The client does not need to send LEAVEBATTLE, as removal has already been done by the server. The only purpose of this command is to notify the client that they were kicked. (The client will also recieve a corresponding LEFTBATTLE notification.)
*/
struct SCForceQuitBattleCommand: SCCommand {
	
	// MARK: - Manual Construction
	
	init() {}
	
	// MARK: - SCCommand
	
	init?(description: String) {}
	
    func execute(on connection: ThreadUnsafeConnection) {
        guard case let .authenticated(authenticatedSession) = connection.session else { return }
        if authenticatedSession.battleroom != nil {
            authenticatedSession.battleroom = nil
            #warning("todo: Notify the user")
        }
    }

    var description: String {
        return "FORCEQUITBATTLE"
    }
}

/**
Sent by the server to all clients in a battle, telling them that some units have been added to disabled units list. Also see the DISABLEUNITS command.
*/
struct SCDisableUnitsCommand: SCCommand {
	
	let units: [String]
	
	// MARK: - Manual Construction
	
	init(units: [String]) {
		self.units = units
	}
	
	// MARK: - SCCommand
	
	init?(description: String) {
		guard let (words, _) = try? wordsAndSentences(for: description, wordCount: 1, sentenceCount: 0, optionalWords: 1000) else {
			return nil
		}
		units = words
	}
	
    func execute(on connection: ThreadUnsafeConnection) {
        guard case let .authenticated(authenticatedSession) = connection.session else { return }
        authenticatedSession.battleroom?.disabledUnits.append(contentsOf: units)
	}
	
	var description: String {
		return "DISABLEUNITS \(units.joined(separator: " "))"
	}
}

/**
Sent by the server to all clients in a battle, telling them that some units have been added to enabled units list. Also see the DISABLEUNITS command.
*/
struct SCEnableUnitsCommand: SCCommand {
	
	let units: [String]
	
	// MARK: - Manual Construction
	
	init(units: [String]) {
		self.units = units
	}
	
	// MARK: - SCCommand
	
	init?(description: String) {
		guard let (words, _) = try? wordsAndSentences(for: description, wordCount: 1, sentenceCount: 0, optionalWords: 1000) else {
			return nil
		}
		units = words
	}
	
    func execute(on connection: ThreadUnsafeConnection) {
        guard case let .authenticated(authenticatedClient) = connection.session else { return }
        authenticatedClient.battleroom?.disabledUnits.removeAll(where: { units.contains($0) })
    }
	
	var description: String {
		return "ENABLEUNITS \(units.joined(separator: " "))"
	}
}

/**
Sent to notify a client that another user requested that a "ring" sound be played to them.
*/
struct SCRingCommand: SCCommand {
	
	let username: String
	
	// MARK: - Manual Construction
	
	init(username: String) {
		self.username = username
	}
	
	// MARK: - SCCommand
	
	init?(description: String) {
		username = description
	}
	
    func execute(on connection: ThreadUnsafeConnection) {
		#warning("todo")
	}
	
	var description: String {
		return "RING \(username)"
	}
}
