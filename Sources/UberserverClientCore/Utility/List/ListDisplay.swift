//
//  ListDisplay.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 26/8/19.
//  Copyright © 2019 MasterBel2. All rights reserved.
//

import Foundation

public protocol ListDisplay: AnyObject {
    func addSection(_ list: ListProtocol)
    func removeSection(_ list: ListProtocol)
}
