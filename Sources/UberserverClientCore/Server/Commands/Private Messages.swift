//
//  Private Messages.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 12/11/19.
//  Copyright © 2019 MasterBel2. All rights reserved.
//

import Foundation

/// Send a private chat message to an other client.
public struct CSSayPrivateCommand: CSCommand {
    let intendedRecipient: String
    let message: String

    init(intendedRecipient: String, message: String) {
        self.intendedRecipient = intendedRecipient
        self.message = message
    }

    // MARK: CSCommand

    public init?(description: String) {
        guard let (words, sentences) = try? wordsAndSentences(for: description, wordCount: 1, sentenceCount: 1) else {
            return nil
        }

        intendedRecipient = words[0]
        message = sentences[0]
    }

    public func execute(on server: LobbyServer) {
        // TODO
    }

    public var description: String {
        return "SAYPRIVATE \(intendedRecipient) \(message)"
    }
}

/// Sent to a client that just sent a SAYPRIVATE command.
///
/// This notifies the client that the server sent the private message on to its intended recipient.
public struct SCSayPrivateCommand: SCCommand {
	
	let username: String
	let message: String
	
	// MARK: - Manual Construction
	
	init(username: String, message: String) {
		self.username = username
		self.message = message
	}
	
	// MARK: - SCCommand
	
    public init?(description: String) {
		guard let (words, sentences) = try? wordsAndSentences(for: description, wordCount: 1, sentenceCount: 1) else {
			return nil
		}
		username = words[0]
		message = sentences[0]
	}
	
    public func execute(on client: Client) {
        guard let userID = client.id(forPlayerNamed: username),
            let channel = client.privateMessageChannel(withUserNamed: username, userID: userID),
              let myID = client.myID,
              let myUsername = client.userList.items[myID]?.profile.fullUsername else {
            return
        }

        channel.receivedNewMessage(
            ChatMessage(
                time: Date(),
                senderID: myID,
                senderName: myUsername,
                content: message,
                isIRCStyle: false
            )
        )
	}
	
    public var description: String {
		return "SAYPRIVATE \(username) \(message)"
	}
}

/// Sends a private message on to its intended recipient.
public struct SCSaidPrivateCommand: SCCommand {
	
	/// The username of the message's sender.
	let username: String
	/// The contents of the message.
	let message: String
	
	// MARK: - Manual Construction
	
	init(username: String, message: String) {
		self.username = username
		self.message = message
	}
	
	// MARK: - SCCommand
	
    public init?(description: String) {
		guard let (words, sentences) = try? wordsAndSentences(for: description, wordCount: 1, sentenceCount: 1) else {
			return nil
		}
		username = words[0]
		message = sentences[0]
	}
	
    public func execute(on client: Client) {
        guard let senderID = client.id(forPlayerNamed: username),
              let channel = client.privateMessageChannel(withUserNamed: username, userID: senderID),
              let sender = client.userList.items[senderID] else {
            return
        }

        if handleSaidEncodedCommand(client: client, user: sender, message: message, availableCommands: saidPrivateEncodableCommands) { return }


        channel.receivedNewMessage(
            ChatMessage(
                time: Date(),
                senderID: senderID,
				senderName: sender.profile.fullUsername,
                content: message,
                isIRCStyle: false
            )
        )
	}
	
    public var description: String {
		return "SAIDPRIVATE \(username) \(message)"
	}
}

public struct SCSayPrivateEXCommand: SCCommand {
	
	let username: String
	let message: String
	
	// MARK: - Manual Construction
	
	init(username: String, message: String) {
		self.username = username
		self.message = message
	}
	
	// MARK: - SCCommand
	
    public init?(description: String) {
		guard let (words, sentences) = try? wordsAndSentences(for: description, wordCount: 1, sentenceCount: 1) else {
			return nil
		}
        username = words[0]
        message = sentences[1]
    }

    public func execute(on client: Client) {
        guard let userID = client.id(forPlayerNamed: username),
              let channel = client.privateMessageChannel(withUserNamed: username, userID: userID),
              let myID = client.myID,
              let myUsername = client.userList.items[myID]?.profile.fullUsername else {
            return
        }

        channel.receivedNewMessage(
            ChatMessage(
                time: Date(),
                senderID: myID,
                senderName: myUsername,
                content: message,
                isIRCStyle: true
            )
        )
	}
	
    public var description: String {
		return "SAYPRIVATEEX \(username) \(message)"
	}
}

public struct SCSaidPrivateEXCommand: SCCommand {
	
	let username: String
	let message: String
	
	// MARK: - Manual Construction
	
	init(username: String, message: String) {
		self.username = username
		self.message = message
	}
	
	// MARK: - SCCommand
	
    public init?(description: String) {
		guard let (words, sentences) = try? wordsAndSentences(for: description, wordCount: 1, sentenceCount: 1) else {
			return nil
		}
		username = words[0]
		message = sentences[1]
	}
	
    public func execute(on client: Client) {
        guard let userID = client.id(forPlayerNamed: username),
              let channel = client.privateMessageChannel(withUserNamed: username, userID: userID) else {
            return
        }

        channel.receivedNewMessage(
            ChatMessage(
                time: Date(),
                senderID: userID,
                senderName: username,
                content: message,
                isIRCStyle: true
            )
        )
	}
	
    public var description: String {
		return "SAIDPRIVATEEX \(username) \(message)"
	}
}
