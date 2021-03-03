//
//  DownloadInfo.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 7/12/19.
//  Copyright © 2019 MasterBel2. All rights reserved.
//

import Foundation

/// An encapsulation of information about a download operation.
public final class DownloadInfo {

    init(name: String, location: URL) {
        self.name = name
        self.location = location
    }

	/// The name of the download.
    public let name: String
	/// The location the download will be stored to.
    public let location: URL
	/// The date the download began.
    public let dateBegan = Date()
	/// The current state of the download.
	public internal(set) var state: State = .loading
    public internal(set) var progress: Int = 0
    public internal(set) var target: Int = 0
	
	/// Percent is an integer between 0 and 100 representing download progress, where 0 represents a pre-download state, and progress == target indicates an indeterminate download
	
	
	public enum State {
		/// The download is preparing.
		case loading
		/// The download is progressing
		case progressing
		/// The download is paused.
		case paused
		/// The download has failed.
		case failed
		/// The download has completed successfully.
		case completed
	}
}
