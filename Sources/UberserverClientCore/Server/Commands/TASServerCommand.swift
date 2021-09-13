//
//  TASServerCommand.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 15/7/19.
//  Copyright © 2019 MasterBel2. All rights reserved.
//

import Foundation

public struct TASServerCommand: SCCommand {

    public static let title = "TASSERVER"

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

    public init?(payload: String) {
        guard let (words, _) = try? wordsAndSentences(for: payload, wordCount: 4, sentenceCount: 0) else {
            return nil
        }
        protocolVersion = words[0]
        springVersion = words[1]
        udpPort = Int(words[2]) ?? 0
        lanMode = words[3] == "1"
    }

    public var payload: String {
        return "\(protocolVersion) \(springVersion) \(udpPort) \(lanMode ? 1 : 0)"
    }
    
    public func execute(on connection: ThreadUnsafeConnection) {
        let protocolFloat: Float

        if let version = Float(String(protocolVersion.prefix(while: { "0.123456789".contains($0) }))) {
            protocolFloat = version
        } else {
            // Default to latest available version
            protocolFloat = 0.38
        }

        connection.setProtocol(.tasServer(version: protocolFloat))

        if ProtocolFeature.TASServer.crypto0_37.isAvailable(in: protocolFloat) {
            // TODO
        } else if ProtocolFeature.TASServer.crypto0_38.isAvailable(in: protocolFloat) {
            connection.send(CSSTLSCommand(), specificHandler: { response in
                if response is SCOKCommand {
                    try? connection.socket.setStreamProperty(StreamSocketSecurityLevel.tlSv1, forKey: .socketSecurityLevelKey)
                    return true
                }
                return false
            })
        }
    }
}
