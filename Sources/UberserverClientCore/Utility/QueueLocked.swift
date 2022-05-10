//
//  QueueLocked.swift
//  UberserverClientCore
//
//  Created by MasterBel2 on 18/2/21.
//

import Foundation

public class WeakOwned<OwnedObject: AnyObject> {
    weak public private(set) var object: OwnedObject?

    public init(_ object: OwnedObject) {
        self.object = object
    }
}

public typealias UnownedQueueLocked<T: AnyObject> = QueueLocked<WeakOwned<T>>

public func MakeUnownedQueueLocked<LockedObject: AnyObject>(lockedObject: LockedObject, queue: DispatchQueue) -> QueueLocked<WeakOwned<LockedObject>> {
    return QueueLocked(
        lockedObject: WeakOwned(lockedObject),
        queue: queue
    )
}

/// Locks an object in an interface that forces it to be interacted with on a single thread.
public struct QueueLocked<LockedObject> {

    public init(lockedObject: LockedObject, queue: DispatchQueue) {
        self.lockedObject = lockedObject
        self.queue = queue
    }
    
    private let lockedObject: LockedObject
    public let queue: DispatchQueue
    
    public func sync<ReturnType>(block: (LockedObject) -> ReturnType) -> ReturnType {
        return queue.sync {
            return block(lockedObject)
        }
    }

    public func asyncAfter(deadline: DispatchTime, qos: DispatchQoS, execute block: @escaping (LockedObject) -> Void) -> DispatchWorkItem {
        let workItem = DispatchWorkItem(qos: qos, flags: .enforceQoS, block: {
            block(lockedObject)
        })
        queue.asyncAfter(deadline: deadline, execute: workItem)
        return workItem
    }

    public func async(block: @escaping (LockedObject) -> Void) {
        queue.async {
            block(lockedObject)
        }
    }
}

/// Provides weak capture for reference types on async calls.
public extension QueueLocked where LockedObject: AnyObject {
    public func asyncAfter(deadline: DispatchTime, qos: DispatchQoS, execute block: @escaping (LockedObject) -> Void) -> DispatchWorkItem {
        let workItem = DispatchWorkItem(qos: qos, flags: .enforceQoS, block: { [weak lockedObject] in
            guard let lockedObject = lockedObject else { return }
            block(lockedObject)
        })
        queue.asyncAfter(deadline: deadline, execute: workItem)
        return workItem
    }

    public func async(block: @escaping (LockedObject) -> Void) {
        queue.async { [weak lockedObject] in
            guard let lockedObject = lockedObject else { return }
            block(lockedObject)
        }
    }
}
