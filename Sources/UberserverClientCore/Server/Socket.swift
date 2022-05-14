//
//  Socket.swift
//  OSXSpringLobby
//
//  Created by Belmakor on 30/06/2016.
//  Copyright © 2016 MasterBel2. All rights reserved.
//

import Foundation
import ServerAddress
import NIO

private enum SocketError: Error {
    case failedToSetStreamProperty(property: Any?, key: Stream.PropertyKey)
}

/// A set of functions that may be implemented by a Socket's delegate.
protocol SocketDelegate: AnyObject {
	func socket(_ socket: Socket, didReceive data: Data)
    func socket(_ socket: Socket, didFailWithError error: Error?)
}

typealias Socket = TCPClientSocket
final class TCPClientSocket: TCPClientDelegate {
    weak var delegate: SocketDelegate?

    let address: ServerAddress

    private(set) var client: TCPClient?

    var tlsEnabled: Bool { return client?.tlsEnabled == true }

    init?(address: ServerAddress) {
        self.address = address
    }

    func open() {
        client = try? TCPClient.run(
            host: address.location,
            port: address.port,
            delegate: self
        )
    }

    func close() {
        client?.stop()
        client = nil
    }

    func send(message: Data) {
        guard let channel = client?.channel else {
            return
        }

        channel.writeAndFlush(ByteBuffer(bytes: message), promise: nil)
    }

    // MARK: - TCPClientDelegate

    func socketError(_ error: Error) {
        delegate?.socket(self, didFailWithError: error)
        client = nil
    }

    func received(_ data: Data) {
        delegate?.socket(self, didReceive: data)
    }
}
