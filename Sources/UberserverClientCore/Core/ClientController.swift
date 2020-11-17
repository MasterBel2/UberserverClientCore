//
//  ClientController.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 8/9/19.
//  Copyright © 2019 MasterBel2. All rights reserved.
//

import Foundation
import ServerAddress

/**
 Facilitates creation of clients.
 */
public final class ClientController {
    private(set) var clients: [Client] = []
    /// Provides platform-specific windows.
    private let windowManager: WindowManager
    private let resourceManager: ResourceManager
    /// The user's preferences controller.
    let preferencesController: PreferencesController
    let springProcessController: SpringProcessController

    public init(windowManager: WindowManager, resourceManager: ResourceManager, preferencesController: PreferencesController, springProcessController: SpringProcessController) {
        self.windowManager = windowManager
        self.resourceManager = resourceManager
        self.preferencesController = preferencesController
        self.springProcessController = springProcessController
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
    public func connect(to address: ServerAddress) {
        let client = Client(
            windowManager: windowManager.newClientWindowManager(clientController: self),
            resourceManager: resourceManager,
            preferencesController: preferencesController,
            address: address,
            springProcessController: springProcessController
        )
        client.createAndShowWindow()
        clients.append(client)
    }

    /// Creates a new client without a predefined server.
    public func createNewClient() {
        let client = Client(
            windowManager: windowManager.newClientWindowManager(clientController: self),
            resourceManager: resourceManager,
            preferencesController: preferencesController,
            springProcessController: springProcessController
        )
        client.createAndShowWindow()
        clients.append(client)
    }

	/// Forgets the reference to a client.
    public func destroyClient(_ client: Client) {
		clients = clients.filter({ $0 !== client })
    }
}
