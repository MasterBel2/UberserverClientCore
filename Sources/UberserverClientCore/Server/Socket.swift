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

public typealias Socket = TCPClientSocket
public final class TCPClientSocket: TCPClientDelegate {
    weak var delegate: SocketDelegate?

    public let address: ServerAddress

    private(set) var client: TCPClient<Data>?

    public var tlsEnabled: Bool { return client?.tlsEnabled == true }


    private(set) var bufferedMessages: [Data] = []

    public var shouldBuffer = false {
        didSet {
            if !shouldBuffer { flush() }
        }
    }

    init?(address: ServerAddress) {
        self.address = address
    }

    func open() {
        client = try? TCPClient<Data>.run(
            host: address.location,
            port: address.port,
            delegate: self
        )
    }

    func flush() {
        bufferedMessages.forEach({ send(message: $0, force: true) })
    }

    func close() {
        client?.stop()
        client = nil
    }

    // parameter force: if true, message buffering is bypassed
    func send(message: Data, force: Bool = false) {
        if shouldBuffer && !force {
            bufferedMessages.append(message)
        } else {
            client?.channel.writeAndFlush(message, promise: nil)
        }
    }

    // MARK: - TCPClientDelegate

    func socketError(_ error: Error) {
        delegate?.socket(self, didFailWithError: error)
        // Crashing here: apparently when stop() is called, that loops back to here and so you have a client = nil inside a client.stop() - creating a double access. 
        // Weird? Yes. Know how to fix it? ... Async? 
        // client = nil
    }

    func received(_ data: Data) {
        delegate?.socket(self, didReceive: data)
    }
}