//
//  Client.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 8/9/19.
//  Copyright © 2019 MasterBel2. All rights reserved.
//

import Foundation
import ServerAddress

public protocol ReceivesClientUpdates: AnyObject {
    /// Indicates that the client will attempt to establish a connection to the given address.
    func client(_ client: Client, willConnectTo address: ServerAddress)
    /// Indicates that the client has created a `Connection` object that it will use to connect to a server.
    func client(_ client: Client, successfullyEstablishedConnection connection: Connection)
    ///
    func client(_ client: Client, willRedirectFrom oldServerAddress: ServerAddress, to newServerAddress: ServerAddress)
    ///
    func client(_ client: Client, didSuccessfullyRedirectTo newConnection: Connection)
    /// Indicates that the client is about to destroy its connection object, usually directly after the connection disconnects from a server.
    func clientDisconnectedFromServer(_ client: Client)

    /// Returns a type-erasing wrapper of self.
    func asAnyReceivesClientUpdates() -> AnyReceivesClientUpdates
}

public extension ReceivesClientUpdates {
    func asAnyReceivesClientUpdates() -> AnyReceivesClientUpdates {
        return AnyReceivesClientUpdates(wrapping: self)
    }
}

public final class AnyReceivesClientUpdates: ReceivesClientUpdates, Box {
    public let wrapped: ReceivesClientUpdates

    public var wrappedAny: AnyObject {
        return wrapped
    }

    public init(wrapping: ReceivesClientUpdates) {
        self.wrapped = wrapping
    }

    public func client(_ client: Client, willConnectTo address: ServerAddress) {
        wrapped.client(client, willConnectTo: address)
    }

    public func client(_ client: Client, successfullyEstablishedConnection connection: Connection) {
        wrapped.client(client, successfullyEstablishedConnection: connection)
    }

    public func client(_ client: Client, willRedirectFrom oldServerAddress: ServerAddress, to newServerAddress: ServerAddress) {
        wrapped.client(client, willRedirectFrom: oldServerAddress, to: newServerAddress)
    }

    public func client(_ client: Client, didSuccessfullyRedirectTo newConnection: Connection) {
        wrapped.client(client, didSuccessfullyRedirectTo: newConnection)
    }

    public func clientDisconnectedFromServer(_ client: Client) {
        wrapped.clientDisconnectedFromServer(client)
    }

    /// Returns self, as we're already wrapped. Purely for protocol conformance reasons.
    public func asAnyReceivesClientUpdates() -> AnyReceivesClientUpdates {
        return self
    }
}

/**
 A client encapsulates a single connection to a server.

 The connection is described by the client's `connection` property.
 A the `connection` property may be initialized by calling the `connect(to serverAddress:)` instance method.
 */
public final class Client: UpdateNotifier {

    // MARK: - System data

    public let resourceManager: ResourceManager
    public let system: System

    // MARK: - Chaining Updates
    
    public var objectsWithLinkedActions: [AnyReceivesClientUpdates] = []

    // MARK: -

    public private(set) var connection: Connection?

    // MARK: - Creating a Client

    public init(system: System, resourceManager: ResourceManager) {

        // Initialise values

        self.system = system
        self.resourceManager = resourceManager
    }

    // MARK: - Managing the Client's Connection

    public func disconnect() {
        connection = nil
        applyActionToChainedObjects({ $0.clientDisconnectedFromServer(self) })
    }

    /// Establishes a connection to the given address.
    ///
    /// Client will notify all objects waiting for an update when the connection has been successfully established by calling `client(_ client:successfullyEstablishedConnection:)`
    public func connect(to address: ServerAddress, tls: Bool = false, defaultLobby: Lobby) {
        Logger.log("Connecting to \(address)!", tag: .General)
        guard let connection = Connection(
            address: address,
            client: self,
            resourceManager: resourceManager,
            preferencesController: PreferencesController.default,
            baseCacheDirectory: system.configDirectory,
            defaultLobby: defaultLobby
        ) else {
            return
        }
        applyActionToChainedObjects({ $0.client(self, successfullyEstablishedConnection: connection) })

        self.connection = connection
	}

    /// Destroys the current connection and connects to the new address.
    func redirect(to address: ServerAddress, tls: Bool, defaultLobby: Lobby) {
        connection = nil
        connect(to: address, tls: tls, defaultLobby: defaultLobby)
    }

    // MARK: - Receiving Messages from the Server

    /// Handles an error from the server.
    func receivedError(_ error: ServerError) {
        switch error {
		default:
            Logger.log("\(error)", tag: .ServerError)
//            fatalError()
			#warning("FIXME")
        }
    }

    func didReceiveMessageFromServer(_ message: String) {}
}
