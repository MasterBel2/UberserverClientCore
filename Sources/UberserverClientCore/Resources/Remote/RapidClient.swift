//
//  RapidClient.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 6/12/19.
//  Copyright © 2019 MasterBel2. All rights reserved.
//

import Foundation
import SWCompression

/**
 A downloader that retrieves resources from Rapid.
*/
final public class RapidClient: Downloader, DownloaderDelegate {

    // MARK: - Dependencies

	/// The rapid client's delegate.
    public weak var delegate: DownloaderDelegate?

    // MARK: - Local Directories

    let springDataDirectory: URL

    public init(dataDirectory: URL) {
        self.springDataDirectory = dataDirectory
    }

	/// The local root directory where downloads should be stored.
    private var cacheDirectory: URL {
        return springDataDirectory
    }

	/// The local directory in which rapid repository indexes are stored.
    private var repositoriesDirectory: URL {
        cacheDirectory.appendingPathComponent("rapid", isDirectory: true)
    }
	
	/// The full local URL for the repository's versions.gz file.
    private func versionsGZDirectory(forRepoNamed repoName: String) -> URL {
        return repositoriesDirectory.appendingPathComponent(repoName).appendingPathComponent("versions").appendingPathExtension("gz")
    }

	/// The local directory in which packate files are stored.
    private var packageDirectory: URL {
        return cacheDirectory.appendingPathComponent("packages", isDirectory: true)
    }

	/// The full local URL for the package.
    private func packageLocalURL(_ packageName: String) -> URL {
        return packageDirectory.appendingPathComponent(packageName).appendingPathExtension("sdp")
    }

	/// The local directory in which pool files are stored.
    private var poolDirectory: URL {
        return cacheDirectory.appendingPathComponent("pool", isDirectory: true)
    }

    // MARK: - Remote targets

	/// The remote root directory for Rapid.
    private static let rapidRemote = URL(string: "https://packages.springrts.com")!
	/// The full remote URL for the index of repositories.
    private static let repositoriesURL = rapidRemote.appendingPathComponent("repos").appendingPathExtension(".gz")

	/// The remote directory from which package files may be retrieved.
    private static let packagesRemote = rapidRemote.appendingPathComponent("packages", isDirectory: true)
	/// The remote directory from which pool files may be retrieved.
    private static let poolRemote = rapidRemote.appendingPathComponent("pool", isDirectory: true)

	/// The full remote URL for the package.
    private static func packageURL(_ packageName: String) -> URL {
        return packagesRemote.appendingPathComponent(packageName).appendingPathExtension("sdp")
    }

    // MARK: - Downloading a resource

    public private(set) var paused = false

    public func pauseDownload() {
        paused = true
        poolDownloader?.pauseDownload()
        packageDownloader?.pauseDownload()
    }

    public func resumeDownload() {
        paused = false
        packageDownloader?.resumeDownload()
        poolDownloader?.resumeDownload()
    }

    // Hold a reference so the completion of async downloading can be handled
    private var packageDownloader: ArrayDownloader?
    private var poolDownloader: ArrayDownloader?

	/// Attempts to download a resource with the given name from Rapid.
    public func download(_ name: String) {
		downloadName = name
		delegate?.downloaderDidBeginDownload(self)
        do {
            try downloadPackages(name)
        } catch {
            delegate?.downloader(self, downloadDidFailWithError: error)
        }
    }

	/// Searches local rapid cache for the resource, and downloads a .sdp file when a match is found.
    private func downloadPackages(_ name: String) throws {
        let repositoryIndexes = try FileManager.default.contentsOfDirectory(atPath: repositoriesDirectory.path)
        let indexCaches = repositoryIndexes.map(versionsGZDirectory(forRepoNamed:))
        let packages = indexCaches.compactMap({ sdpArchiveName(for: name, at: $0) })
		guard packages.count > 0 else {
			downloader(self, downloadDidFailWithError: nil)
			return
		}
        let packageDownloader = ArrayDownloader(
            resourceNames: packages,
            rootDirectory: packageDirectory,
            remoteURL: RapidClient.packagesRemote,
            pathExtension: "sdp",
            successCondition: .one
        )

        packageDownloader.delegate = self
        packageDownloader.attemptFileDownloads()
        if paused {
            packageDownloader.pauseDownload()
        }

        self.packageDownloader = packageDownloader
    }

    /// Parses a package and retrieves the resources it specifies.
    private func downloadResourceData(_ packageURL: URL) throws {
        guard let data = FileManager.default.contents(atPath: packageURL.path) else {
            Logger.log("Failed to retrieve data from downloaded file", tag: .GeneralError)
			delegate?.downloader(self, downloadDidFailWithError: nil)
            return
        }
        guard let unzippedData = try? GzipArchive.unarchive(archive: data) else {
            Logger.log("Failed to unzip file", tag: .GeneralError)
			delegate?.downloader(self, downloadDidFailWithError: nil)
            return
        }
        let resourceNames = try self.poolFiles(from: unzippedData).map({ (poolArchive: PoolArchive) -> String in
            let folderName = String(poolArchive.md5Digest.dropLast(30))
            let fileName = String(poolArchive.md5Digest.dropFirst(2))
            return "\(folderName)/\(fileName)"
        })
        let poolDownloader = ArrayDownloader(
            resourceNames: resourceNames,
            rootDirectory: poolDirectory,
            remoteURL: RapidClient.poolRemote,
            pathExtension: "gz",
            successCondition: .all
        )
        poolDownloader.delegate = self
        poolDownloader.attemptFileDownloads()
        if paused {
            poolDownloader.pauseDownload()
        }

        self.poolDownloader = poolDownloader
    }

    // MARK: - DownloaderDelegate

    public func downloaderDidBeginDownload(_ downloader: Downloader) {
        if downloader === packageDownloader {
            delegate?.downloaderDidBeginDownload(self)
        }
    }

    public func downloader(_ downloader: Downloader, downloadHasProgressedTo progress: Int, outOf total: Int) {
        if downloader === poolDownloader {
            delegate?.downloader(self, downloadHasProgressedTo: progress, outOf: total)
        }
    }

    public func downloader(_ downloader: Downloader, downloadDidFailWithError error: Error?) {
        delegate?.downloader(self, downloadDidFailWithError: error)
    }

    public func downloader(_ downloader: Downloader, successfullyCompletedDownloadTo tempUrls: [URL]) {
        if downloader === poolDownloader {
            delegate?.downloader(self, successfullyCompletedDownloadTo: tempUrls)
        } else {
            guard tempUrls.count == 1,
                let url = tempUrls.first else {
                    return
            }
            do {
                try downloadResourceData(url)
            } catch {
                Logger.log("[Rapid Client] download failed: \(error)", tag: .General)
                self.downloader(self, downloadDidFailWithError: error)
            }
        }
    }

    // MARK: - Downloader

    public private(set) var downloadName: String = ""
    public var targetURL: URL {
        return poolDirectory
    }

    public func finalizeDownload(_ successful: Bool) {
        if successful {
            self.poolDownloader?.finalizeDownload(successful)
            self.poolDownloader = nil
            self.packageDownloader?.finalizeDownload(successful)
            self.packageDownloader = nil
        }
		self.poolDownloader = nil
		self.packageDownloader = nil
    }

    // MARK: - Analysing data

    public enum PoolFileDecodeError: Error {
        case crc32
        case fileSize
        case fileName
    }

    private func poolFiles(from data: Data) throws -> [PoolArchive] {
        if let string = String(data: data, encoding: .utf8) {
            print(string)
        }
        var remainingData = data
        var archives: [PoolArchive] = []
        while remainingData.count >= 25 {
            let fileNameLength = Int(remainingData[0])
            let fileName: String
            if fileNameLength == 0 {
                fileName = ""
            } else {
                guard let decoded = String(data: remainingData[1...fileNameLength], encoding: .utf8) else { throw PoolFileDecodeError.fileName }
                fileName = decoded
            }
            let md5Digest = remainingData[(fileNameLength + 1)..<(fileNameLength + 17)].map({
                return $0 < 16 ? "0" + String($0, radix: 16) : String($0, radix: 16)
            }).joined()
            guard let crc32 = Int(data: remainingData[(fileNameLength + 5)..<(fileNameLength + 21)]) else { throw PoolFileDecodeError.crc32 }
            guard let fileSize = Int(data: remainingData[(fileNameLength + 9)..<(fileNameLength + 25)]) else { throw PoolFileDecodeError.fileSize }
            archives.append(PoolArchive(fileName: fileName, md5Digest: md5Digest, crc32: crc32, fileSize: fileSize))
            if remainingData.count > (25 + fileNameLength) {
                remainingData = remainingData.advanced(by: 25 + fileNameLength)
            } else {
                break
            }
        }
        return archives
    }

    private func sdpArchiveName(for resourceName: String, at url: URL) -> String? {
        guard let data = FileManager.default.contents(atPath: url.path) else {
            return nil
        }
        guard let unzippedData = try? GzipArchive.unarchive(archive: data) else {
            return nil
        }
        guard let stringValue = String(data: unzippedData, encoding: .utf8) else {
            return nil
        }
        let archives = resources(from: stringValue)
        guard let resource = archives.first(where: { $0.name == resourceName }) ?? archives.last(where: { "\($0.shortName):\($0.tag)" == resourceName }) else {
            return nil
        }
        return resource.sdpArchiveName
    }

    private func resources(from index: String) -> [RapidArchiveInfo] {
        var resources: [RapidArchiveInfo] = []
        index.enumerateLines(invoking: { (line, _) in
            let components = line.replacingOccurrences(of: ",", with: " , ").split(separator: ",").map({ $0.trimmingCharacters(in: [" "])})
            guard components.count == 4 else {
                return
            }
            let otherComponents = components[0].split(separator: ":")
            resources.append(RapidArchiveInfo(
                shortName: String(otherComponents[0]),
                tag: String(otherComponents[1]),
                version: otherComponents.count == 3 ? String(otherComponents[2]) : nil,
                sdpArchiveName: String(components[1]),
                mutator: components[2] == "" ? nil : String(components[2]),
                name: String(components[3])
            ))
        })
        return resources
    }

    // MARK: - Nested types

    private struct PoolArchive {
        let fileName: String
        let md5Digest: String
        let crc32: Int
        let fileSize: Int
    }
}
