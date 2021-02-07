//
//  ClientWindowManager.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 9/2/20.
//  Copyright © 2020 MasterBel2. All rights reserved.
//

import Foundation
import ServerAddress

/// A set of functions providing a platform-agnostic interface for platform-specific windows associated with a single client.
public protocol ClientWindowManager {
    func configure(for client: Client)

    func presentInitialWindow()
    /// Displays an window with information about the logged in user's account
    func presentAccountWindow(_ controller: AccountInfoController)

    /// Prompts the interface to select a server.
    func selectServer(completionHandler: @escaping (ServerAddress) -> Void)
    /// Dismisses the server selection interface.
    func dismissServerSelection()
    /// Present a login interface.
    func presentLogin(controller: UserAuthenticationController)
    /// Dismisses the login interface.
    func dismissLogin()

    func resetServerWindows()

    // Battleroom

    func displayBattleroom(_ battleroom: Battleroom)
    func destroyBattleroom()

    // Channels

    func joinedChannel(_ channel: Channel)
    
}
