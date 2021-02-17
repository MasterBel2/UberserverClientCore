//
//  UpdateNotifier.swift
//  
//
//  Created by MasterBel2 on 21/1/21.
//

import Foundation

/// Describes an object which updates other objects after it is updated.
public protocol UpdateNotifier: AnyObject {
	associatedtype UpdatableType
	
    /// An array of blocks which return objects that must be updated when the UpdateNotifier is updated.
    ///
    /// Modify with `addObject(_:)` and `removeObject(_:)`
	var objectsWithLinkedActions: [() -> UpdatableType?] { get set }
}

public extension UpdateNotifier {
    /// Adds an object to be updated when the `UpdateNotifier` is updated. Added objects
    ///
    /// Attempting to add an object that does not conform to `UpdatableType` will trigger a crash.
	func addObject<T: AnyObject>(_ object: T) {
		if object as? UpdatableType == nil { fatalError("Object does not conform to UpdatableType") }
		objectsWithLinkedActions.append({ [weak object] () -> UpdatableType? in
			return object as? UpdatableType
		})
	}
    
    /// Removes a an object from the storage of objects to be updated.
	func removeObject<T: AnyObject>(_ object: T) {
		objectsWithLinkedActions.removeAll(where: { $0() as? T === object })
	}
    
    /// Calls the provided block on all stored updatable objects, removing any blocks from storage corresponding to objects that no longer exist.
	func applyActionToChainedObjects(_ action: (UpdatableType) -> ()) {
		var updatedObjects: [() -> UpdatableType?] = []
		let targets = objectsWithLinkedActions.compactMap({ (function: @escaping () -> UpdatableType?) -> UpdatableType? in
			let temp = function()
			if temp != nil { updatedObjects.append(function) }
			return temp
		})
		objectsWithLinkedActions = updatedObjects
		targets.forEach(action)
	}
}
