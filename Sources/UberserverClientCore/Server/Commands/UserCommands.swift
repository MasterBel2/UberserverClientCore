//
//  SCUserCommands.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 12/11/19.
//  Copyright © 2019 MasterBel2. All rights reserved.
//

import Foundation
/**
 Sent by a client to inform the server about his changed status.

 # Note

 To tell out if a battle is "in-game", a client must check the in-game status of the host.
 */
public struct CSMyStatusCommand: CSCommand {

    let status: User.Status

    init(status: User.Status) {
        self.status = status
    }

    public init?(description: String) {
        guard let statusInt = Int(description) else {
                return nil
        }
        self.status = User.Status(rawValue: statusInt)
    }

    public func execute(on server: LobbyServer) {
        // TODO
    }

    public var description: String {
        return "MYSTATUS \(status.rawValue)"
    }
}

/**
 Tells the client that a new user joined a server. The client should add this user to his clients list, which he must maintain while he is
 connected to the server.
 */
public struct SCAddUserCommand: SCCommand {

    /// The username of the user just joined the server
    let username: String
    /// A two-character country code based on ISO 3166 standard.
    /// See http://www.iso.org/iso/en/prods-services/iso3166ma/index.html
    let country: String
    /// No longer used; set to 0
//    let cpu: String
    /// The user's unique ID
    let userID: Int
    /// A string of text sent by the client, typically identifying the lobby client they are using.
    let lobbyID: String

    init(username: String, country: String, cpu: String = "0", userID: Int, lobbyID: String) {
        self.username = username
        self.country = country
//        self.cpu = cpu
        self.userID = userID
        self.lobbyID = lobbyID
    }

    // MARK: - SCCommand

    public init?(description: String) {
        guard let (words, sentences) = try? wordsAndSentences(for: description, wordCount: 3, sentenceCount: 1),
            let userID = Int(words[2]) else {
            return nil
        }
        username = words[0]
        country = words[1]
//        cpu = words[2]
        self.userID = userID
        lobbyID = sentences[0]
    }

    public func execute(on connection: ThreadUnsafeConnection) {
        guard case let .authenticated(authenticatedSession) = connection.session else { return }
        let userProfile = User.Profile(id: userID, fullUsername: username, lobbyID: lobbyID)
        let user = User(profile: userProfile)
        authenticatedSession.userList.addItem(user, with: userID)
    }

    public var description: String {
        return "ADDUSER \(username) \(country) \(userID) \(lobbyID)"
//        return "ADDUSER \(username) \(country) \(cpu) \(userID) \(lobbyID)"
    }

}

public struct SCRemoveUserCommand: SCCommand {
	
	let username: String
	
	// MARK: - Manual Construction
	
	init(username: String) {
		self.username = username
	}
	
	// MARK: - SCCommand
	
    public init?(description: String) {
		guard let (words, _) = try? wordsAndSentences(for: description, wordCount: 1, sentenceCount: 0) else {
			return nil
		}
		username = words[0]
	}
	
    public func execute(on connection: ThreadUnsafeConnection) {
        guard case let .authenticated(authenticatedSession) = connection.session else { return }
        guard let userID = authenticatedSession.id(forPlayerNamed: username) else {
            return
        }
        authenticatedSession.userList.removeItem(withID: userID)
	}
	
    public var description: String {
		return "REMOVEUSER \(username)"
	}
}

public struct SCClientStatusCommand: SCCommand {
	
	let username: String
	let status: User.Status
	
	// MARK: - Manual Construction
	
	init(username: String, status: User.Status) {
		self.username = username
		self.status = status
	}
	
	// MARK: - SCCommand
	
    public init?(description: String) {
		guard let (words, _) = try? wordsAndSentences(for: description, wordCount: 2, sentenceCount: 0),
		let statusValue = Int(words[1]) else {
			return nil
		}
		username = words[0]
		status = User.Status(rawValue: statusValue)
	}
	
    public func execute(on connection: ThreadUnsafeConnection) {
        guard case let .authenticated(authenticatedSession) = connection.session,
              let userID = authenticatedSession.id(forPlayerNamed: username),
              let user = authenticatedSession.userList.items[userID] else {
            return
        }

        // Update battleroom before we update the status, so we can access the previous status
        if let battleroom = authenticatedSession.battleroom,
           userID == battleroom.battle.founderID,
           user.status.isIngame != status.isIngame,
           status.isIngame {
            battleroom.startGame()
        }

        user.status = status

        authenticatedSession.userList.respondToUpdatesOnItem(identifiedBy: userID)
    }

    public var description: String {
		return "CLIENTSTATUS \(username) \(status.rawValue)"
	}
}

