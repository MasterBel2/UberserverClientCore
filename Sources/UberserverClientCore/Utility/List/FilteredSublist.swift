public final class FilteredSublist<ListItem>: ListDelegate {
    /// Intended to be immutable, other than initial set
    public private(set) weak var parentList: List<ListItem>?
    public let data = List<ListItem>()

    public init(parent: List<ListItem>, filter: @escaping (Int, ListItem) -> Bool) {
        self.parentList = parent
        self.filter = filter

        parent.addObject(self.asAnyListDelegate())

        parent.items.forEach({ data.addItem($0.value, with: $0.key) })
    }

    public let filter: (Int, ListItem) -> Bool

    // MARK: - ListDelegate

    public func list(_ list: List<ListItem>, didAdd user: ListItem, identifiedBy id: Int) {
        guard list === parentList, let item = parentList?.items[id] else { return }
        if filter(id, item) {
            data.addItem(item, with: id)
        }
    }

    public func list(_ list: List<ListItem>, didRemoveItemIdentifiedBy id: Int) {
        guard list === parentList else { return }
        data.removeItem(withID: id)
    }

    public func list(_ list: List<ListItem>, itemWithIDWasUpdated id: Int) {
        guard list === parentList, let item = parentList?.items[id] else { return }
        if filter(id, item) {
            data.addItem(item, with: id)
        } else {
            data.removeItem(withID: id)
        }
        data.respondToUpdatesOnItem(identifiedBy: id)
    }

    public func listWillClear(_ list: List<ListItem>) {
        guard list === parentList else { return }
        data.clear()
    }
}