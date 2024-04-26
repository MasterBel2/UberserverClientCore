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

    public static let title = "COMPFLAGS"
	
	let compatabilityFlags: [CompatabilityFlag]
	private let unrecognisedFlags: [String]
	
	// MARK: - Manual Construction
	
	init(compatabilityFlags: [CompatabilityFlag]) {
		self.compatabilityFlags = compatabilityFlags
		unrecognisedFlags = []
	}
	
	// MARK: - SCCommand
	
    public init?(payload: String) {
        guard let (_, _, _, optionalWords) = try? wordsAndSentences(for: payload, wordCount: 0, sentenceCount: 0, optionalWordCount: Int.max) else {
			return nil
		}
		compatabilityFlags = optionalWords.compactMap({ CompatabilityFlag(rawValue: $0) })
		let compatabilityFlagValues = compatabilityFlags.map({ $0.rawValue })
		let unrecognisedFlags = optionalWords.filter({ !compatabilityFlagValues.contains($0) })
		self.unrecognisedFlags = unrecognisedFlags
	}
	
    public func execute(on lobby: TASServerLobby) {
		Logger.log("Unrecognised flags: \(unrecognisedFlags.joined(separator: " "))", tag: .General)
	}
	
    public var payload: String {
		return compatabilityFlags.map({$0.rawValue}).joined(separator: " ")
	}
}

public struct SCRedirectCommand: SCCommand {

    public static let title = "REDIRECT"
	
	let ip: String
	let port: Int
	
	// MARK: - Manual Construction
	
	init(ip: String, port: Int) {
		self.ip = ip
		self.port = port
	}
	
	// MARK: - SCCommand
	
    public init?(payload: String) {
		guard let (words, _) = try? wordsAndSentences(for: payload, wordCount: 2, sentenceCount: 0),
			let port = Int(words[1]) else {
			return nil
		}
		ip = words[0]
		self.port = port
	}
	
    public func execute(on lobby: TASServerLobby) {
        lobby.connection.redirect(to: ServerAddress(location: ip, port: port))
	}
	
    public var payload: String {
        return "\(ip) \(port)"
	}
}


public struct SCFailedCommand: SCCommand {

    public static let title = "FAILED"
	
	// MARK: - Manual Construction
	
	init() {}
	
	// MARK: - SCCommand
	
    public init?(payload: String) {}
	
    public func execute(on lobby: TASServerLobby) {}
	
    public var payload: String { return "" }
}

/**
A command used to send information to clients in JSON format. (Currently rarely used.)
*/
public struct SCJSONCommand: SCCommand {

    public static let title = "JSON"
	
	let json: String
	
	// MARK: - Manual Construction
	
	init(json: String) {
		self.json = json
	}
	
	// MARK: - SCCommand
	
    public init?(payload: String) {
		json = payload
	}
	
    public func execute(on lobby: TASServerLobby) {
//		jsonCommandHandler.execute(json, on: connection)
        #warning("todo")
	}
	
    public var payload: String {
		return json
	}
}

/**
 Requests permission to start a TLS connection to the server.
 */
public struct CSSTLSCommand: CSCommand {

    public static let title = "STLS"

    public init() {}

    public init?(payload: String) {}

    public var payload: String { return "" }

    public func execute(on server: LobbyServer) {
        // TODO
    }
}


/**
Sent as the response to a STLS command. The client now can now start the tls connection. The server will send again the greeting TASSERVER.
*/
public struct SCOKCommand: SCCommand {

    public static let title = "OK"
	
	// MARK: - Manual Construction
	
	init() {}
	
	// MARK: - SCCommand
	
    public init?(payload: String) {}
	
    public func execute(on lobby: TASServerLobby) {
        // Handled by specific handler
    }
	
    public var payload: String { return "" }
}
