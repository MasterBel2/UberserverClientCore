//
//  Connection.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 25/6/19.
//  Copyright © 2019 MasterBel2. All rights reserved.
//

import Foundation
import ServerAddress

public protocol ReceivesConnectionUpdates: AnyObject {
    func connection(_ connection: ThreadUnsafeConnection, didIdentify lobby: Lobby)

    func asAnyReceivesConnectionUpdates() -> AnyReceivesConnectionUpdates
}

public extension ReceivesConnectionUpdates {
    func asAnyReceivesConnectionUpdates() -> AnyReceivesConnectionUpdates {
        return AnyReceivesConnectionUpdates(wrapping: self)
    }
}

public final class AnyReceivesConnectionUpdates: ReceivesConnectionUpdates, Box {
    let wrapped: ReceivesConnectionUpdates
    
    public var wrappedAny: AnyObject {
        return wrapped
    }
    
    init(wrapping: ReceivesConnectionUpdates) {
        self.wrapped = wrapping
    }

    public func connection(_ connection: ThreadUnsafeConnection, didIdentify lobby: Lobby) {
        wrapped.connection(connection, didIdentify: lobby)
    }
}

public typealias ThreadUnsafeConnection = Connection._Connection

/// Handles the socket connection to a lobbyserver.
///
/// Lobbyserver protocol is described at http://springrts.com/dl/LobbyProtocol
/// See here for an implementation in C++ https://github.com/cleanrock/flobby/tree/master/src/model
public final class Connection: SocketDelegate {

    /**
     Contains the state for `Connection`, such that it can be forced to operate on a single thread.

     If you need to store a reference to `_Connection`, make sure it is `ThreadLocked`.
     */
    public class _Connection: UpdateNotifier {

        init(queue: DispatchQueue, socket: Socket, defaultLobby: Lobby, client: Client, resourceManager: ResourceManager, cacheDirectory: URL, preferencesController: PreferencesController) {
            self.queue = queue
            self.socket = socket
            self.client = client
            self.resourceManager = resourceManager
            self.cacheDirectory = cacheDirectory

            self.preferencesController = preferencesController

            self.lobby = defaultLobby
        }

        deinit {
            socket.close()
        }

        // MARK: - Cache

        /// The directory where all cache information associated with the connected server should be written.
        public let cacheDirectory: URL

        // MARK: - Update Notifier

        public var objectsWithLinkedActions: [AnyReceivesConnectionUpdates] = []

        // MARK: - Dependencies

        /// The client that owns this connection.
        private unowned var client: Client
        /// The resource manager providing resource information to this connection.
        let resourceManager: ResourceManager
        let preferencesController: PreferencesController

        // MARK: - Thread-safety

        /// _Connection is queue-locked on the queue. Use this only for async calls.
        public let queue: DispatchQueue

        // MARK: - Socket connection

        /// The socket that connects to the remote server.
        public let socket: Socket

        /// A message was received over the socket.
        func socket(_ socket: Socket, didReceive message: Data) {
            lobby.connection(self, didReceive: message)
        }

        func socket(_ socket: Socket, didFailWithError error: Error?) {
            client.disconnect()
        }

        func redirect(to newAddress: ServerAddress) {
            client.redirect(to: newAddress, tls: socket.tlsEnabled, defaultLobby: lobby)
        }

        /// States the possible sessions that may be maintained with the server.
//        public enum LobbyType {
//            case unknown(UnknownLobby)
//            case tasServerLobby(TASServerLobby)
//            case tachyonLobby(TachyonLobby)
//
//            var value: Lobby {
//                switch self {
//                case let .unknown(lobby):
//                    return lobby
//                case let .tasServerLobby(lobby):
//                    return lobby
//                case let .tachyonLobby(lobby):
//                    return lobby
//                }
//            }
//        }

        public internal(set) var lobby: Lobby {
            didSet {
                applyActionToChainedObjects({ $0.connection(self, didIdentify: lobby) })
            }
        }

//        public internal(set) var lobbyType: LobbyType! {}
    }

    public let _connection: QueueLocked<_Connection>

    // MARK: - Connection Properties

    /// The address the client is connected to.
    public var address: ServerAddress {
        return _connection.sync(block: { return $0.socket.address })
    }

    /// A directory in which the client associated with this connection may store information relating to the server it is connected to.
    public let cacheDirectory: URL

    // MARK: - Lifecycle

    /// Initialiser for the TASServer object.
    ///
    /// - parameter address: The IP address or domain name of the server, along with the port it should connect on.
    /// - parameter defaultProtocol: The protocol the connection will assume the server will communicate with. Use `.unknown` for the client to detect the protocol.
    init?(address: ServerAddress, client: Client, resourceManager: ResourceManager, preferencesController: PreferencesController, baseCacheDirectory: URL, defaultLobby: Lobby) {
        guard let socket = Socket(address: address) else {
            return nil
        }

        let queue = DispatchQueue(label: "com.believeandrise.connection", qos: .userInteractive, target: DispatchQueue.global(qos: .userInteractive))

        let _connection = _Connection(
            queue: queue,
            socket: socket,
            defaultLobby: defaultLobby,
            client: client,
            resourceManager: resourceManager,
            cacheDirectory: baseCacheDirectory.appendingPathComponent(address.description),
            preferencesController: preferencesController
        )

        self._connection = QueueLocked(
            lockedObject: _connection,
            queue: queue
        )

        self.cacheDirectory = baseCacheDirectory.appendingPathComponent(address.description)

        socket.delegate = self
    }

    // MARK: - Socket Events

    /// A message was received over the socket.
    func socket(_ socket: Socket, didReceive message: Data) {
        _connection.async(block: { $0.socket(socket, didReceive: message)})
    }

    /// The socket will no longer receive information from the server.
    func socket(_ socket: Socket, didFailWithError error: Error?) {
        _connection.async(block: { $0.socket(socket, didFailWithError: error) })
    }
}
