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

    public static let title = "SAYPRIVATE"

    let intendedRecipient: String
    let message: String

    init(intendedRecipient: String, message: String) {
        self.intendedRecipient = intendedRecipient
        self.message = message
    }

    // MARK: CSCommand

    public init?(payload: String) {
        guard let (words, sentences) = try? wordsAndSentences(for: payload, wordCount: 1, sentenceCount: 1) else {
            return nil
        }

        intendedRecipient = words[0]
        message = sentences[0]
    }

    public func execute(on server: LobbyServer) {
        // TODO
    }

    public var payload: String {
        return "\(intendedRecipient) \(message)"
    }
}

/// Sent to a client that just sent a SAYPRIVATE command.
///
/// This notifies the client that the server sent the private message on to its intended recipient.
public struct SCSayPrivateCommand: SCCommand {

    public static let title = "SAYPRIVATE"
	
	let username: String
	let message: String
	
	// MARK: - Manual Construction
	
	init(username: String, message: String) {
		self.username = username
		self.message = message
	}
	
	// MARK: - SCCommand
	
    public init?(payload: String) {
		guard let (words, sentences) = try? wordsAndSentences(for: payload, wordCount: 1, sentenceCount: 1) else {
			return nil
		}
		username = words[0]
		message = sentences[0]
	}
    
    public func execute(on connection: ThreadUnsafeConnection) {
        guard case let .authenticated(authenticatedSession) = connection.session,
              let userID = authenticatedSession.id(forPlayerNamed: username),
              let channel = authenticatedSession.privateMessageChannel(withUserNamed: username, userID: userID),
              let myID = authenticatedSession.myID else {
            return
        }

        channel.receivedNewMessage(
            ChatMessage(
                time: Date(),
                senderID: myID,
                senderName: authenticatedSession.username,
                content: message,
                isIRCStyle: false
            )
        )
    }

    public var payload: String {
		return "\(username) \(message)"
	}
}

/// Sends a private message on to its intended recipient.
public struct SCSaidPrivateCommand: SCCommand {

    public static let title = "SAIDPRIVATE"
	
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
	
    public init?(payload: String) {
		guard let (words, sentences) = try? wordsAndSentences(for: payload, wordCount: 1, sentenceCount: 1) else {
			return nil
		}
		username = words[0]
        message = sentences[0]
    }

    public func execute(on connection: ThreadUnsafeConnection) {
        guard case let .authenticated(authenticatedSession) = connection.session,
              let senderID = authenticatedSession.id(forPlayerNamed: username),
              let channel = authenticatedSession.privateMessageChannel(withUserNamed: username, userID: senderID),
              let sender = authenticatedSession.userList.items[senderID] else {
            return
        }

        if handleSaidEncodedCommand(authenticatedClient: authenticatedSession, connection: connection, senderID: senderID, sender: sender, message: message, availableCommands: saidPrivateEncodableCommands) { return }


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
	
    public var payload: String {
		return "\(username) \(message)"
	}
}

public struct SCSayPrivateEXCommand: SCCommand {

    public static let title = "SAYPRIVATEEX"
	
	let username: String
	let message: String
	
	// MARK: - Manual Construction
	
	init(username: String, message: String) {
		self.username = username
		self.message = message
	}
	
	// MARK: - SCCommand
	
    public init?(payload: String) {
		guard let (words, sentences) = try? wordsAndSentences(for: payload, wordCount: 1, sentenceCount: 1) else {
			return nil
		}
        username = words[0]
        message = sentences[1]
    }
    
    public func execute(on connection: ThreadUnsafeConnection) {
        guard case let .authenticated(authenticatedSession) = connection.session,
              let userID = authenticatedSession.id(forPlayerNamed: username),
              let channel = authenticatedSession.privateMessageChannel(withUserNamed: username, userID: userID),
              let myID = authenticatedSession.myID,
              let myUsername = authenticatedSession.userList.items[myID]?.profile.fullUsername else {
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

    public var payload: String {
        return "\(username) \(message)"
    }
}

public struct SCSaidPrivateEXCommand: SCCommand {

    public static let title = "SAIDPRIVATEEX"
	
	let username: String
	let message: String
	
	// MARK: - Manual Construction
	
	init(username: String, message: String) {
		self.username = username
		self.message = message
	}
	
	// MARK: - SCCommand
	
    public init?(payload: String) {
		guard let (words, sentences) = try? wordsAndSentences(for: payload, wordCount: 1, sentenceCount: 1) else {
            return nil
        }
        username = words[0]
        message = sentences[1]
    }

    public func execute(on connection: ThreadUnsafeConnection) {
        guard case let .authenticated(authenticatedSession) = connection.session else { return }
        guard let userID = authenticatedSession.id(forPlayerNamed: username),
              let channel = authenticatedSession.privateMessageChannel(withUserNamed: username, userID: userID) else {
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

    public var payload: String {
        return "\(username) \(message)"
    }
}
