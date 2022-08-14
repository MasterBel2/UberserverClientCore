//
//  SpringArchiveInfo.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 21/11/19.
//  Copyright © 2019 MasterBel2. All rights reserved.
//

import Foundation
import FoundationNetworking

struct SpringArchiveInfo: Decodable {
    let category: String
    let description: String?
    let filename: String
    let mirrors: [URL]
    let md5: String
    let name: String
    let sdp: String
    let size: Int
    let springname: String
    let tags: [String]
    let timestamp: String
    let version: String
}

final class SpringArchiveDownloadTask: NSObject, Downloader, URLSessionDelegate, URLSessionDownloadDelegate {
    let archiveInfo: SpringArchiveInfo
    var urlDownloadTask: URLSessionDownloadTask?

    init(archiveInfo: SpringArchiveInfo, rootDirectory: URL) {
        self.archiveInfo = archiveInfo
        self.rootDirectory = rootDirectory
    }

    // MARK: - Directories

    private let rootDirectory: URL

    private var tempDirectory: URL {
        return rootDirectory.appendingPathComponent("temp", isDirectory: true)
    }

    var tempFileURL: URL {
        return tempDirectory.appendingPathComponent(archiveInfo.filename)
    }
    var targetURL: URL {
        return rootDirectory.appendingPathComponent(archiveInfo.filename)
    }

    // MARK: - Getting download progress information

    weak var delegate: DownloaderDelegate?
    var downloadName: String {
        return archiveInfo.name
    }

    // MARK: - Downloading

    var indexOfCurrentDownload = 0

    private(set) var paused = false

    func pauseDownload() {
        paused = true
        urlDownloadTask?.suspend()
    }

    func resumeDownload() {
        paused = false
        if let downloadTask = urlDownloadTask {
            downloadTask.resume()
        } else {
            attemptFileDownload(at: indexOfCurrentDownload)
        }
    }

    func attemptFileDownloads() {
        delegate?.downloaderDidBeginDownload(self)
        guard archiveInfo.mirrors.count > 0 else {
            delegate?.downloader(self, successfullyCompletedDownloadTo: [])
            return
        }
        attemptFileDownload(at: 0)
    }

    private func attemptFileDownload(at index: Int) {
        indexOfCurrentDownload = index
        let mirror = archiveInfo.mirrors[index]

        let urlSession = URLSession(configuration: .default, delegate: self, delegateQueue: nil)

        let downloadTask = urlSession.downloadTask(with: mirror)
        downloadTask.resume()
        self.urlDownloadTask = downloadTask
    }

    // MARK: - Finalising downloads

    func finalizeDownload(_ successful: Bool) {
        if successful {
            try? FileManager.default.moveItem(at: tempFileURL, to: targetURL)
        }
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    private func downloadsFailed(at index: Int, error: Error) {
        try? FileManager.default.removeItem(at: tempDirectory)
        if (index + 1) >= archiveInfo.mirrors.count {
            self.delegate?.downloader(self, downloadDidFailWithError: error)
        } else {
            attemptFileDownload(at: index + 1)
        }
    }

    private func successfullyDownloadedResource(named fileName: String, to location: URL) {

    }

    // MARK: - URLSessionDelegate

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        do {
            // Deleting last component from the URL allows path components to be included in the file name given to this function.
            try FileManager.default.createDirectory(atPath: tempDirectory.path, withIntermediateDirectories: true, attributes: nil)
            // Move item, else it will be deleted at the end of this function.
            try FileManager.default.moveItem(at: location, to: tempFileURL)
            delegate?.downloader(self, successfullyCompletedDownloadTo: [location])
        } catch {
            self.downloadsFailed(at: indexOfCurrentDownload, error: error)
        }
        urlDownloadTask = nil
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            downloadsFailed(at: indexOfCurrentDownload, error: error)
            urlDownloadTask = nil
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        delegate?.downloader(self, downloadHasProgressedTo: Int(totalBytesWritten), outOf: Int(totalBytesExpectedToWrite))
    }
}
