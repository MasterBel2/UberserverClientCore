//
//  QueueLocked.swift
//  UberserverClientCore
//
//  Created by MasterBel2 on 18/2/21.
//

import Foundation

/// Locks an object in an interface that forces it to be interacted with on a single thread.
public struct QueueLocked<LockedObject> {

    public init(lockedObject: LockedObject, queue: DispatchQueue) {
        self.lockedObject = lockedObject
        self.queue = queue
    }
    
    private let lockedObject: LockedObject
    private let queue: DispatchQueue
    
    public func sync<ReturnType>(block: (LockedObject) -> ReturnType) -> ReturnType {
        return queue.sync {
            return block(lockedObject)
        }
    }

    func asyncAfter(deadline: DispatchTime, qos: DispatchQoS, execute block: @escaping (LockedObject) -> Void) -> DispatchWorkItem {
        let workItem = DispatchWorkItem(qos: qos, flags: .enforceQoS, block: {
            block(lockedObject)
        })
        queue.asyncAfter(deadline: deadline, execute: workItem)
        return workItem
    }

    func async(block: @escaping (LockedObject) -> Void) {
        queue.async {
            block(lockedObject)
        }
    }
}

/// Provides weak capture for reference types on async calls.
public extension QueueLocked where LockedObject: AnyObject {
    func asyncAfter(deadline: DispatchTime, qos: DispatchQoS, execute block: @escaping (LockedObject) -> Void) -> DispatchWorkItem {
        let workItem = DispatchWorkItem(qos: qos, flags: .enforceQoS, block: { [weak lockedObject] in
            guard let lockedObject = lockedObject else { return }
            block(lockedObject)
        })
        queue.asyncAfter(deadline: deadline, execute: workItem)
        return workItem
    }

    func async(block: @escaping (LockedObject) -> Void) {
        queue.async { [weak lockedObject] in
            guard let lockedObject = lockedObject else { return }
            block(lockedObject)
        }
    }
}
