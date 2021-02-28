//
//  Client.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 8/9/19.
//  Copyright © 2019 MasterBel2. All rights reserved.
//

import Foundation
import ServerAddress

public protocol ReceivesClientUpdates {
    /// Indicates that the client has created a `Connection` object that it will use to connect to a server.
    func client(_ client: Client, didPrepare connection: Connection)
    /// Indicates that the client is about to destroy its connection object, usually directly after the connection disconnects from a server.
    func client(_ client: Client, willDestroy connection: Connection)
}

public extension ReceivesClientUpdates {
    func client(_ client: Client, didPrepare connection: Connection) {}
    func client(_ client: Client, willDestroy connection: Connection) {}
}

/**
 A client encapsulates a single connection to a server.

 The connection is described by the client's `connection` property.
 A the `connection` property may be initialized by calling the `connect(to serverAddress:)` instance method.
 */
public final class Client: UpdateNotifier {
    
    // MARK: - Client State

    /// Executes a block if the client is not connected to a server, logging an error on failure.
    public func inDisconnectedState<ReturnType>(_ block: () -> ReturnType, file: String = #file, function: String = #function, line: Int = #line) -> ReturnType? {
        if connection == nil {
            return block()
        } else {
            Logger.log("\(file):\(line) \(function): Client is not disconnected.", tag: .ClientStateError)
            return nil
        }
    }

    /// Executes a block if the client is connected to a server, logging an error on failure.
    public func inConnectedState<ReturnType>(_ block: (Connection) -> ReturnType, file: String = #file, function: String = #function, line: Int = #line) -> ReturnType? {
        if let connection = connection {
            return block(connection)
        } else {
            Logger.log("\(file):\(line) \(function): Client is not connected to a server.", tag: .ClientStateError)
            return nil
        }
    }

    /// Executes a block if the client is authenticated with a server, logging an error on failure.
    public func inAuthenticatedState<ReturnType>(_ block: (AuthenticatedClient, Connection) -> ReturnType, file: String = #file, function: String = #function, line: Int = #line) -> ReturnType? {
        let result = inConnectedState({ (connection: Connection) -> ReturnType? in
            if let authenticatedClient = connection.authenticatedClient {
                return block(authenticatedClient, connection)
            } else {
                return nil
            }
        })
        if let result = result {
            return result
        } else {
            Logger.log("\(file):\(line) \(function): User is not authenticated.", tag: .ClientStateError)
            return nil
        }
    }

    /// Executes a block if the client is in a battleroom, logging an error on failure.
    public func inBattleroomState<ReturnType>(_ block: (Battleroom, AuthenticatedClient, Connection) -> ReturnType, file: String = #file, function: String = #function, line: Int = #line) -> ReturnType? {
        let result = inAuthenticatedState { (authenticatedClient: AuthenticatedClient, connection: Connection) -> ReturnType? in
            if let battleroom = authenticatedClient.battleroom {
                return block(battleroom, authenticatedClient, connection)
            } else {
                return nil
            }
        }
        if let result = result {
            return result
        } else {
            Logger.log("\(file):\(line) \(function): User is not in a battleroom.", tag: .ClientStateError)
            return nil
        }
    }

    // MARK: - System data

    public let resourceManager: ResourceManager
    public let system: System

    // MARK: - Chaining Updates
    
    public var objectsWithLinkedActions: [() -> ReceivesClientUpdates?] = []

    // MARK: - Controlling specific data & interactions

    ///
    public let accountInfoController = AccountInfoController()

    /// The The
    public let userAuthenticationController: UserAuthenticationController

    // MARK: -

    public private(set) var connection: Connection?

    // MARK: - Creating a Client

    public init(system: System, userAuthenticationController: UserAuthenticationController, address: ServerAddress? = nil, resourceManager: ResourceManager) {

        // Initialise values

        self.system = system
        self.resourceManager = resourceManager

        self.userAuthenticationController = userAuthenticationController

        // Configuration

        accountInfoController.client = self
        userAuthenticationController.client = self

        // Initialise server
        if let address = address {
            connect(to: address)
        }
    }

    // MARK: - Managing the Client's Connection

    func reset() {
        if let connection = connection {
            applyActionToChainedObjects({ $0.client(self, willDestroy: connection) })
            connection.disconnect()
            self.connection = nil
        }

        accountInfoController.invalidate()
    }
	
	public func connect(to address: ServerAddress) {
        if let connection = connection {
            connection.redirect(to: address)
        } else {
            let connection = Connection(
                address: address,
                client: self,
                userAuthenticationController: userAuthenticationController,
                baseCacheDirectory: system.configDirectory
            )
            applyActionToChainedObjects({ $0.client(self, didPrepare: connection) })
            connection.connect()
            
            self.connection = connection
        }
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

    func didReceiveMessageFromServer(_ message: String) {
        if message.hasPrefix("Registration date:") {
            let components = message.components(separatedBy: " ")
            guard components.count >= 6 else {
                accountInfoController.setRegistrationDate(.none)
                return
            }
            let dateString = components[2..<5].joined(separator: " ")
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM DD, YYYY"
            guard let date = dateFormatter.date(from: dateString) else { return }
            accountInfoController.setRegistrationDate(date)
        } else if message.hasPrefix("Email address:") {
            let components = message.components(separatedBy: " ")
            if components.count == 3,
                components[2] != "",
                components[2] != "None" {
                accountInfoController.setEmail(components[2])
            } else {
                accountInfoController.setEmail("No email provided")
            }
        } else if message.hasPrefix("Ingame time:") {
            let ingameTimeString = message.components(separatedBy: " ")[2]
            guard let ingameTime = Int(ingameTimeString) else { return }
            accountInfoController.setIngameHours(ingameTime)
        }
    }
}
