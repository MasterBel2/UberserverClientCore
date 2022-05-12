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
	func socket(_ socket: Socket, didReceive message: String)
    func socket(_ socket: Socket, didFailWithError error: Error?)
}

typealias Socket = TCPClientSocket
final class TCPClientSocket: TCPClientDelegate {
    weak var delegate: SocketDelegate?

    let address: ServerAddress

    private var client: TCPClient?

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

    func send(message: String) {
        guard let channel = client?.channel else {
            return
        }

        channel.writeAndFlush(ByteBuffer(bytes: message.utf8), promise: nil)
    }

    // MARK: - TCPClientDelegate

    func socketError(_ error: Error) {
        delegate?.socket(self, didFailWithError: error)
        client = nil
    }

    func received(_ data: Data) {
        if let string = String(bytes: data, encoding: .utf8) {
            delegate?.socket(self, didReceive: string)
        }
    }
}
