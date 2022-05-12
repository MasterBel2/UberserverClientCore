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

    func stop() {
        _ = channel.close()
    }

    /// Assembles the pieces created in `TCPClient.run`
    private init(channel: NIO.Channel, eventLoopGroup: EventLoopGroup) throws {
        self.eventLoopGroup = eventLoopGroup
        self.channel = channel
    }

    static func run(host: String, port: Int, delegate: TCPClientDelegate) throws -> TCPClient {
        print("Starting client…")

//        let configuration = TLSConfiguration.makeClientConfiguration()
        let handler = Handler()
        handler.delegate = delegate

        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let bootstrap = ClientBootstrap(group: eventLoopGroup)
            .channelInitializer { channel in
                return channel.pipeline.addHandler(handler)
            }

        return try TCPClient(
            channel: bootstrap.connect(host: host, port: port).wait(),
            eventLoopGroup: eventLoopGroup
        )
    }
//    let sslContext = try NIOSSLContext(configuration: configuration)
//    guard let handler = try? NIOSSLClientHandler(context: sslContext, serverHostname: nil) else {
//        fatalError("Failed to construct NIOSSLClientHandler")
//    }

//    private class tlsUpgradeHandler: RemovableChannelHandler, ChannelOutboundHandler {
//        typealias OutboundIn = ByteBuffer
//        typealias OutboundOut = ByteBuffer
//
//        private var messageBuffer: [String] = []
//
//        private var removeSelf: (() -> Void)?
//
//        func removeHandler(context: ChannelHandlerContext, removalToken: ChannelHandlerContext.RemovalToken) {
//            removeSelf = {
//                context.leavePipeline(removalToken: removalToken)
//            }
//        }
//
//        func flushAndRemove(context: ChannelHandlerContext) {
//
//            messageBuffer.forEach({ message in
//                let byteBuffer = ByteBuffer(string: message)
//                context.writeAndFlush(byteBuffer)
//            })
//
//        }
//
//        // Conformance
//
//        func read(context: ChannelHandlerContext) {
//            <#code#>
//        }
//
//        func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
//            <#code#>
//        }
//
//    }

    private class Handler: ChannelInboundHandler {
        typealias InboundIn = ByteBuffer
        typealias OutboundOut = ByteBuffer

        weak var delegate: TCPClientDelegate?

        func errorCaught(context: ChannelHandlerContext, error: Error) {
            delegate?.socketError(error)
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
