//
//  NIO.swift
//  UberserverClientCore
//
//  Created by MasterBel2 on 25/9/21.
//

import Foundation
import NIO
import NIOSSL

final class TCPClient {
    let channel: NIO.Channel
    private let eventLoopGroup: EventLoopGroup

    private(set) var tlsEnabled: Bool = false

    func enableTLS() throws {
        guard !tlsEnabled else { return }

        var configuration = TLSConfiguration.makeClientConfiguration()
        configuration.certificateVerification = .none
        let sslContext = try! NIOSSLContext(configuration: configuration)
        let handler = try NIOSSLClientHandler(context: sslContext, serverHostname: nil)

        try channel.pipeline.addHandler(handler, position: .first).wait()

        tlsEnabled = true
    }

    func stop() {
        _ = channel.close()
    }

    /// Assembles the pieces created in `TCPClient.run`
    private init(channel: NIO.Channel, eventLoopGroup: EventLoopGroup) throws {
        self.eventLoopGroup = eventLoopGroup
        self.channel = channel
    }


    static func run(host: String, port: Int, delegate: TCPClientDelegate) throws -> TCPClient {

        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let bootstrap = ClientBootstrap(group: eventLoopGroup)
            .channelInitializer { channel in

                let handler = Handler()
                handler.delegate = delegate

                return channel.pipeline.addHandler(handler)
            }

        return try TCPClient(
            channel: bootstrap.connect(host: host, port: port).wait(),
            eventLoopGroup: eventLoopGroup
        )
    }

    private class Handler: ChannelInboundHandler {
        typealias InboundIn = ByteBuffer
        typealias OutboundOut = ByteBuffer

        weak var delegate: TCPClientDelegate?

        func errorCaught(context: ChannelHandlerContext, error: Error) {
            delegate?.socketError(error)
            print(error)
        }

        func channelRead(context: ChannelHandlerContext, data: NIOAny) {
            var readBuffer = unwrapInboundIn(data)

            if let data = readBuffer.readBytes(length: readBuffer.readableBytes) {
                delegate?.received(Data(data))
            }
        }
    }

    deinit {
        stop()
        eventLoopGroup.shutdownGracefully({ _ in })
    }
}

protocol TCPClientDelegate: AnyObject {
    func socketError(_ error: Error)
    func received(_ data: Data)
}
