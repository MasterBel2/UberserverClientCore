//
//  TASServerCommand.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 15/7/19.
//  Copyright © 2019 MasterBel2. All rights reserved.
//

import Foundation
import NIOSSL

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
    
    public func execute(on lobby: TASServerLobby) {
        // Clean up buffering created by configuration switches (e.g. TLS)
        lobby.connection.socket.shouldBuffer = false
        lobby.connection.socket.flush()
        
        lobby.setVersion(protocolVersion)

        guard !lobby.connection.socket.tlsEnabled,
              case let .tasServer(version: protocolFloat) = lobby.featureAvailability?.serverProtocol else {
            return
        }

        if ProtocolFeature.TASServer.crypto0_37.isAvailable(in: protocolFloat) {
            // TODO
        } else if ProtocolFeature.TASServer.crypto0_38.isAvailable(in: protocolFloat) {
            lobby.send(CSSTLSCommand(), specificHandler: { response in
                if response is SCOKCommand {
                    do {
                        try lobby.connection.socket.client?.enableTLS()
                    } catch {
                        print(error)
                    }
                    return true
                }
                return false
            })
        }
        // Will reset when server tells us we've successfully reconnected to the server.
        lobby.connection.socket.shouldBuffer = true
    }
}
