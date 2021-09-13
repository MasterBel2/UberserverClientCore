//
//  TASServerCommand.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 4/7/19.
//  Copyright © 2019 MasterBel2. All rights reserved.
//

import Foundation

struct CSLoginCommand: CSCommand {

    static let title = "LOGIN"

    func execute(on server: LobbyServer) {
        #warning("TODO")
    }

    init?(payload: String) {
        #warning("Command decoding not implemented")
        return nil
    }

    init(username: String, password: String, compatabilityFlags: Set<CompatabilityFlag>) {
        self.username = username
        self.password = password
        self.compatabilityFlags = compatabilityFlags
    }

	let username: String
	let password: String
    let compatabilityFlags: Set<CompatabilityFlag>

	var payload: String {
		let encodedPassword = password.md5().base64Encoded() // TODO: Error checking
        return "\(username) \(encodedPassword) 0 * BelieveAndRise Alpha\t0\t" + (compatabilityFlags.map { $0.rawValue }).joined(separator: " ")
	}
}

struct CSRegisterCommand: CSCommand {

    static let title = "REGISTER"

    func execute(on server: LobbyServer) {
        #warning("TODO")
    }

    init?(payload: String) {
        guard let (words, _) = try? wordsAndSentences(for: payload, wordCount: 2, sentenceCount: 0),
              words.count == 2 else {
            return nil
        }
        username = words[0]
        encodedPassword = words[1]
    }

    init(username: String, password: String) {
        self.username = username
        self.encodedPassword = password.md5().base64Encoded()
    }

	let username: String
	let encodedPassword: String

	var payload: String {
		return "\(username) \(encodedPassword)"
	}
}
