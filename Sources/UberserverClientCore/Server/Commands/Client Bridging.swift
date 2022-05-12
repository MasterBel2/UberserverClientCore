//
//  Client Bridging.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 12/11/19.
//  Copyright © 2019 MasterBel2. All rights reserved.
//

import Foundation

struct SCBridgeClientFromCommand: SCCommand {

    static let title = "BRIDGECLIENTFROM"
	
	let location: String
	let externalID: Int
	let externalUsername: String
	
	// MARK: - Manual Construction
	
	init(location: String, externalID: Int, externalUsername: String) {
		self.location = location
		self.externalID = externalID
		self.externalUsername = externalUsername
	}
	
	// MARK: - SCCommand
	
	init?(payload: String) {
		guard let (words, _) = try? wordsAndSentences(for: payload, wordCount: 3, sentenceCount: 0),
			let externalID = Int(words[2]) else {
			fatalError()
			return nil
		}
		location = words[0]
		self.externalID = externalID
		externalUsername = words[2]
	}
	
    func execute(on connection: ThreadUnsafeConnection) {
		#warning("TODO")
	}
	
	var payload: String {
		return "\(location) \(externalID) \(externalUsername)"
	}
}

struct SCUnbridgeClientFromCommand: SCCommand {

    static let title = "UNBRIDGECLIENTFROM"
	
	let location: String
	let externalID: Int
	let externalUsername: String
	
	// MARK: - Manual Construction
	
	init(location: String, externalID: Int, externalUsername: String) {
		self.location = location
		self.externalID = externalID
		self.externalUsername = externalUsername
	}
	
	// MARK: - SCCommand
	
	init?(payload: String) {
		guard let (words, _) = try? wordsAndSentences(for: payload, wordCount: 3, sentenceCount: 0),
			let externalID = Int(words[2]) else {
			fatalError()
			return nil
		}
		location = words[0]
		self.externalID = externalID
		externalUsername = words[2]
	}
	
	func execute(on connection: ThreadUnsafeConnection) {
		#warning("TODO")
	}
	
	var payload: String {
		return "\(location) \(externalID) \(externalUsername)"
	}
}

struct SCJoinedFromCommand: SCCommand {

    static let title = "JOINEDFROM"
	
	let channelName: String
	let bridge: String
	let username: String

	// MARK: - Manual Construction
	
	init(channelName: String, bridge: String, username: String) {
		self.channelName = channelName
		self.bridge = bridge
		self.username = username
	}
	
	// MARK: - SCCommand
	
	init?(payload: String) {
		guard let (words, _) = try? wordsAndSentences(for: payload, wordCount: 3, sentenceCount: 0) else {
			return nil
		}
		channelName = words[0]
		bridge = words[1]
		username = words[2]
	}
	
	func execute(on connection: ThreadUnsafeConnection) {
		#warning("TODO")
	}
	
	var payload: String {
		return "\(channelName) \(bridge) \(username)"
	}
}

struct SCLeftFromCommand: SCCommand {

    static let title = "LEFTFROM"
	
	let channelName: String
	let username: String
	
	// MARK: - Manual Construction
	
	init(channelName: String, username: String) {
		self.channelName = channelName
		self.username = username
	}
	
	// MARK: - SCCommand
	
	init?(payload: String) {
		guard let (words, _) = try? wordsAndSentences(for: payload, wordCount: 2, sentenceCount: 0) else {
			return nil
		}
		channelName = words[0]
		username = words[1]
	}
	
	func execute(on connection: ThreadUnsafeConnection) {
		#warning("todo")
	}
	
	var payload: String {
		return "\(channelName) \(username)"
	}
}

struct SCSaidFromCommand: SCCommand {

    static let title = "SAIDFROM"
	
	let channelName: String
	let username: String
	let message: String?
	
	// MARK: - Manual Construction
	
	init(channelName: String, username: String, message: String?) {
		self.channelName = channelName
		self.username = username
		self.message = message
	}
	
	// MARK: - SCCommand
	
	init?(payload: String) {
		guard let (words, _, _, optionalSentences) = try? wordsAndSentences(for: payload, wordCount: 2, sentenceCount: 0, optionalSentenceCount: 1) else {
			return nil
		}
		
		channelName = words[0]
		username = words[1]
        message = optionalSentences.first
	}
	
    func execute(on connection: ThreadUnsafeConnection) {
		#warning("todo")
	}
	
	var payload: String {
		var string = "\(channelName) \(username)"
		if let message = message {
			string += " \(message)"
		}
		return string
	}
}

struct SCClientsFromCommand: SCCommand {

    static let title = "CLIENTSFROM"

    let channelName: String
	let bridge: String
    let clients: [String]

    // MARK: - Manual construction

	init(channelName: String, bridge: String, clients: [String]) {
        self.channelName = channelName
		self.bridge = bridge
        self.clients = clients
    }

    // MARK: - SCCommand

    init?(payload: String) {
        guard let (words, sentences) = try? wordsAndSentences(for: payload, wordCount: 2, sentenceCount: 1) else {
            return nil
        }
        channelName = words[0]
		bridge = words[1]
        clients = sentences[0].components(separatedBy: " ")
    }

    var payload: String {
        return "\(channelName) \(bridge) \(clients.joined(separator: " "))"
    }

    func execute(on connection: ThreadUnsafeConnection) {
		#warning("todo")
    }
}

