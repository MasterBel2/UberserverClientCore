//
//  Ping.swift
//  
//
//  Created by MasterBel2 on 3/3/21.
//

import Foundation

/**
 Requests a [PONG](https://springrts.com/dl/LobbyProtocol/ProtocolDescription.html#PONG:server) back from the server.

 Clients should send PING once every 30 seconds, if no other data is being sent to the server. For details, see the notes above on keep-alive signals.
 */
struct CSPingCommand: CSCommand {

    static let title = "PING"

    init?(payload: String) {}
    init() {}

    var payload: String { return "" }

    func execute(on server: LobbyServer) {
        // TODO
    }
}

/**
 Sent as the response to a [PING](https://springrts.com/dl/LobbyProtocol/ProtocolDescription.html#PING:client) command.
 */
struct SCPongCommand: SCCommand {

    static let title = "PONG"
    
    init?(payload: String) {}
    init() {}

    var payload: String { return "" }

    public func execute(on lobby: TASServerLobby) {}
}
