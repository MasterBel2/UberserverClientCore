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
	
    private let remoteResourceFetcher: RemoteResourceFetcher

    private let queue = DispatchQueue(label: "com.believeandrise.resourcemanager")

	public init(downloadController: DownloadController, windowManager: WindowManager, archiveLoader: DescribesArchivesOnDisk) {
        remoteResourceFetcher = RemoteResourceFetcher(
			downloadController: downloadController,
			windowManager: windowManager
		)
		self.archiveLoader = archiveLoader
    }

    // MARK: - Controlling resources

    /// Loads engines, maps, then games.
    public func loadLocalResources() {
		archiveLoader.load()
    }

    /// Downloads a resource, and calls a completion handler with a boolean value indicating whether the download
    /// was successful, including verifying that unitsync can now identify the newly downloaded resource.
    public func download(_ resource: Resource, completionHandler: @escaping (Bool) -> Void) {
        remoteResourceFetcher.retrieve(resource, completionHandler: { [weak self] successful in
            guard let self = self else {
                return
            }
            if successful {
				self.queue.sync { self.archiveLoader.reload() }
                switch resource {
                case .engine(let (name, platform)):
                    fatalError()
                case .game(let name):
                    completionHandler(self.hasGame(name: name))
                case .map(let name):
                    // We only care about the name match here. Checksum can be checked where sync is important.
                    let hasMap = self.hasMap(named: name, checksum: 0, preferredVersion: "").hasNameMatch
                    completionHandler(hasMap)
                }
            } else {
                completionHandler(false)
            }
        })
    }

    // MARK: - Establishing sync

    /// 
    public func hasMap(named mapName: String, checksum: Int32, preferredVersion: String) -> (hasNameMatch: Bool, hasChecksumMatch: Bool, usedPreferredVersion: Bool) {
        let matches = archiveLoader.mapArchives.filter({ $0.name == mapName })
        return (
            hasNameMatch: matches.count > 0,
            hasChecksumMatch: matches.filter({ $0.checksum == checksum }).count == 1,
            usedPreferredVersion: true
        )
    }
	
//	public func loadMap(named mapName: String, checksum: Int32, preferredEngineVersion: String, downloadIfNecessary: Bool, completionHandler: (hasNameMatch: Bool, hasChecksumMatch: Bool, ))

    public func dimensions(forMapNamed name: String) -> (width: Int, height: Int)? {
		return queue.sync {
			guard let archive = archiveLoader.mapArchives.first(where: { $0.name == name }) else {
				return nil
			}
			return (archive.width, archive.height)
		}
    }

    /// Whether the lobby has located an engine with the specified version.
    public func hasEngine(version: String) -> Bool {
		return archiveLoader.engines.contains(where: { $0.syncVersion == version })
    }

    /// Whether unitsync can find a game with the matching name. The name string should include the game's version.
    public func hasGame(name: String) -> Bool {
        return archiveLoader.modArchives.contains(where: { $0.name == name })
    }

    // MARK: - Maps

    /// Loads a minimap of the given resolution. Calls the completion block for each mip level as it loads from the lowest to the highest. (This is to ensure the user sees visual feedback through the loading process.)
    public func loadMinimapData(forMapNamed mapName: String, mipLevels: Range<Int>, completionBlock: @escaping ((data: [UInt16], dimension: Int)?) -> Void) {
        // Proces the largest mipLevel (lowest resolution) to the smallest (greatest resolution).
        for mipLevel in mipLevels.reversed() {
            queue.async { [weak self] in
				// Retrieve array of dimension * dimension pixels that form the minimap for the given map, where dimension = 1024 / (2^mipLevel).
				let dimension = 1024 / Int(pow(2, Float(mipLevel)))
				guard let maybeData = self?.archiveLoader.mapArchives.first(where: { $0.name == mapName })?.miniMap.minimap(for: mipLevel),
					maybeData.count == dimension * dimension else {
					completionBlock(nil)
					return
				}

				completionBlock((maybeData, dimension))
            }
        }
    }
}
