//
//  List.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 16/7/19.
//  Copyright © 2019 MasterBel2. All rights reserved.
//

import Foundation

public protocol ListDelegate: AnyObject {
    associatedtype ListItem

    /// Notifies the delegate that the list added an item with the given ID at the given index.
    func list(_ list: List<ListItem>, didAdd item: ListItem, identifiedBy id: Int)
    /// Notifies the delegate that the list removed an item at the given index.
    func list(_ list: List<ListItem>, didRemoveItemIdentifiedBy id: Int)
    /// Informs the delegate that an item was updated and its view should be reloaded.
    func list(_ list: List<ListItem>, itemWithIDWasUpdated id: Int)
    /// Notifies the delegate that the list will clear all data, so that they may remove all data associated with the list.
    func listWillClear(_ list: List<ListItem>)
    /// Returns a type-erasing wrapper of self.
    func asAnyListDelegate() -> AnyListDelegate<ListItem>
}

extension ListDelegate {
    public func asAnyListDelegate() -> AnyListDelegate<ListItem> {
        return AnyListDelegate(valueToWrap: self)
    }    
}

public class AnyListDelegate<ListItem>: ListDelegate, Box {
    public func list(_ list: List<ListItem>, didAdd item: ListItem, identifiedBy id: Int) {
        _didAddItem(list, item, id)
    }

    public func list(_ list: List<ListItem>, didRemoveItemIdentifiedBy id: Int) {
        _didRemoveItem(list, id)
    }

    public func list(_ list: List<ListItem>, itemWithIDWasUpdated id: Int) {
        _didUpdateItem(list, id)
    }

    public func listWillClear(_ list: List<ListItem>) {
        _willClear(list)
    }

    private let _didAddItem: (List<ListItem>, ListItem, Int) -> Void
    private let _didRemoveItem: (List<ListItem>, Int) -> Void
    private let _didUpdateItem: (List<ListItem>, Int) -> Void
    private let _willClear: (List<ListItem>) -> Void

    public let wrappedAny: AnyObject

    public init<T: ListDelegate>(valueToWrap: T) where T.ListItem == ListItem {
        self._didAddItem = valueToWrap.list(_:didAdd:identifiedBy:)
        self._didRemoveItem = valueToWrap.list(_:didRemoveItemIdentifiedBy:)
        self._didUpdateItem = valueToWrap.list(_:itemWithIDWasUpdated:)
        self._willClear = valueToWrap.listWillClear

        self.wrappedAny = valueToWrap
    }

    /// Returns self, as we're already wrapped. Purely for protocol conformance reasons.
    public func asAnyListDelegate() -> AnyListDelegate<ListItem> {
        return self
    }  
}

public final class List<ListItem>: UpdateNotifier {

    /// Necessary to publicise.
    public init() {}

    /// The items contained in the list, keyed by their ID.
    public private(set) var items: [Int : ListItem] = [:]

    // MARK: - UpdateNotifier

	public var objectsWithLinkedActions: [AnyListDelegate<ListItem>] = []

    /// Inserts the item into the list, with the ID as its key, locating it according to the
    /// selected sorting method. For items already in the list, this is a noop.
    public func addItem(_ item: ListItem, with id: Int) {
        guard items[id] == nil else { return }
        items[id] = item
        applyActionToChainedObjects({ $0.list(self, didAdd: item, identifiedBy: id) })
    }

    public func respondToUpdatesOnItem(identifiedBy id: Int) {
        guard items[id] != nil else { return }
        applyActionToChainedObjects({ $0.list(self, itemWithIDWasUpdated: id) })
    }

    /// Removes the item with the given ID from the list.
    public func removeItem(withID id: Int) {
        guard items[id] != nil else { return }
        items.removeValue(forKey: id)
        applyActionToChainedObjects({ $0.list(self, didRemoveItemIdentifiedBy: id) })
    }

    public func clear() {
        applyActionToChainedObjects({ $0.listWillClear(self) })
        items = [:]
    }
}