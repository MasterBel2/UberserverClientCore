//
//  NIO.swift
//  UberserverClientCore
//
//  Created by MasterBel2 on 25/9/21.
//

import Foundation
import NIO
import NIOSSL
import NIOFoundationCompat

struct UDPMessage {
    let data: Data
    let address: SocketAddress
}

final class TCPClient<DataType> {
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

    static func runUDP(host: String, port: Int, delegate: TCPClientDelegate) throws -> TCPClient<UDPMessage> {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let bootstrap = DatagramBootstrap(group: eventLoopGroup)
            .channelInitializer { channel in

                let handler = UDPHandler()
                handler.delegate = delegate

                return channel.pipeline.addHandler(handler)
            }

        return try TCPClient<UDPMessage>(
            channel: bootstrap.connect(host: host, port: port).wait(),
            eventLoopGroup: eventLoopGroup
        )
    }
    
    static func run(host: String, port: Int, delegate: TCPClientDelegate) throws -> TCPClient<Data> {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let bootstrap = ClientBootstrap(group: eventLoopGroup)
            .channelInitializer { channel in

                let handler = TCPHandler()
                handler.delegate = delegate

                return channel.pipeline.addHandler(handler)
            }

        return try TCPClient<Data>(
            channel: bootstrap.connect(host: host, port: port).wait(),
            eventLoopGroup: eventLoopGroup
        )
    }

    private class TCPHandler: ChannelInboundHandler, ChannelOutboundHandler {
        typealias InboundIn = ByteBuffer
        typealias OutboundOut = ByteBuffer

        typealias OutboundIn = Data

        weak var delegate: TCPClientDelegate?

        func errorCaught(context: ChannelHandlerContext, error: Error) {
            delegate?.socketError(error)
            print(error)
        }

        func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
            let writeBuffer = unwrapOutboundIn(data)
            
            context.write(wrapOutboundOut(ByteBuffer(data: writeBuffer)), promise: promise)
        }

        func channelRead(context: ChannelHandlerContext, data: NIOAny) {
            var readBuffer = unwrapInboundIn(data)

            if let data = readBuffer.readBytes(length: readBuffer.readableBytes) {
                delegate?.received(Data(data))
            }
        }
    }

    private class UDPHandler: ChannelInboundHandler, ChannelOutboundHandler {
        typealias InboundIn = AddressedEnvelope<ByteBuffer>
        typealias OutboundOut = AddressedEnvelope<ByteBuffer>
        typealias OutboundIn = UDPMessage

        weak var delegate: TCPClientDelegate?

        func errorCaught(context: ChannelHandlerContext, error: Error) {
            delegate?.socketError(error)
            print(error)
        }

        func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
            let message = unwrapOutboundIn(data)
            let byteBuffer = ByteBuffer(data: message.data)
            let addressedEnvelope = AddressedEnvelope(remoteAddress: message.address, data: byteBuffer)

            context.write(wrapOutboundOut(addressedEnvelope), promise: promise)
        }

        func channelRead(context: ChannelHandlerContext, data: NIOAny) {
            var readBuffer = unwrapInboundIn(data)

            if let data = readBuffer.data.readBytes(length: readBuffer.data.readableBytes) {
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
