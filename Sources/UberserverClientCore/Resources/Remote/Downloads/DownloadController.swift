//
//  DownloadController.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 7/12/19.
//  Copyright © 2019 MasterBel2. All rights reserved.
//

import Foundation

/// A set of functions to be implemented by the download item view's delegate.
public protocol DownloadItemViewDelegate: AnyObject {
    /// Instructs the delegate to show the download in its directory.
    func showDownload(_ id: Int)
    /// Instructs the delegate to pause the download.
    func pauseDownload(_ id: Int)
    /// Instructs the delegate to resume the paused download.
    func resumeDownload(_ id: Int)
}

/// An object which controls information about current and previous download operations.
public final class DownloadController: DownloaderDelegate, DownloadItemViewDelegate {

	/// Downloaders associated with the items in the download list.
	///
	/// Since download ID is assigned from 0, increasing every time a downloader is added, the ID of a download is also the index of its downloader.
    var downloaders: [Downloader] = []
	/// The controller's list of download operations.
    public let downloadList = List<DownloadInfo>()
    private var nextID = 0

    private let system: System

    public init(system: System) {
        self.system = system
    }

	// MARK: - DownloaderDelegate

    public func downloaderDidBeginDownload(_ downloader: Downloader) {
        let downloadInfo = DownloadInfo(
            name: downloader.downloadName,
            location: downloader.targetURL
        )

        downloadList.addItem(downloadInfo, with: nextID)
        downloaders.append(downloader)
        nextID += 1
    }

    public func downloader(_ downloader: Downloader, downloadHasProgressedTo progress: Int, outOf total: Int) {
        guard let index = downloaders.enumerated().first(where: { $0.element === downloader })?.offset,
			let downloadItem = downloadList.items[index] else {
            return
        }
		
		if downloadItem.state != .paused {
			downloadItem.state = .progressing
		}
		downloadItem.state = .progressing
        downloadItem.progress = progress
        downloadItem.target = total
        downloadList.respondToUpdatesOnItem(identifiedBy: index)
    }

    public func downloader(_ downloader: Downloader, downloadDidFailWithError error: Error?) {
        guard let index = downloaders.enumerated().first(where: { $0.element === downloader })?.offset,
		let downloadItem = downloadList.items[index] else {
            return
        }
		downloadItem.state = .failed
        downloadList.respondToUpdatesOnItem(identifiedBy: index)
    }

    public func downloader(_ downloader: Downloader, successfullyCompletedDownloadTo tempUrls: [URL]) {
        guard let index = downloaders.enumerated().first(where: { $0.element === downloader })?.offset,
			let downloadItem = downloadList.items[index] else {
            return
        }
		downloadItem.state = .completed
        downloadList.respondToUpdatesOnItem(identifiedBy: index)
    }

    // MARK: - DownloadItemViewDelegate

    public func showDownload(_ id: Int) {
        let targetDirectory = downloaders[id].targetURL
        system.showFile(targetDirectory.lastPathComponent, at: targetDirectory.deletingLastPathComponent())
    }

    public func pauseDownload(_ id: Int) {
        downloaders[id].pauseDownload()
        downloadList.items[id]?.state = .paused
        downloadList.respondToUpdatesOnItem(identifiedBy: id)
    }

    public func resumeDownload(_ id: Int) {
        downloaders[id].resumeDownload()
        downloadList.items[id]?.state = .progressing
        downloadList.respondToUpdatesOnItem(identifiedBy: id)
    }
}
