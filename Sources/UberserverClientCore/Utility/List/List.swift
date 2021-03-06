//
//  List.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 16/7/19.
//  Copyright © 2019 MasterBel2. All rights reserved.
//

import Foundation

public protocol ListDelegate: AnyObject {
    /// Notifies the delegate that the list added an item with the given ID at the given index.
    func list(_ list: ListProtocol, didAddItemWithID id: Int, at index: Int)
    /// Notifies the delegate that the list removed an item at the given index.
    func list(_ list: ListProtocol, didRemoveItemAt index: Int)
    /// Informs the delegate that an item was updated and its view should be reloaded.
    func list(_ list: ListProtocol, itemWasUpdatedAt index: Int)
    /// Notifies the delegate that the list moved an item between the given indices.
    func list(_ list: ListProtocol, didMoveItemFrom index1: Int, to index2: Int)
    /// Notifies the delegate that the list will clear all data, so that they may remove all data associated with the list.
    func listWillClear(_ list: ListProtocol)
    /// Indicates that the list just sorted itself from scratch, likely as a result of sort rules changing.
    func listDidSort(_ list: ListProtocol)
}

public extension ListDelegate {
    func listDidSort(_ list: ListProtocol) {}
}

/// A wrapper protocol for lists which hides the generic API.
public protocol ListProtocol: AnyObject {
	func addDelegate<DelegateObject: ListDelegate>(_ delegate: DelegateObject)
	func removeDelegate<DelegateObject: ListDelegate>(_ delegate: DelegateObject)
    var title: String { get }
    var sortedItemCount: Int { get }
	var sortedItemsByID: [Int] { get }
}

/// A list wraps a set of objects by their ID.
///
/// - warning: This class is **not** thread-safe and must be updated serially from a single thread.
public final class List<ListItem>: ListProtocol, UpdateNotifier {

    // MARK: - Behaviour

    /// Determines whether updates to the list's parent (e.g. Addition, removal) should automatically True by default.
    ///
    /// If it is intended for this value to be false, ListItem should be a value type, as for reference types property changes
    /// will always be inherited.
    var automaticallyInheritParentUpdates: Bool = true

    // MARK: - Properties

    // Metadata

    /// A brief, human-readable string describing the content of the list
    public let title: String

    // Content

    /// An array of item IDs, sorted in the order determined by the values of the item's properties, as indicated by the sort key. `itemIndicies` and `items` must be updated before updating this array.
    public private(set) var sortedItemsByID: [Int] = [] {
        didSet {
            #if DEBUG
            validateList()
            #endif
        }
    }
    /// The items contained in the list, keyed by their ID.
    public private(set) var items: [Int : ListItem] = [:]
    /// The locations of the items in the sorted list, keyed by their ID.
    public private(set) var itemIndicies: [Int : Int] = [:]

    // MARK: - Structure

    /// The list of which this is a sublist.
    private(set) weak var parent: List<ListItem>?

    /// An array of lists that are a subset of this list.
    ///
    /// Displayed lists will often contain a subset of another list. Creating a list as a
    /// sublist of another list allows modifications happen to all sublists automatically.
    private(set) var sublists: [List<ListItem>] = []

    // MARK: - Dependencies

	public var objectsWithLinkedActions: [() -> ListDelegate?] = []

    // MARK: - ListProtocol

    /// Alias for addObject to satisfy ListProtocol requirements.
	public func addDelegate<DelegateObject: ListDelegate>(_ delegate: DelegateObject) {
		addObject(delegate)
	}
	/// Alias for removeObject to satisfy ListProtocol requirements.
	public func removeDelegate<DelegateObject: ListDelegate>(_ delegate: DelegateObject) {
		removeObject(delegate)
	}

    // MARK: - Sorting

    public enum SortDirection {
        /// Indicates the lowest values at the start of the list, and the greatest values at the end of the list.
        case ascending
        /// Indicates the greatest values at the start of the list, and the lowest values at the end of the list.
        case descending
    }

    public var sortDirection: SortDirection = .descending {
        didSet {
            switch sortDirection {
            case .descending:
                _forwardSortCondition = .firstIsGreaterThanSecond
                _reverseSortCondition = .firstIsLesserThanSecond
            case .ascending:
                _forwardSortCondition = .firstIsLesserThanSecond
                _reverseSortCondition = .firstIsGreaterThanSecond
            }
            sortFromScratch()
        }
    }

    private var _forwardSortCondition: ValueRelation = .firstIsGreaterThanSecond
    private var _reverseSortCondition: ValueRelation = .firstIsLesserThanSecond
	
	/// Describes how the list should sort its items. Re-sorts the list on update.
    public var sorter: ListSorter {
        didSet {
            sortFromScratch()
        }
    }

    /// Re-sorts the list based on the given property.
    func sort<T: Comparable>(by property: @escaping (ListItem) -> T) {
        var sorter = PropertySorter<ListItem, T>(property: property)
        sorter.list = self
        self.sorter = sorter
    }

    /// Sorts the list.
    private func sortFromScratch() {
        sortedItemsByID.sort(by: { sorter.relation(betweenItemIdentifiedBy: $0, andItemIdentifiedBy: $1) == _forwardSortCondition })
        for (index, itemID) in sortedItemsByID.enumerated() {
            itemIndicies[itemID] = index
        }
    }

    // MARK: - Lifecycle

    /// Creates a list with the given title, sorted by the given sort key
    public init(title: String, sorter: ListSorter, parent: List<ListItem>? = nil) {
        self.title = title
        self.sorter = sorter
        self.parent = parent

        parent?.sublists.append(self)
    }

    convenience init<T: Comparable>(title: String, property: @escaping (ListItem) -> T, parent: List<ListItem>? = nil) {
        var sorter = PropertySorter<ListItem, T>(property: property)

        self.init(title: title, sorter: sorter, parent: parent)
        sorter.list = self
        self.sorter = sorter
    }

    // MARK: - Retrieving list data

    /// The number of items in the list.
    public var sortedItemCount: Int {
        return sortedItemsByID.count
    }

    /// The ID of the item at the given location.
    public func itemID(at index: Int) -> Int? {
        guard (0..<sortedItemCount).contains(index) else {
            return nil
        }
        return sortedItemsByID[index]
    }

    /// The item in the given position in the list.
    public func item(at index: Int) -> ListItem? {
        guard let itemID = self.itemID(at: index) else {
            return nil
        }
        return items[itemID]
    }

    // MARK: - Updating list content

    /// Removes all data from the list.
    func clear() {
		applyActionToChainedObjects({ $0.listWillClear(self) })
        sublists.forEach({ $0.clear() })
        items = [:]
        sortedItemsByID = []
        itemIndicies = [:]
    }

    /// Inserts the item into the list, with the ID as its key, locating it according to the
    /// selected sorting method.
    func addItem(_ item: ListItem, with id: Int) {
        items[id] = item
        for index in 0..<sortedItemCount {
            let idAtIndex = sortedItemsByID[index]
            if sorter.relation(betweenItemIdentifiedBy: id, andItemIdentifiedBy: idAtIndex) != _forwardSortCondition {
                // Update the location of the items this displaces. Must happen before we sort the
                // so that we can identify them by their current location.
                for indexToUpdate in index..<sortedItemCount {
                    let idToUpdate = sortedItemsByID[indexToUpdate]
                    itemIndicies[idToUpdate] = indexToUpdate + 1
                }
                placeItem(item, with: id, at: index)
                return
            }
        }
        placeItem(item, with: id, at: sortedItemCount)
    }

    /// A helper function that ensures an item is in the parent list before adding it to this list.
    func addItemFromParent(id: Int) {
        if let item = self.parent?.items[id] {
            self.addItem(item, with: id)
        }
    }

    /// Places an item in the list and sets its indexes etc. Does not update the items that it displaces.
    private func placeItem(_ item: ListItem, with id: Int, at index: Int) {
        itemIndicies[id] = index
        sortedItemsByID.insert(id, at: index)
		applyActionToChainedObjects({ $0.list(self, didAddItemWithID: id, at: index)})
    }

    /// Updates the list's sort order and notifies the delegate that the item has been updated.
    func respondToUpdatesOnItem(identifiedBy id: Int) {
        guard let index = itemIndicies[id] else {
                return
        }

        var indexesToUpdate: [Int] = []
        var newIndex = index

        for (relationToMove, offset) in [(_forwardSortCondition, 1), (_reverseSortCondition, -1)] {
            var nextIndex: Int {
                return newIndex + offset
            }
            while (0..<sortedItemCount).contains(nextIndex),
                sorter.relation(betweenItemIdentifiedBy: id, andItemIdentifiedBy: sortedItemsByID[nextIndex]) == relationToMove {
                newIndex = nextIndex
                indexesToUpdate.append(newIndex)
            }
            if newIndex != index {
                // Update indexes associated with IDs before updating IDs associated with indexes, because it depends on the array
                // -1 * offset, since they move the opposite direction to the updated item
                indexesToUpdate.forEach({
                    itemIndicies[self.sortedItemsByID[$0]] = $0 - offset
                })
                // Update the index associated with the updated ID
                itemIndicies[id] = newIndex
                sortedItemsByID.moveItem(from: index, to: newIndex)
				applyActionToChainedObjects({ $0.list(self, didMoveItemFrom: index, to: newIndex) })
                break
            }
        }
		applyActionToChainedObjects({ $0.list(self, itemWasUpdatedAt: newIndex)})
        for sublist in sublists {
            sublist.respondToUpdatesOnItem(identifiedBy: id)
        }
    }

    /// Removes the item with the given ID from the list.
    func removeItem(withID id: Int) {
        guard let index = itemIndicies[id] else {
            return
        }
        itemIndicies.removeValue(forKey: id)
        for indexToUpdate in (index + 1)..<sortedItemCount {
            let idToUpdate = sortedItemsByID[indexToUpdate]
            itemIndicies[idToUpdate] = indexToUpdate - 1
        }
        items.removeValue(forKey: id)
        sortedItemsByID.remove(at: index)
        sublists.forEach { $0.removeItem(withID: id) }

		applyActionToChainedObjects({ $0.list(self, didRemoveItemAt: index) })
    }

    // MARK: - List integrity

    /// Checks whether `itemIndicies` and `sortedItemsByID` agree, and prints an error message to the console if an inconsistency is detected.
    private func validateList() {
        var valid = true
        items.forEach({
            let key = $0.key
            if let position = itemIndicies[$0.key] {
                let itemAtPosition = sortedItemsByID[position]

                if key != itemAtPosition {
                    valid = false
                }
            } else {
                valid = false
            }
        })

        if !valid {
            debugOnlyPrint("Internal inconsistency detected in list \(title): \(self)")
            items.map({
                let key = $0.key
                if let position = itemIndicies[$0.key] {
                    let itemAtPosition = sortedItemsByID[position]
                    return "Item \($0.key): Position \(position), ItemAtPosition \(itemAtPosition), valid: \(key == itemAtPosition)"
                } else {
                    return "Item \($0.key): Position: nil, valid: false"
                }
            }).forEach({ debugOnlyPrint($0)})
        }
    }
}
