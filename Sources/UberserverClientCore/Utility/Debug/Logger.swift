//
//  Logger.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 20/4/20.
//  Copyright © 2020 MasterBel2. All rights reserved.
//

import Foundation

/// Provides an interface for debug-only logging.
final class Logger {

    struct Message {
        let timestamp = Date()
        let message: String
        let tag: Tag

        var description: String {
            return "\(timestamp) [\(tag.rawValue)] \(message)"
        }

        enum Tag: String {
            case General
            case GeneralError

            case BattleStatusUpdate
            case StatusUpdate

            case RawProtocolMessage

            case MOTD
            case ServerMessage
            case ServerError
            
            case ClientStateError
        }
    }

    private init() {}

    private static let `logger` = Logger()
    #if DEBUG
    private static let path = NSHomeDirectoryURL().appendingPathComponent(".config")
        .appendingPathComponent("spring")
        .appendingPathComponent("debug.believeandrise.log").path
    #else
    private static let path = NSHomeDirectoryURL().appendingPathComponent(".config")
        .appendingPathComponent("spring")
        .appendingPathComponent("believeandrise.log").path
    #endif

    private(set) var messages: [Logger.Message] = []
    private var previousWrite: String = "Start of log file"

    /// Adds a message to the application's log.
    static func log(_ message: String, tag: Message.Tag) {
        let newMessage = Message(message: message, tag: tag)
        logger.messages.append(newMessage)

        let newEntry = newMessage.description
        // print(newEntry)
        let newWrite = logger.previousWrite + "\n" + newEntry
        write(newWrite)
        logger.previousWrite = newWrite
    }

    private static func write(_ log: String) {
        try? log.write(toFile: path, atomically: true, encoding: .utf8)
    }
}
