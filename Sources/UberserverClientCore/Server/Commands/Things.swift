//
//  Things.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 12/11/19.
//  Copyright © 2019 MasterBel2. All rights reserved.
//

import Foundation
import ServerAddress

public struct SCCompFlagsCommand: SCCommand {
	
	let compatabilityFlags: [CompatabilityFlag]
	private let unrecognisedFlags: [String]
	
	// MARK: - Manual Construction
	
	init(compatabilityFlags: [CompatabilityFlag]) {
		self.compatabilityFlags = compatabilityFlags
		unrecognisedFlags = []
	}
	
	// MARK: - SCCommand
	
    public init?(description: String) {
		guard let (words, _) = try? wordsAndSentences(for: description, wordCount: 0, sentenceCount: 0, optionalWords: 1000) else {
			return nil
		}
		compatabilityFlags = words.compactMap({ CompatabilityFlag(rawValue: $0) })
		let compatabilityFlagValues = compatabilityFlags.map({ $0.rawValue })
		let unrecognisedFlags = words.filter({ !compatabilityFlagValues.contains($0) })
		self.unrecognisedFlags = unrecognisedFlags
	}
	
    public func execute(on client: Client) {
		debugOnlyPrint("Unrecognised flags: \(unrecognisedFlags.joined(separator: " "))")
	}
	
    public var description: String {
		return "COMPFLAGS \(compatabilityFlags.map({$0.rawValue}).joined(separator: " "))"
	}
}

public struct SCRedirectCommand: SCCommand {
	
	let ip: String
	let port: Int
	
	// MARK: - Manual Construction
	
	init(ip: String, port: Int) {
		self.ip = ip
		self.port = port
	}
	
	// MARK: - SCCommand
	
    public init?(description: String) {
		guard let (words, _) = try? wordsAndSentences(for: description, wordCount: 2, sentenceCount: 0),
			let port = Int(words[1]) else {
			return nil
		}
		ip = words[0]
		self.port = port
	}
	
    public func execute(on client: Client) {
        client.inConnectedState { connection in
            connection.redirect(to: ServerAddress(location: ip, port: port))
        }
	}
	
    public var description: String {
		return "REDIRECT \(ip) \(port)"
	}
}


public struct SCFailedCommand: SCCommand {
	
	// MARK: - Manual Construction
	
	init() {}
	
	// MARK: - SCCommand
	
    public init?(description: String) {}
	
    public func execute(on client: Client) {
		client.receivedError(.failed)
	}
	
    public var description: String {
		return "FAILED"
	}
}

/**
A command used to send information to clients in JSON format. (Currently rarely used.)
*/
public struct SCJSONCommand: SCCommand {
	
	let json: String
	
	// MARK: - Manual Construction
	
	init(json: String) {
		self.json = json
	}
	
	// MARK: - SCCommand
	
    public init?(description: String) {
		json = description
	}
	
    public func execute(on client: Client) {
//		jsonCommandHandler.execute(json, on: connection)
	}
	
    public var description: String {
		return "JSON " + json
	}
}


/**
Sent as the response to a PING command.
*/
public struct SCPongCommand: SCCommand {
	
	let time = Date()
	
	// MARK: - Manual Construction
	
	init() {}
	
	// MARK: - SCCommand
	
    public init?(description: String) {}
	
    public func execute(on client: Client) {
		#warning("todo")
	}
	
    public var description: String {
		return "PONG"
	}
}

/**
Sent as the response to a STLS command. The client now can now start the tls connection. The server will send again the greeting TASSERVER.
*/
public struct SCOKCommand: SCCommand {
	
	// MARK: - Manual Construction
	
	init() {}
	
	// MARK: - SCCommand
	
    public init?(description: String) {}
	
    public func execute(on client: Client) {
		#warning("TODO")
	}
	
    public var description: String {
		return "OK"
	}
}
