//
//  UpdateNotifier.swift
//  
//
//  Created by MasterBel2 on 21/1/21.
//

import Foundation

public protocol UpdateNotifier: AnyObject {
	associatedtype UpdatableType
	
	var objectsWithLinkedActions: [() -> UpdatableType?] { get set }
}

public extension UpdateNotifier {
	func addObject<T: AnyObject>(object: T) {
		if object as? UpdatableType == nil { fatalError("Object does not conform to UpdatableType") }
		objectsWithLinkedActions.append({ [weak object] () -> UpdatableType? in
			return object as? UpdatableType
		})
	}
	func removeObject<T: AnyObject>(object: T) {
		objectsWithLinkedActions.removeAll(where: { $0() as? T === object })
	}
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
