import XCTest
@testable import UberserverClientCore

final class UberserverClientCoreTests: XCTestCase {

    class Test: Equatable {
        static func == (lhs: UberserverClientCoreTests.Test, rhs: UberserverClientCoreTests.Test) -> Bool {
            return lhs.value == rhs.value
        }

        var value: Int
        init(value: Int) {
            self.value = value
        }
    }

    private func list(sortDirection: List<Test>.SortDirection, items: [(id: Int, value: Int)]) -> List<Test> {
        let list = List<Test>(title: "Test", property: { $0.value })
        list.sortDirection = sortDirection

        for item in items {
            list.addItem(Test(value: item.value), with: item.id)
        }

        return list
    }

    private func assertItemOrder(items: [(id: Int, value: Int)], in list: List<Test>, file: StaticString = #filePath, line: UInt = #line) {

        for (index, item) in items.enumerated() {
            if item.id != list.sortedItemsByID[index] {
                XCTFail("Item order incorrect! item.id: \(item.id), list.sortedItemsByID[index]: \(list.sortedItemsByID[index])", file: file, line: line)
            }
            if item.value != list.items[item.id]?.value {
                XCTFail("Item not indexed under correct ID! id: \(item.id) item.value: \(item.value), list.items[item.id]?.value: \(list.items[item.id]?.value)", file: file, line: line)
            }
            if index != list.itemIndicies[item.id] {
                XCTFail("Position cache incorrect! id: \(item.id) index: \(index), list.itemIndicies[item.id]: \(list.itemIndicies[item.id])", file: file, line: line)
            }
        }
    }

    private func queueListUpdates(items: [(id: Int, value: Int)], in list: List<Test>) {
        for item in items {
            list.items[item.id]?.value = item.value
            list.respondToUpdatesOnItem(identifiedBy: item.id)
        }
    }

    // Default sort order / .descending

    func testReverseOrderedInsertDescending() {
        let initialItems = [
            (id: 0, value: 2),
            (id: 1, value: 1),
            (id: 2, value: 0)
        ]

        let testList = list(sortDirection: .descending, items: initialItems)

        assertItemOrder(items: initialItems, in: testList)
    }

    func testOrderedInsertDescending() {
        let initialItems = [
            (id: 0, value: 0),
            (id: 1, value: 1),
            (id: 2, value: 2)
        ]
        let expected = [
            (id: 2, value: 2),
            (id: 1, value: 1),
            (id: 0, value: 0)
        ]

        let testList = list(sortDirection: .descending, items: initialItems)

        assertItemOrder(items: expected, in: testList)
    }

    func testUnOrderedInsertDescending() {
        let initialItems = [
            (id: 0, value: 0),
            (id: 1, value: 1),
            (id: 2, value: 2)
        ]

        let testList = list(sortDirection: .descending, items: initialItems)

        queueListUpdates(items: [
            (id: 0, value: 1),
            (id: 1, value: 0),
            (id: 2, value: 2)
        ], in: testList)

        assertItemOrder(items: [
            (id: 2, value: 2),
            (id: 0, value: 1),
            (id: 1, value: 0)
        ], in: testList)
    }

    // Default sort order / .ascending

    func testOrderedInsertAscending() {
        let initialItems = [
            (id: 0, value: 0),
            (id: 1, value: 1),
            (id: 2, value: 2)
        ]

        let testList = list(sortDirection: .ascending, items: initialItems)

        assertItemOrder(items: initialItems, in: testList)
    }

    func testReverseOrderedInsertAscending() {
        let initialItems = [
            (id: 0, value: 2),
            (id: 1, value: 1),
            (id: 2, value: 0)
        ]
        let expectedItems = [
            (id: 2, value: 0),
            (id: 1, value: 1),
            (id: 0, value: 2)
        ]

        let testList = list(sortDirection: .ascending, items: initialItems)

        assertItemOrder(items: expectedItems, in: testList)
    }

    func testUnOrderedInsertAscending() {
        let initialItems = [
            (id: 0, value: 0),
            (id: 1, value: 0),
            (id: 2, value: 0)
        ]

        let testList = list(sortDirection: .ascending, items: initialItems)

        queueListUpdates(items: [
            (id: 0, value: 1),
            (id: 1, value: 0),
            (id: 2, value: 2)
        ], in: testList)

        assertItemOrder(items: [
            (id: 1, value: 0),
            (id: 0, value: 1),
            (id: 2, value: 2)
        ], in: testList)
    }

//    static var allTests = [
//        ("testOrderedInsert", testOrderedInsert),
//        ("testReverseOrderedInsert", testReverseOrderedInsert),
//    ]
}
