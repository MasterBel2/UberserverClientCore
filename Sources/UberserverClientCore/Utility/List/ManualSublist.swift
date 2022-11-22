public final class ManualSublist<ListItem>: ListDelegate {
    /// Intended to be immutable, other than initial set
    public private(set) weak var parentList: ListType?
    public let data = ListType()

    public typealias ListType = List<ListItem>

    public init(parent: ListType) {
        self.parentList = parent

        parent.addObject(self.asAnyListDelegate())
    }

    public var items: [Int : ListItem] {
        return data.items
    }

    public func addItemFromParent(id: Int) {
        if let item = parentList?.items[id] {
            data.addItem(item, with: id)
        }
    }

    // MARK: - ListDelegate

    public func list(_ list: List<ListItem>, didAdd item: ListItem, identifiedBy id: Int) {}

    public func list(_ list: List<ListItem>, didRemoveItemIdentifiedBy id: Int) {
        guard list === parentList else { return }
        data.removeItem(withID: id)
    }

    public func list(_ list: List<ListItem>, itemWithIDWasUpdated id: Int) {
        guard list === parentList else { return }
        data.respondToUpdatesOnItem(identifiedBy: id)
    }

    public func listWillClear(_ list: List<ListItem>) {
        guard list === parentList else { return }
        data.clear()
    }
}