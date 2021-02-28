//
//  ResourceManager.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 14/11/19.
//  Copyright © 2019 MasterBel2. All rights reserved.
//

import Foundation

public final class ResourceManager {

	/// Provides access to engine-related archives, such as mods, etc.
	public let archiveLoader: DescribesArchivesOnDisk
    public let replayController: ReplayController
    private let remoteResourceFetcher: RemoteResourceFetcher

    private let queue = DispatchQueue(label: "com.believeandrise.resourcemanager")
    
    // MARK: - Creating a Resource Manager

    public init(replayController: ReplayController, remoteResourceFetcher: RemoteResourceFetcher, archiveLoader: DescribesArchivesOnDisk) {
        self.remoteResourceFetcher = remoteResourceFetcher
		self.archiveLoader = archiveLoader
        self.replayController = replayController
    }

    // MARK: - Controlling resources

    /// Begins an asynchronous load of all data on disk, beginning with sync-necessary items (such as engines, games, and maps.)
    public func loadLocalResources() {
		archiveLoader.load()
        try? replayController.loadReplays()
    }
    
    public func loadEngine(version: String, shouldDownload: Bool, completionHandler: @escaping (Result<Engine, Error>) -> Void) {
        let matches = archiveLoader.engines.filter({ $0.syncVersion == version})
        if let match = matches.first {
            completionHandler(.success(match))
        } else if shouldDownload {
            remoteResourceFetcher.retrieve(.engine(name: version, platform: Platform.current)) { [weak self] successful in
                guard let self = self else { return }
                if successful {
                    self.queue.sync {
                        self.archiveLoader.reload()
                        self.loadEngine(version: version, shouldDownload: false, completionHandler: completionHandler)
                    }
                }
            }
        }
    }
    
    public typealias GameLoadResult = Result<(ModArchive, Bool), Error>
    public func loadGame(named gameName: String, preferredEngineVersion: Bool, shouldDownload: Bool, completionHandler: @escaping (GameLoadResult) -> Void) {
        let matches = archiveLoader.modArchives.filter({ $0.name == gameName })
        if let match = matches.first {
            completionHandler(.success((match, false)))
        } else if shouldDownload {
            remoteResourceFetcher.retrieve(.game(name: gameName)) { [weak self] successful in
                guard let self = self else { return }
                if successful {
                    self.queue.sync {
                        self.archiveLoader.reload()
                        self.loadGame(named: gameName, preferredEngineVersion: preferredEngineVersion, shouldDownload: false, completionHandler: completionHandler)
                    }
                }
            }
        }
    }
    
    public func loadEngine(version: String, completionHandler: (Result<Engine, Error>) -> Void) {
        
    }
    
    
    public typealias MapLoadResult = Result<(mapArchive: MapArchive, checksumMatch: Bool, usedPreferredEngineVersion: Bool), Error>
    public func loadMap(named mapName: String, checksum: Int32, preferredVersion: String, shouldDownload: Bool, completionHandler: @escaping (MapLoadResult) -> Void) {
        let matches = archiveLoader.mapArchives.filter({ $0.name == mapName })
        if let match = matches.first {
            completionHandler(.success((match, match.singleArchiveChecksum == checksum, false)))
        } else if shouldDownload {
            remoteResourceFetcher.retrieve(.map(name: mapName)) { [weak self] successful in
                guard let self = self else {
                    return
                }
                if successful {
                    self.queue.sync {
                        self.archiveLoader.reload()
                        self.loadMap(named: mapName, checksum: checksum, preferredVersion: preferredVersion, shouldDownload: false, completionHandler: completionHandler)
                    }
                }
            }
        }
    }

    // MARK: - Establishing sync

    /// Whether the lobby has located an engine with the specified version.
    public func hasEngine(version: String) -> Bool {
		return archiveLoader.engines.contains(where: { $0.syncVersion == version })
    }

    /// Whether unitsync can find a game with the matching name. The name string should include the game's version.
    public func hasGame(name: String) -> Bool {
        return archiveLoader.modArchives.contains(where: { $0.name == name })
    }
}
