//
//  GeneralServerCommands.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 13/7/19.
//  Copyright © 2019 MasterBel2. All rights reserved.
//

import Foundation

/// See https://springrts.com/dl/LobbyProtocol/ProtocolDescription.html#MOTD:server
public struct MOTDCommand: SCCommand {
    public static let title = "MOTD"

    public let payload: String

    public init(payload: String) {
        self.payload = payload
    }

    public init?(_payload: String) {
        payload = _payload
    }

    public func execute(on lobby: TASServerLobby) {
        print(payload)
    }
}

/**
A general purpose message sent by the server. The lobby client program should display this message to the user in a non-invasive way, but clearly visible to the user (for example, as a SAYEX-style message from the server, printed into all the users chat panels).

# Example
`SERVERMSG Server is going down in 5 minutes for a restart, due to a new update.`
*/
public struct SCServerMessageCommand: SCCommand {

    public static let title = "SERVERMSG"
	
	/// The server's message.
	let message: String
	
	// MARK: - Manual Construction
	
	init(message: String) {
		self.message = message
	}
	
	// MARK: - SCCommand
	
    public init?(payload: String) {
		guard let (_, sentences) = try? wordsAndSentences(for: payload, wordCount: 0, sentenceCount: 1) else {
			return nil
		}
		message = sentences[0]
	}
	
    public func execute(on lobby: TASServerLobby) {
//        client.didReceiveMessageFromServer(message)
        print(message)
        #warning("TODO")
	}
	
    public var payload: String {
		return message
	}
}

public struct SCServerMessageBoxCommand: SCCommand {

    public static let title = "SERVERMSGBOX"
	
	let message: String
	let url: URL?
	
	// MARK: - Manual Construction
	
	init(message: String, url: URL) {
		self.message = message
		self.url = url
	}
	
	// MARK: - SCCommand
	
    public init?(payload: String) {
		guard let (_, sentences, _, optionalSentences) = try? wordsAndSentences(for: payload, wordCount: 0, sentenceCount: 1, optionalSentenceCount: 1) else {
			return nil
		}
		message = sentences[0]
		url = sentences.count == 2 ? URL(string: sentences[1]) : nil
	}
	
    public func execute(on lobby: TASServerLobby) {
		#warning("TODO")
	}
	
    public var payload: String {
		var string = message
		if let url = url {
			string += " \(url)"
		}
		return string
	}
}

