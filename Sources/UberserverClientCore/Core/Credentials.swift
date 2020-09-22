//
//  Credentials.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 14/12/19.
//  Copyright © 2019 MasterBel2. All rights reserved.
//

import Foundation

/// Stores a username and its associated password.
public struct Credentials {

    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }

    public let username: String
    public let password: String
}
