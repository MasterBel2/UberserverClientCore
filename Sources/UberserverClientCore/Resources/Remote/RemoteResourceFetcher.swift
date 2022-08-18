//
//  SpringArchiveInfo.swift
//  ProjectPlayground
//
//  Created by MasterBel2 on 16/11/19.
//  Copyright © 2019 MasterBel2. All rights reserved.
//

import Foundation
import FoundationNetworking

/// A set of functions called by a `RemoteResourceFetcher` to allow updates in response to a change in its state.
public protocol ReceivesRemoteResourceFetcherUpdates {
    /// Indicates that a download task is about to commence.
    func remoteResourceFetcher(_ remoteResourceFetcher: RemoteResourceFetcher, willBeginDownloadOf resource: Resource)
}

// For downloading from rapid:
// 1. Ensure cached versions.gz are up-to-date
// 2. Locate resource in versions.gz
// 3. Identify versions to download (between latest version and current version)
// 4. Dowload versions and place files in the appropriate ~/.spring/pool/XX folder
// 5. Indicate download completion

// For downloading from torrent
// 1. Search https://api.springfiles.com/json.php?category=<category>&torrent=true&springname=<name>
// 2. Check dependencies are dowloaded
// 3. Download from mirror

public final class RemoteResourceFetcher: DownloaderDelegate, UpdateNotifier {

    // MARK: - Dependencies

    private let downloadController: DownloadController

    public var objectsWithLinkedActions: [() -> ReceivesRemoteResourceFetcherUpdates?] = []

    /// In-progress download task cache.
    private var tasks: [UUID : URLSessionDownloadTask] = [:]

	public init(downloadController: DownloadController) {
        self.downloadController = downloadController
    }

    // MARK: - Properties

    private var downloaders: [Downloader] = []
    private var completionHandler: ((Bool) -> Void)?

    // MARK: - Retrieving resources

    /// Attempts to retrieve a resource from either Rapid or the SpringFiles API. The completion handler calls true for successful
    /// download, and false for a faliure.
    public func retrieve(_ resource: Resource, dataDirectory: URL, completionHandler: @escaping (Bool) -> Void) {

        applyActionToChainedObjects({ $0.remoteResourceFetcher(self, willBeginDownloadOf: resource) })

        self.completionHandler = completionHandler
        switch resource {
        case .engine, .map:
            retrieveSpringFilesArchivedResource(resource, dataDirectory: dataDirectory)
        case .game(let name):
            let rapidClient = RapidClient(dataDirectory: dataDirectory)
            rapidClient.delegate = self
            rapidClient.download(name)
            downloaders.append(rapidClient)
        }
    }
	
	/// Downloads a single, complete resource from the SpringFiles API.
    private func retrieveSpringFilesArchivedResource(_ resource: Resource, dataDirectory: URL) {
        searchSpringFiles(for: resource, completionHandler: { results in
            guard let target = results?.first else {
                return
            }

            // 1. Check dependencies are downloaded
            #warning("Dependencies may not have been downloaded")

            // 2. For each mirror, one at a time until successful, attempt to download the file
            let downloader = SpringArchiveDownloadTask(archiveInfo: target, targetDirectory: dataDirectory.appendingPathComponent(resource.directory, isDirectory: true))

            downloader.delegate = self
            downloader.attemptFileDownloads()
            
            self.downloaders.append(downloader)
        })
    }

	/// Searches the SpringFiles API for a resource.
    private func searchSpringFiles(for resource: Resource, completionHandler: @escaping ([SpringArchiveInfo]?) -> Void) {
        guard let url = URL(string: "https://springfiles.springrts.com/json.php?category=\(resource.category)&torrent=true&springname=\(resource.name.replacingOccurrences(of: " ", with: "%20"))") else {
            return
        }
        let taskID = UUID()

        let downloadTask = URLSession.shared.downloadTask(with: url) { [weak self] (urlOrNil, responseOrNil, errorOrNil) in
            guard let self = self else {
                return
            }
            defer {
                self.tasks.removeValue(forKey: taskID)
            }
            guard let url = urlOrNil,
                let data = FileManager.default.contents(atPath: url.path) else {
                self.completionHandler?(false)
                return
            }
            let jsonDecoder = JSONDecoder()
            let results = try? jsonDecoder.decode([SpringArchiveInfo].self, from: data)

            completionHandler(results)
        }
        downloadTask.resume()
        tasks[taskID] = downloadTask
    }

    // MARK: - DownloaderDelegate

    public func downloaderDidBeginDownload(_ downloader: Downloader) {
        downloadController.downloaderDidBeginDownload(downloader)
    }

    public func downloader(_ downloader: Downloader, downloadHasProgressedTo progress: Int, outOf total: Int) {
        downloadController.downloader(downloader, downloadHasProgressedTo: progress, outOf: total)
    }

    public func downloader(_ downloader: Downloader, downloadDidFailWithError error: Error?) {
        print("Download failed!")
		downloader.finalizeDownload(false)
		if downloader is RapidClient {
			#warning("This makes assumptions about the use of RapidClient to only download games. A more robust system should be put in place for determining the resource to be downloaded.")
			retrieveSpringFilesArchivedResource(.game(name: downloader.downloadName), dataDirectory: downloader.targetURL.deletingLastPathComponent())
		} else {
			completionHandler?(false)
		}
		downloaders.removeAll(where: { $0 === downloader})
		downloadController.downloader(downloader, downloadDidFailWithError: error)
    }

    public func downloader(_ downloader: Downloader, successfullyCompletedDownloadTo tempUrls: [URL]) {
        print("Download completed!")
		downloader.finalizeDownload(true)
        completionHandler?(true)
        downloaders.removeAll(where: { $0 === downloader})

        downloadController.downloader(downloader, successfullyCompletedDownloadTo: tempUrls)
    }
}
