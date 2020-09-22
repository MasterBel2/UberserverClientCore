//
//  Array+MoveItem.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 14/11/19.
//  Copyright © 2019 MasterBel2. All rights reserved.
//

import Foundation

extension Array {
    /// Removes an item from its current index in the array and places it at the new index.
    public mutating func moveItem(from oldIndex: Int, to newIndex: Int) {
        let value = self[oldIndex]
        remove(at: oldIndex)
        insert(value, at: newIndex)
    }

    /// Sequentiallly pairs the elements of two equal length arrays.
    public func join<J>(with other: Array<J>) -> [(Element, J)] {
        guard self.count == other.count else {
            fatalError("Cannot join arrays of different sizes!")
        }
        return (0..<self.count).map({ (self[$0], other[$0]) })
    }

}
