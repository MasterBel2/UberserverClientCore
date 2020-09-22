//
//  ServerSelectionDelegate.swift
//  UberserverClientCore
//
//  Created by MasterBel2 on 22/9/20.
//

import Foundation
import ServerAddress

/// An object that handles a request to connect to a lobbyserver.
public protocol ServerSelectionDelegate: AnyObject {
    func serverSelectionInterface(didSelectServerAt serverAddress: ServerAddress)
}
