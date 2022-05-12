//
//  Ignore Command Set.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 4/7/20.
//  Copyright © 2020 MasterBel2. All rights reserved.
//

import Foundation

///

/**
Tells the client that the user has been ignored (usually as a result of the IGNORE command sent by the client, but other sources are also possible). Also see the IGNORE command. This command uses named arguments, see "Named Arguments" chapter of the Intro section.
*/
public struct SCIgnoreCommand: SCCommand {

    public static let title = "IGNORE"

    let username: String
    let reason: String?

    // MARK: - Manual Construction

    init(username: String, reason: String) {
        self.username = username
        self.reason = reason
    }

    // MARK: - SCCommand

    public init?(payload: String) {
        guard let (words, _, _, optionalSentences) = try? wordsAndSentences(for: payload, wordCount: 1, sentenceCount: 0, optionalSentenceCount: 1) else {
            return nil
        }
        username = words[0]
        reason = optionalSentences.first
    }

    public func execute(on connection: ThreadUnsafeConnection) {
        #warning("todo")
    }

    public var payload: String {
        var string = username
        if let reason = reason {
            string += " \(reason)"
        }
        return string
    }
}

public struct SCUnignoreCommand: SCCommand {

    public static let title = "UNIGNORE"

    let username: String

    // MARK: - Manual Construction

    init(username: String) {
        self.username = username
    }

    // MARK: - SCCommand

    public init?(payload: String) {
        guard let (words, _) = try? wordsAndSentences(for: payload, wordCount: 1, sentenceCount: 0) else {
            return nil
        }
        self.username = words[0]
    }

    public func execute(on connection: ThreadUnsafeConnection) {
        #warning("todo")
    }

    public var payload: String {
        return username
    }
}

public struct SCIgnoreListBegin: SCCommand {

    public static let title = "IGNORELISTBEGIN"

    // MARK: - Manual Construction

    init() {}

    // MARK: - SCCommand

    public init?(payload: String) {}

    public func execute(on connection: ThreadUnsafeConnection) {
        #warning("todo")
    }

    public var payload: String { return "" }
}

public struct SCIgnoreListCommand: SCCommand {

    public static let title = "IGNORELIST"

    let username: String
    let reason: String?

    // MARK: - Manual Construction

    init(username: String, reason: String) {
        self.username = username
        self.reason = reason
    }

    // MARK: - SCCommand

    public init?(payload: String) {
        guard let (words, sentences, _, optionalSentences) = try? wordsAndSentences(for: payload, wordCount: 1, sentenceCount: 0, optionalSentenceCount: 1) else {
            return nil
        }
        username = words[0]
        reason = optionalSentences.first
    }

    public func execute(on connection: ThreadUnsafeConnection) {
        #warning("todo")
    }

    public var payload: String {
        #warning("todo")
        return ""
    }
}

public struct SCCIgnoreListEndCommand: SCCommand {

    public static let title = "IGNORELISTEND"

    // MARK: - Manual Construction

    init() {}

    // MARK: - SCCommand

    public init?(payload: String) {}

    public func execute(on connection: ThreadUnsafeConnection) {
        #warning("todo")
    }

    public var payload: String { return "" }
}
