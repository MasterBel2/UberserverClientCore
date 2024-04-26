import Foundation

public class AnyListOrderDelegate<ListItem>: ListOrderDelegate, Box {
    /// Notifies the delegate that the list added an item with the given ID at the given index.
    public func listOrder(_ listOrder: ListOrder<ListItem>, didAddItemWithID id: Int, at index: Int) {
        _didAddItem(listOrder, id, index)
    }
    /// Notifies the delegate that the list removed an item at the given index.
    public func listOrder(_ listOrder: ListOrder<ListItem>, didRemoveItemIdentifiedBy id: Int, at index: Int) {
        _didRemoveItem(listOrder, id, index)
    }
    /// Informs the delegate that an item was updated and its view should be reloaded.
    public func listOrder(_ listOrder: ListOrder<ListItem>, itemIdentifiedBy id: Int, wasUpdatedAt index: Int) {
        _didUpdateItem(listOrder, id, index)
    }
    /// Notifies the delegate that the list moved an item between the given indices.
    public func listOrder(_ listOrder: ListOrder<ListItem>, didMoveItemIdentifiedBy id: Int, from index1: Int, to index2: Int) {
        _didMoveItem(listOrder, id, index1, index2)
    }
    /// Notifies the delegate that the list will clear all data, so that they may remove all data associated with the list.
    public func listWillClear(_ listOrder: ListOrder<ListItem>) {
        _willClear(listOrder)
    }
    /// Indicates that the list just sorted itself from scratch, likely as a result of sort rules changing.
    public func listDidSort(_ listOrder: ListOrder<ListItem>) {
        _didSort(listOrder)
    }

    private let _didAddItem: (ListOrder<ListItem>, Int, Int) -> Void
    private let _didMoveItem: (ListOrder<ListItem>, Int, Int, Int) -> Void
    private let _didUpdateItem: (ListOrder<ListItem>, Int, Int) -> Void
    private let _didRemoveItem: (ListOrder<ListItem>, Int, Int) -> Void
    private let _willClear: (ListOrder<ListItem>) -> Void
    private let _didSort: (ListOrder<ListItem>) -> Void

    public let wrappedAny: AnyObject

    public init<T: ListOrderDelegate>(valueToWrap: T) where T.ListItem == ListItem {
        _didAddItem = valueToWrap.listOrder(_:didAddItemWithID:at:)   
        _didMoveItem = valueToWrap.listOrder(_:didMoveItemIdentifiedBy:from:to:)
        _didUpdateItem = valueToWrap.listOrder(_:itemIdentifiedBy:wasUpdatedAt:)
        _didRemoveItem = valueToWrap.listOrder(_:didRemoveItemIdentifiedBy:at:)
        _willClear = valueToWrap.listWillClear(_:)
        _didSort = valueToWrap.listDidSort(_:)

        wrappedAny = valueToWrap
    }

    /// Returns self, as we're already wrapped. Purely for protocol conformance reasons.
    public func asAnyListOrderDelegate() -> AnyListOrderDelegate<ListItem> {
        return self
    }
}

public protocol ListOrderDelegate: AnyObject {
    associatedtype ListItem

    /// Notifies the delegate that the list added an item with the given ID at the given index.
    func listOrder(_ listOrder: ListOrder<ListItem>, didAddItemWithID id: Int, at index: Int)
    /// Notifies the delegate that the list removed an item at the given index.
    func listOrder(_ listOrder: ListOrder<ListItem>, didRemoveItemIdentifiedBy id: Int, at index: Int)
    /// Informs the delegate that an item was updated and its view should be reloaded.
    func listOrder(_ listOrder: ListOrder<ListItem>, itemIdentifiedBy id: Int, wasUpdatedAt index: Int)
    /// Notifies the delegate that the list moved an item between the given indices.
    func listOrder(_ listOrder: ListOrder<ListItem>, didMoveItemIdentifiedBy id: Int, from index1: Int, to index2: Int)
    /// Notifies the delegate that the list will clear all data, so that they may remove all data associated with the list.
    func listWillClear(_ listOrder: ListOrder<ListItem>)
    /// Indicates that the list just sorted itself from scratch, likely as a result of sort rules changing.
    func listDidSort(_ listOrder: ListOrder<ListItem>)
    /// Returns a type-erasing wrapper of self.
    func asAnyListOrderDelegate() -> AnyListOrderDelegate<ListItem>
}

extension ListOrderDelegate {
    public func asAnyListOrderDelegate() -> AnyListOrderDelegate<ListItem> {
        return AnyListOrderDelegate(valueToWrap: self)
    }    
}

/**
  Records an ordering for the items contained in a list.
 */
public final class ListOrder<ListItem>: ListDelegate, UpdateNotifier {
    public let listToSort: List<ListItem>

    public private(set) var itemIndices: [Int : Int] = [:]
    public private(set) var sortedItemsByID: [Int] = []

    public var objectsWithLinkedActions: [AnyListOrderDelegate<ListItem>] = []

    /// The number of items in the list.
    public var sortedItemCount: Int {
        return sortedItemsByID.count
    }

    /// Re-sorts the list based on the given property.
    public func setSortRule<T: Comparable>(by property: @escaping (ListItem) -> T) {
        var sorter = PropertySorter<ListItem, T>(property: property)
        sorter.list = listToSort
        self.sortRule = sorter
    }

    public func itemID(at index: Int) -> Int? {
        guard (0..<sortedItemCount).contains(index) else {
            return nil
        }
        return sortedItemsByID[index]
    }

    public func item(at index: Int) -> ListItem? {
        guard let itemID = self.itemID(at: index) else {
            return nil
        }
        return listToSort.items[itemID]
    }

    public init(listToSort: List<ListItem>, sortRule: ListSorter) {
        self.sortRule = sortRule
        self.listToSort = listToSort

        for (id, item) in listToSort.items {
            list(listToSort, didAdd: item, identifiedBy: id)
        }

        listToSort.addObject(self.asAnyListDelegate())
    }

    public convenience init<T: Comparable>(listToSort: List<ListItem>, property: @escaping (ListItem) -> T) {
        var sorter = PropertySorter<ListItem, T>(property: property)
        sorter.list = listToSort
        self.init(listToSort: listToSort, sortRule: sorter)
    }

    public enum SortDirection {
        /// Indicates the lowest values at the start of the list, and the greatest values at the end of the list.
        case ascending
        /// Indicates the greatest values at the start of the list, and the lowest values at the end of the list.
        case descending
    }

    public var sortDirection: SortDirection = .descending {
        didSet {
            sortFromScratch() // TODO - something more intelligent like simply flipping the id array, then updating the id index map? 
        }
    }

    public var sortRule: ListSorter {
        didSet {
            sortFromScratch()
        }
    }

    private var firstShouldAppearBeforeSecond: ValueRelation {
        switch sortDirection {
        case .ascending:
            return .firstIsLesserThanSecond
        case .descending:
            return .firstIsGreaterThanSecond
        }
    }

    private var secondShouldAppearBeforeFirst: ValueRelation {
        switch sortDirection {
        case .ascending:
            return .firstIsGreaterThanSecond
        case .descending:
            return .firstIsLesserThanSecond
        }
    }

    /// Sorts the list.
    private func sortFromScratch() {
        sortedItemsByID.sort(by: { sortRule.relation(betweenItemIdentifiedBy: $0, andItemIdentifiedBy: $1) == firstShouldAppearBeforeSecond })
        for (index, itemID) in sortedItemsByID.enumerated() {
            itemIndices[itemID] = index
        }
    }

    /// Places an item in the list and sets its indexes etc. Does not update the items that it displaces.
    private func placeItem(_ item: ListItem, with id: Int, at index: Int) {
        itemIndices[id] = index
        sortedItemsByID.insert(id, at: index)
        applyActionToChainedObjects({ $0.listOrder(self, didAddItemWithID: id, at: index)})
    }

    public func list(_ list: List<ListItem>, didAdd item: ListItem, identifiedBy id: Int) {
        guard list === listToSort, let item = listToSort.items[id] else { return }

        for (index, idAtIndex) in sortedItemsByID.enumerated() {
            if sortRule.relation(betweenItemIdentifiedBy: id, andItemIdentifiedBy: idAtIndex) == firstShouldAppearBeforeSecond {
                // Update the location of the items this displaces. Must happen before we sort the
                // so that we can identify them by their current location.
                for indexToUpdate in index..<sortedItemCount {
                    let idToUpdate = sortedItemsByID[indexToUpdate]
                    itemIndices[idToUpdate] = indexToUpdate + 1
                }
                placeItem(item, with: id, at: index)
                return
            }
        }
        placeItem(item, with: id, at: sortedItemCount)
    }

    public func list(_ list: List<ListItem>, didRemoveItemIdentifiedBy id: Int) {
        guard list === listToSort, let index = itemIndices[id] else { return }
        itemIndices.removeValue(forKey: id)

        for indexToUpdate in (index + 1)..<sortedItemCount {
            let idToUpdate = sortedItemsByID[indexToUpdate]
            itemIndices[idToUpdate] = indexToUpdate - 1
        }
        sortedItemsByID.remove(at: index)

		applyActionToChainedObjects({ $0.listOrder(self, didRemoveItemIdentifiedBy: id, at: index) })
    }

    public func list(_ list: List<ListItem>, itemWithIDWasUpdated id: Int) {
        guard list === listToSort else { return }
        guard let index = itemIndices[id] else {
                return
        }

        var indexesToUpdate: [Int] = []
        var newIndex = index

        for (relationToMove, offset) in [(firstShouldAppearBeforeSecond, -1), (secondShouldAppearBeforeFirst, 1)] {
            var nextIndex: Int {
                return newIndex + offset
            }
            while (0..<sortedItemCount).contains(nextIndex),
                sortRule.relation(betweenItemIdentifiedBy: id, andItemIdentifiedBy: sortedItemsByID[nextIndex]) == relationToMove {
                newIndex = nextIndex
                indexesToUpdate.append(newIndex)
            }
            if newIndex != index {
                // Update indexes associated with IDs before updating IDs associated with indexes, because it depends on the array
                // -1 * offset, since they move the opposite direction to the updated item
                indexesToUpdate.forEach({
                    itemIndices[self.sortedItemsByID[$0]] = $0 - offset
                })
                // Update the index associated with the updated ID
                itemIndices[id] = newIndex
                sortedItemsByID.moveItem(from: index, to: newIndex)
				applyActionToChainedObjects({ $0.listOrder(self, didMoveItemIdentifiedBy: id, from: index, to: newIndex) })
                break
            }
        }
		applyActionToChainedObjects({ $0.listOrder(self, itemIdentifiedBy: id, wasUpdatedAt: newIndex) })
    }

    public func listWillClear(_ list: List<ListItem>) {
        guard list === listToSort else { return }
        itemIndices = [:]
        sortedItemsByID = []
    }

    /// Checks whether `itemIndicies` and `sortedItemsByID` agree, and prints an error message to the console if an inconsistency is detected.
    private func validateList() {
        var valid = true
        listToSort.items.forEach({
            let key = $0.key
            if let position = itemIndices[$0.key] {
                let itemAtPosition = sortedItemsByID[position]

                if key != itemAtPosition {
                    valid = false
                }
            } else {
                valid = false
            }
        })

        if !valid {
            Logger.log("Internal inconsistency detected in list sorter for \(listToSort): \(self)", tag: .ClientStateError)
            listToSort.items.map({
                let key = $0.key
                if let position = itemIndices[$0.key] {
                    let itemAtPosition = sortedItemsByID[position]
                    return "Item \($0.key): Position \(position), ItemAtPosition \(itemAtPosition), valid: \(key == itemAtPosition)"
                } else {
                    return "Item \($0.key): Position: nil, valid: false"
                }
            }).forEach({ Logger.log($0, tag: .ClientStateError) })
        }
    }
}
