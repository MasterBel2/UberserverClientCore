//
//  WindowManager.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 7/8/19.
//  Copyright © 2019 MasterBel2. All rights reserved.
//

import Foundation

/// A set of functions providing a platform-agnostic interface for platform-specific window creation.
public protocol WindowManager {
	/// Immediately displays current and past downloads to the user.
	func presentDownloads(_ controller: DownloadController)

    func presentReplays(_ controller: ReplayController)

    /// Creates a new manager for client-specific windows.
    func newClientWindowManager(clientController: ClientController) -> ClientWindowManager
}

