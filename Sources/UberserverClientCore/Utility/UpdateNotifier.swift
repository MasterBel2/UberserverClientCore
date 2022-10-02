//
//  UpdateNotifier.swift
//  
//
//  Created by MasterBel2 on 21/1/21.
//

import Foundation

public protocol Box {
	var wrappedAny: AnyObject { get}
}

/// Describes an object which updates other objects after it is updated.
public protocol UpdateNotifier: AnyObject {
	associatedtype UpdatableType: AnyObject & Box
	
    /// An array of blocks which return objects that must be updated when the UpdateNotifier is updated.
    ///
    /// Modify with `addObject(_:)` and `removeObject(_:)`
	var objectsWithLinkedActions: [UpdatableType] { get set }
}

public extension UpdateNotifier {
    /// Adds an object to be updated when the `UpdateNotifier` is updated. Added objects
    ///
    /// Attempting to add an object that does not conform to `UpdatableType` will trigger a crash.
	///
	/// The object will be stored with a weak reference, and automatically removed when it is destroyed.
	func addObject(_ object: UpdatableType) {
		objectsWithLinkedActions.append(object)
	}
    
    /// Removes a an object from the storage of objects to be updated.
	func removeObject(_ object: UpdatableType) {
		objectsWithLinkedActions.removeAll(where: { $0.wrappedAny === object.wrappedAny })
	}
    
    /// Calls the provided block on all stored updatable objects, removing any blocks from storage corresponding to objects that no longer exist.
	func applyActionToChainedObjects(_ action: (UpdatableType) -> ()) {
		// objectsWithLinkedActions = objectsWithLinkedActions.filter({ $0.object != nil })
		objectsWithLinkedActions.forEach(action)
	}
}
