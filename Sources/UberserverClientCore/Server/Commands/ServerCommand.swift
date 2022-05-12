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
        guard let (words, _, optionalWords, _) = try? wordsAndSentences(for: payload, wordCount: 2, sentenceCount: 0, optionalWordCount: 1),
              words.count >= 2 else {
            return nil
        }
        username = words[0]
        encodedPassword = words[1]
        emailAddress = try? EmailAddress.decode(from: words[2])
    }

    init(username: String, password: String, emailAddress: EmailAddress?) {
        self.username = username
        self.encodedPassword = password.md5().base64Encoded()
        self.emailAddress = emailAddress
    }

	let username: String
    let emailAddress: EmailAddress?
	let encodedPassword: String

	var payload: String {
        return "\(username) \(encodedPassword) \(emailAddress?.description ?? "")"
	}
}

/// Describes an email address. Used
public struct EmailAddress: CustomStringConvertible {
    public let name: String
    public let host: String

    public struct DecodeError: Error {
        let address: String
    }

    public init(name: String, host: String) {
        self.name = name
        self.host = host
    }

    /// Fails if the email address does not match the required format.
    public static func decode(from string: String) throws -> EmailAddress {
        let components = string.components(separatedBy: "@")
        guard components.count == 2 else {
            throw DecodeError(address: string)
        }
        return EmailAddress(name: components[0], host: components[1])
    }

    public var description: String {
        return "\(name)@\(host)"
    }
}
