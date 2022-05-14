//
//  ClientController.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 8/9/19.
//  Copyright © 2019 MasterBel2. All rights reserved.
//

import Foundation
import ServerAddress

public protocol ReceivesClientControllerUpdates {
    func clientController(_ clientController: ClientController, didCreate client: Client)
}
public extension ReceivesClientControllerUpdates {
    func clientController(_ clientController: ClientController, didCreate client: Client) {}
}

/**
 Facilitates creation of clients.
 */
public final class ClientController: UpdateNotifier {
    private(set) var clients: [Client] = []
    let system: System
    let resourceManager: ResourceManager

    public init(system: System, resourceManager: ResourceManager) {
        self.system = system
        self.resourceManager = resourceManager
    }

    /// On update, inserts the most recent server
    private(set) var recentServers: [URL] = [] {
        didSet {
            if let first = recentServers.first {
                recentServers.removeAll(where: { $0 == first })
            }
            if recentServers.count > 5 {
                recentServers = recentServers.dropLast()
            }
        }
    }

    /// Initiates a client which will connect to the given address.
    public func connect(to address: ServerAddress, tls: Bool, defaultLobby: Lobby) {
        let client = Client(
            system: system,
            resourceManager: resourceManager
        )
        client.connect(to: address, tls: tls, defaultLobby: defaultLobby)
        clients.append(client)
        applyActionToChainedObjects({ $0.clientController(self, didCreate: client) })
    }

    /// Creates a new client without a predefined server.
    public func createNewClient() {
        let client = Client(
            system: system,
            resourceManager: resourceManager
        )
        clients.append(client)
        applyActionToChainedObjects({ $0.clientController(self, didCreate: client) })
    }

    /// Forgets the reference to a client.
    public func destroyClient(_ client: Client) {
        clients = clients.filter({ $0 !== client })
    }
    
    // MARK: - UpdateNotifier
    
    public var objectsWithLinkedActions: [() -> ReceivesClientControllerUpdates?] = []
}
