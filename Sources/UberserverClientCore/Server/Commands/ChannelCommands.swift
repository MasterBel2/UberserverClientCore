//
//  JoinCommand.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 1/9/19.
//  Copyright © 2019 MasterBel2. All rights reserved.
//

import Foundation

/// 
public struct SCJoinCommand: SCCommand {

    public let channelName: String

    // MARK: - Manual construction

    public init(channelName: String) {
        self.channelName = channelName
    }

    // MARK: - SCCommand

    public init?(description: String) {
        if description == "" { return nil }
        self.channelName = description
    }

    public var description: String {
        return "JOIN \(channelName)"
    }

    public func execute(on client: Client) {
        client.inAuthenticatedState { authenticatedClient, connection in
            let channelID = authenticatedClient.id(forChannelnamed: channelName)
            guard authenticatedClient.channelList.items[channelID] == nil else {
                return
            }
            let channel = Channel(title: channelName, rootList: authenticatedClient.userList, sendAction: { [weak connection] channel, message in
                connection?.send(CSSayCommand(channelName: channelName, message: message))
            })
            authenticatedClient.channelList.addItem(channel, with: channelID)
        }
    }
}

public struct SCJoinFailedCommand: SCCommand {

    public let channelName: String
    public let reason: String

    // MARK: - Manual construction

    public init(channelName: String, reason: String) {
        self.channelName = channelName
        self.reason = reason
    }

    // MARK: - SCCommand

    public init?(description: String) {
        guard let (words, sentences) = try? wordsAndSentences(for: description, wordCount: 1, sentenceCount: 1),
              let channelName = words.first,
              let reason = sentences.first else {
            return nil
        }
        self.channelName = channelName
        self.reason = reason
    }

    public var description: String {
        return "JOINFAILED \(channelName) \(reason)"
    }

    public func execute(on client: Client) {
        client.receivedError(.joinFailed(channel: channelName, reason: reason))
    }
}

public struct CSJoinCommand: CSCommand {

    public let channelName: String
    public let key: String?

    // MARK: - Manual construction

    public init(channelName: String, key: String?) {
        self.channelName = channelName
        self.key = key
    }

    // MARK: - CSCommand

    public init?(description: String) {
        guard let (words, _) = try? wordsAndSentences(for: description, wordCount: 2, sentenceCount: 0, optionalWords: 1) else {
            return nil
        }
        self.channelName = words[0]
        self.key = nil
    }

    public var description: String {
        return "JOIN \(channelName)"
    }

    public func execute(on server: LobbyServer) {
        
    }
}

public struct SCChannelTopicCommand: SCCommand {

    public let channelName: String
    public let author: String
    public let topic: String

    // MARK: - Manual construction

    public init(channelName: String, author: String, topic: String) {
        self.channelName = channelName
        self.author = author
        self.topic = topic
    }

    // MARK: - SCCommand

    public init?(description: String) {
        guard let (words, sentences) = try? wordsAndSentences(for: description, wordCount: 2, sentenceCount: 1) else {
                return nil
        }
        channelName = words[0]
        author = words[1]
        topic = sentences[0]
    }

    public var description: String {
        return "CHANNELTOPIC \(channelName) \(author) \(topic)"
    }

    public func execute(on client: Client) {
        client.inAuthenticatedState { authenticatedState, _ in
            let channelID = authenticatedState.id(forChannelnamed: channelName)
            guard let channel = authenticatedState.channelList.items[channelID] else {
                return
            }
            channel.topic = topic
        }
    }
}

/// A request to change a channel's topic, typically sent by a priveleged user.
public struct CSChannelTopicCommand: CSCommand {

    public let channelName: String
    public let topic: String

    // MARK: - Manual construction

    public init(channelName: String, topic: String) {
        self.channelName = channelName
        self.topic = topic
    }

    // MARK: - CSCommand

    public init?(description: String) {
        guard let (words, sentences) = try? wordsAndSentences(for: description, wordCount: 1, sentenceCount: 1) else {
            return nil
        }
        channelName = words[0]
        topic = sentences[0]
    }

    public var description: String {
        return "CHANNELTOPIC \(channelName) \(topic)"
    }

    public func execute(on server: LobbyServer) {

    }
}

/**
 Sent by a client when requesting to leave a channel.

 Note that when the client is disconnected, the client is automatically removed from all channels.
 */
public struct CSLeaveCommand: CSCommand {

    public let channelName: String

    // MARK: - Manual construction

    public init(channelName: String) {
        self.channelName = channelName
    }

    // MARK: - CSCommand

    public init?(description: String) {
        guard let (words, _) = try? wordsAndSentences(for: description, wordCount: 1, sentenceCount: 0) else {
            return nil
        }
        channelName = words[0]
    }

    public var description: String {
        return "LEAVE \(channelName)"
    }

    public func execute(on server: LobbyServer) {
        
    }
}

/**
 Sent by the server to all clients in a channel. Used to broadcast messages in a channel.
 */
public struct SCChannelMessageCommand: SCCommand {

    public let channelName: String
    public let message: String

    // MARK: - Manual construction

    public init(channelName: String, message: String) {
        self.channelName = channelName
        self.message = message
    }

    // MARK: - SCCommand

    public init?(description: String) {
        guard let (words, sentences) = try? wordsAndSentences(for: description, wordCount: 1, sentenceCount: 1) else {
            return nil
        }
        channelName = words[0]
        message = sentences[0]
    }

    public var description: String {
        return "CHANNELMESSAGE \(channelName) \(message)"
    }

    public func execute(on client: Client) {
        #warning("Incomplete implementation")
    }
}

/**
Sent to request that a "ring" sound to be played to other user.
*/
public struct CSRingCommand: CSCommand {
	
	/// Specifies the user to ring.
	public let target: String
	
	// MARK: - Manual construction
	
	public init(target: String) {
		self.target = target
	}
	
	// MARK: - CSCommand
	
	public init?(description: String) {
		guard let (words, sentences) = try? wordsAndSentences(for: description, wordCount: 1, sentenceCount: 1) else {
			return nil
		}
		
		target = words[0]
	}
	
	public var description: String {
		return "RING \(target)"
	}
	
	public func execute(on server: LobbyServer) {
		// Server TODO
	}
}

/**
 Send a chat message to a specific channel. The client has to join the channel before it may use
 this command.
 */
public struct CSSayCommand: CSCommand {

    public let channelName: String
    public let message: String

    // MARK: - Manual construction

    public init(channelName: String, message: String) {
        self.channelName = channelName
        self.message = message
    }

    // MARK: - CSCommand

    public init?(description: String) {
        guard let (words, sentences) = try? wordsAndSentences(for: description, wordCount: 1, sentenceCount: 1) else {
            return nil
        }
        channelName = words[0]
        message = sentences[0]
    }

    public var description: String {
        return "SAY \(channelName) \(message)"
    }

    public func execute(on server: LobbyServer) {

    }
}

public extension String {
    func splitLastWord() -> (Substring, Substring)? {
        guard let splitIndex = self.lastIndex(of: " "),
              splitIndex < endIndex,
              splitIndex > startIndex else {
            return nil
        }
        let payload = self[..<splitIndex]
        let code = self[index(after: splitIndex)...]
        return (payload, code)
    }
}

public protocol SaidEncodableCommand {
    static var Identifier: String { get }

    var payloadDescription: String { get }
    var description: String { get }

    func execute(on authenticatedClient: AuthenticatedClient, connection: Connection)

    init?(payload: String)
}

public extension SaidEncodableCommand {
    var description: String {
        return payloadDescription.appending(" [&\(Self.Identifier)&]")
    }
}

public struct RoutedPrivateMessage: SaidEncodableCommand {
    public static let Identifier: String = "RoutedMessage"

    let senderID: Int
    let receiverID: Int
    let message: String

    init(senderID: Int, receiverID: Int, message: String) {
        self.senderID = senderID
        self.receiverID = receiverID
        self.message = message
    }

    public init?(payload: String) {
        guard let (_, sentences) = try? wordsAndSentences(for: payload, wordCount: 0, sentenceCount: 3),
              let senderID = Int(sentences[1]), let receiverID = Int(sentences[2]) else {
            return nil
        }

        self.senderID = senderID
        self.receiverID = receiverID
        self.message = sentences[0]
    }

    public var payloadDescription: String {
        return "\(message)\t\(senderID)\t\(receiverID)"
    }
    
    public func execute(on authenticatedClient: AuthenticatedClient, connection: Connection) {
        guard let senderName = authenticatedClient.userList.items[senderID]?.profile.fullUsername,
              let receiverName = authenticatedClient.userList.items[receiverID]?.profile.fullUsername else {
            return
        }
        let channelName = "\(senderName) via \(receiverName)"
        let channelID = authenticatedClient.id(forChannelnamed: channelName)
        
        let channel: Channel
        if let createdChannel = authenticatedClient.channelList.items[channelID] {
            channel = createdChannel
        } else {
            channel = Channel(title: channelName, rootList: authenticatedClient.userList, sendAction: { [weak authenticatedClient] channel, message in
            })
            channel.userlist.addItemFromParent(id: senderID)
            channel.userlist.addItemFromParent(id: receiverID)
            channel.userlist.addItemFromParent(id: senderID)
        }
        
        print("Received message from \(channelName): \(message)")
        
        channel.receivedNewMessage(
            ChatMessage(
                time: Date(),
                senderID: senderID,
                senderName: senderName,
                content: message,
                isIRCStyle: false
            )
        )
    }
}

let saidPrivateEncodableCommands: [String : SaidEncodableCommand.Type] = [
    RoutedPrivateMessage.Identifier : RoutedPrivateMessage.self,
]
let saidEncodableCommands: [String : SaidEncodableCommand.Type] = [:]

/**
 Sent to all clients participating in a specific channel when one of the clients sent a chat message
 to it (including the author of the message).
 */
public struct SCSaidCommand: SCCommand {

    let channelName: String
    let username: String
    let message: String

    // MARK: - Manual construction

    init(channelName: String, username: String, message: String) {
        self.channelName = channelName
        self.username = username
        self.message = message
    }

    // MARK: - SCCommand

    public init?(description: String) {
        guard let (words, sentences) = try? wordsAndSentences(for: description, wordCount: 2, sentenceCount: 1) else {
            return nil
        }
        channelName = words[0]
        username = words[1]
        message = sentences[0]
    }

    public var description: String {
        return "SAID \(channelName) \(username) \(message)"
    }
    
    public func execute(on client: Client) {
        client.inAuthenticatedState { authenticatedClient, connection in
            let channelID = authenticatedClient.id(forChannelnamed: channelName)
            guard let channel = authenticatedClient.channelList.items[channelID],
                  let senderID = authenticatedClient.id(forPlayerNamed: username),
                  let sender = authenticatedClient.userList.items[senderID] else {
                return
            }
            
            if handleSaidEncodedCommand(authenticatedClient: authenticatedClient, connection: connection, sender: sender, message: message, availableCommands: saidEncodableCommands) { return }
            
            channel.receivedNewMessage(ChatMessage(
                time: Date(),
                senderID: senderID,
                senderName: username,
                content: message,
                isIRCStyle: false
            ))
        }
    }
}

func handleSaidEncodedCommand(authenticatedClient: AuthenticatedClient, connection: Connection, sender: User, message: String, availableCommands: [String : SaidEncodableCommand.Type]) -> Bool {
    if sender.profile.lobbyID.hasPrefix("BelieveAndRise"),
       let (payload, messageCode) = message.splitLastWord(),
       messageCode.hasPrefix("[&") && messageCode.hasSuffix("&]") {
        let commandID = String(messageCode.dropFirst(2).dropLast(2))
        if let commandType = availableCommands[commandID],
           let command = commandType.init(payload: String(payload)) {
            command.execute(on: authenticatedClient, connection: connection)
            return true
        }
    }
    return false
}

/**
 Sent by any client requesting to say something in a channel in "/me" IRC style. (The SAY command is
 used for normal chat messages.)
 */
public struct CSSayExCommand: CSCommand {

    let channelName: String
    let message: String

    // MARK: - Manual construction

    init(channelName: String, message: String) {
        self.channelName = channelName
        self.message = message
    }

    // MARK: - CSCommand

    public init?(description: String) {
        guard let (words, sentences) = try? wordsAndSentences(for: description, wordCount: 1, sentenceCount: 1) else {
            return nil
        }
        channelName = words[0]
        message = sentences[0]
    }

    public var description: String {
        return "SAYEX \(channelName) \(message)"
    }

    public func execute(on server: LobbyServer) {

    }
}

/**
 Sent by the server when a client said something using the SAYEX command.
 */
public struct SCSaidExCommand: SCCommand {

    let channelName: String
    let username: String
    let message: String

    // MARK: - Manual construction

    init(channelName: String, username: String, message: String) {
        self.channelName = channelName
        self.username = username
        self.message = message
    }

    // MARK: - SCCommand

    public init?(description: String) {
        guard let (words, sentences) = try? wordsAndSentences(for: description, wordCount: 2, sentenceCount: 1) else {
            return nil
        }
        channelName = words[0]
        username = words[1]
        message = sentences[0]
    }

    public var description: String {
        return "SAIDEX \(channelName) \(username) \(message)"
    }
    
    public func execute(on client: Client) {
        client.inAuthenticatedState { authenticatedClient, _ in
            let channelID = authenticatedClient.id(forChannelnamed: channelName)
            guard let channel = authenticatedClient.channelList.items[channelID],
                  let senderID = authenticatedClient.id(forPlayerNamed: username) else {
                return
            }
            channel.receivedNewMessage(ChatMessage(
                time: Date(),
                senderID: senderID,
                senderName: username,
                content: message,
                isIRCStyle: true
            ))
        }
    }
}

public struct SCChannelCommand: SCCommand {
	
	let channelName: String
	let userCount: Int
	let topic: String?
	
	// MARK: - Manual Construction
	
	init(channelName: String, userCount: Int, topic: String?) {
		self.channelName = channelName
		self.userCount = userCount
		self.topic = topic
	}
	
	// MARK: - SCCommand
	
    public init?(description: String) {
		guard let (words, sentences) = try? wordsAndSentences(for: description, wordCount: 2, sentenceCount: 0, optionalSentences: 1),
		let userCount = Int(words[1]) else {
			return nil
		}
		channelName = words[0]
		self.userCount = userCount
		topic = sentences.count == 1 ? sentences[0] : nil
	}
	
    public func execute(on client: Client) {
		#warning("todo")
	}
	
    public var description: String {
		var string = "CHANNEL \(channelName) \(userCount)"
		if let topic = topic {
			string += " \(topic)"
		}
		return string
	}
}

public struct SCEndOfChannelsCommand: SCCommand {
	
	// MARK: - Manual Construction
	
	init() {}
	
	// MARK: - SCCommand
	
    public init?(description: String) {}
	
    public func execute(on client: Client) {
		#warning("todo")
	}
	
    public var description: String {
		return "ENDOFCHANNELS"
	}
}
