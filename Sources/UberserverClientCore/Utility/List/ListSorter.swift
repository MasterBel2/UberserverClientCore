//
//  ListSorter.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 26/7/20.
//  Copyright © 2020 MasterBel2. All rights reserved.
//

import Foundation

/// Idenifies a magnitude relationship between two items in a list.
public protocol ListSorter {
    func relation(betweenItemIdentifiedBy id1: Int, andItemIdentifiedBy id2: Int) -> ValueRelation
}

/// Sorts a list according to the property provided by the closure.
public struct PropertySorter<ListItem, Property: Comparable>: ListSorter {
    weak var list: List<ListItem>?
    let property: (ListItem) -> Property

    public func relation(betweenItemIdentifiedBy id1: Int, andItemIdentifiedBy id2: Int) -> ValueRelation {
        guard let item1 = list?.items[id1],
            let item2 = list?.items[id2] else {
                return .firstAndSecondAreEqual
        }
        return ValueRelation(value1: property(item1), value2: property(item2))
    }
}

/// Sorts a list of players in a battleroom according to their trueskills.
public struct BattleroomPlayerListSorter: ListSorter {
    weak var battleroom: Battleroom?

    public func relation(betweenItemIdentifiedBy id1: Int, andItemIdentifiedBy id2: Int) -> ValueRelation {
        guard let trueSkill1 = battleroom?.trueSkill(for: id1),
            let trueSkill2 = battleroom?.trueSkill(for: id2) else {
            return .firstIsGreaterThanSecond
        }
        return ValueRelation(value1: trueSkill1, value2: trueSkill2)
    }
}
