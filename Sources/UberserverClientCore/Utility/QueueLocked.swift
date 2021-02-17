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
    
    public func async(block: @escaping (LockedObject) -> Void) {
        queue.async {
            block(lockedObject)
        }
    }
    
    public func sync<ReturnType>(block: (LockedObject) -> ReturnType) -> ReturnType {
        return queue.sync {
            return block(lockedObject)
        }
    }
}
