//
//  Private Messages.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 12/11/19.
//  Copyright © 2019 MasterBel2. All rights reserved.
//

import Foundation

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
		#warning("todo")
	}
	
    public var description: String {
		return "SAYPRIVATE \(username) \(message)"
	}
}

public struct SCSaidPrivateCommand: SCCommand {
	
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
		#warning("todo")
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
		#warning("todo")
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
		#warning("todo")
	}
	
    public var description: String {
		return "SAIDPRIVATEEX \(username) \(message)"
	}
}
