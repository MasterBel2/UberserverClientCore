//
//  Timer.swift
//  
//
//  Created by MasterBel2 on 8/3/21.
//

import Foundation

/// Records a start time, and provides the interval since this time.
struct Timer {
    /// The creation time of this timer, in microseconds.
    let start = clock()
    /// The interval since the start of the timer, in microseconds.
    var intervalFromStart: Int {
        return Int(clock() - start)
    }
}
