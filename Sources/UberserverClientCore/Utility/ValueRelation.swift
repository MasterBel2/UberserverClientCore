//
//  ValueRelation.swift
//  
//
//  Created by MasterBel2 on 3/3/21.
//

import Foundation

/// A value indicating the relationship between two Comparables.
public enum ValueRelation {
    /// Indicates that the two values are equal.
    case firstAndSecondAreEqual
    /// Indicates the first value is greater than the second.
    case firstIsGreaterThanSecond
    /// Indicates the second value is greater than the first.
    case firstIsLesserThanSecond

    init<T: Comparable>(value1: T, value2: T) {
        if value1 < value2 {
            self = .firstIsLesserThanSecond
        } else if value1 == value2 {
            self = .firstAndSecondAreEqual
        } else {
            self = .firstIsGreaterThanSecond
        }
    }
}
