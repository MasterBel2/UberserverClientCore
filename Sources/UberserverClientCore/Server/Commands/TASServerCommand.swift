//
//  TASServerCommand.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 15/7/19.
//  Copyright © 2019 MasterBel2. All rights reserved.
//

import Foundation

public struct TASServerCommand: SCCommand {
    /// The lobby protocol version used by the server. Should log in only if this version is
    /// supported.
    let protocolVersion: String
    /// Default spring version used on the lobby server. If the value is "*", it should be ignored.
    let springVersion: String
    /// This is server UDP port where the "NAT Help Server" is running. This is the port to which
    /// clients should send their UDP packets when trying to figure out their public UDP source
    /// port. This is used with some NAT traversal techniques (e.g. "hole punching").
    let udpPort: Int
    /// Whether the host is running in lan mode. Lan mode corresponds to a "1" value for serverMode.
    let lanMode: Bool

    // MARK: - SCCommand

    public init?(description: String) {
        guard let (words, _) = try? wordsAndSentences(for: description, wordCount: 4, sentenceCount: 0) else {
            return nil
        }
        protocolVersion = words[0]
        springVersion = words[1]
        udpPort = Int(words[2]) ?? 0
        lanMode = words[3] == "1"
    }

    public var description: String {
        return "TASSERVER \(protocolVersion) \(springVersion) \(udpPort) \(lanMode ? 1 : 0)"
    }
    
    public func execute(on connection: ThreadUnsafeConnection) {
        if protocolVersion == "unknown" {
            connection.setProtocol(.tasServer(version: 0.38))
        } else if let version = Float(String(protocolVersion.prefix(while: { "0.123456789".contains($0) }))) {
            connection.setProtocol(.tasServer(version: version))
        }
    }
}
