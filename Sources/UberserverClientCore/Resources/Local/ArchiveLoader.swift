//
//  ArchiveLoader.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 29/7/20.
//  Copyright © 2020 MasterBel2. All rights reserved.
//

import Foundation
import SpringRTSStartScriptHandling

public protocol DescribesArchivesOnDisk {
	func reload()
	func load()
	
	var engines: [Engine] { get }
	var modArchives: [ModArchive] { get }
	var mapArchives: [MapArchive] { get }
	var skirmishAIArchives: [SkirmishAIArchive] { get }
}

/// A loader for Unitsync archives.
public final class UnitsyncArchiveLoader: DescribesArchivesOnDisk {

    /// Whether the archives have been loaded.
    private var archivesAreLoaded = false
    private let system: System
    
    public init(system: System) {
        self.system = system
    }

	public func reload() {
		for engine in engines {
            engine.unitsyncWrapper.sync { $0.refresh() }
		}
        archivesAreLoaded = false
        load()
    }
	
	/// Attempts to auto-detect spring versions in common directories by attempting to initialise unitsync on their contents.
	private func autodetectSpringVersions() {
		let fileManager = FileManager.default
		let allApplicationURLs =
			fileManager.urls(for: .allApplicationsDirectory, in: .localDomainMask)
				.reduce([], { (result, url) -> [URL] in
					let urls = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])
					return result + (urls ?? [])
				})
		for applicationURL in allApplicationURLs {
			let config = UnitsyncConfig(appURL: applicationURL)
			if let wrapper = UnitsyncWrapper(config: config) {
				let version = wrapper.springVersion
				engines.append(Engine(
                    location: applicationURL,
					version: version,
					isReleaseVersion: wrapper.IsSpringReleaseVersion(),
                    system: system,
                    unitsyncWrapper: QueueLocked(lockedObject: wrapper, queue: DispatchQueue(label: "Unitsync Wrapper", qos: .userInteractive))
					)
				)
			}
		}
		print("\(Date()): Loaded Engines!")
	}

    /// Retrieves the lists of archives from Unitsync.
	public func load() {
		guard !archivesAreLoaded else { return }
		autodetectSpringVersions()
		guard let unitsyncWrapper = mostRecentUnitsync else { return }
		
        mapArchives = (0..<unitsyncWrapper.sync { $0.GetMapCount()}).map({ index in
            return UnitsyncMapArchive(
                archiveIndex: index,
                archiveName: String(cString: unitsyncWrapper.sync { $0.GetMapName(index) }),
                unitsyncWrapper: unitsyncWrapper
            )
        })
        modArchives = (0..<unitsyncWrapper.sync { $0.GetPrimaryModCount() }).map({ index in
            return UnitsyncModArchive(
                archiveIndex: index,
                unitsyncWrapper: unitsyncWrapper
            )
        })
        skirmishAIArchives = (0..<unitsyncWrapper.sync { $0.GetSkirmishAICount() }).map({ index in
            return UnitsyncSkirmishAIArchive(
                archiveIndex: index,
                unitsyncWrapper: unitsyncWrapper
            )
        })
        archivesAreLoaded = true
    }

	public private(set) var engines: [Engine] = []
	public private(set) var modArchives: [ModArchive] = []
	public private(set) var mapArchives: [MapArchive] = []
	public private(set) var skirmishAIArchives: [SkirmishAIArchive] = []
	
	private var mostRecentUnitsync: QueueLocked<UnitsyncWrapper>? {
		return engines.sorted(by: { $0.version > $1.version }).first?.unitsyncWrapper
	}
}

public struct Engine {
    private let system: System
    
    init(location: URL, version: String, isReleaseVersion: Bool, system: System, unitsyncWrapper: QueueLocked<UnitsyncWrapper>) {
        self.system = system
        self.version = version
        self.isReleaseVersion = isReleaseVersion
        self.location = location
        self.unitsyncWrapper = unitsyncWrapper
    }
    
	public let version: String
	public let isReleaseVersion: Bool
    
    private var scriptFileURL: URL {
        return system.configDirectory.appendingPathComponent("script.txt")
    }

	/// Returns a string that may be used to determine if it will sync with another engine version. For a release version, this is the major
	/// and minor versions of the engine. For other versions, it is the entire version string.
	public var syncVersion: String {
		if !isReleaseVersion {
			return version
		}
		let versionComponents = version.components(separatedBy: ".") + ["0"]

		return versionComponents[0...1].joined(separator: ".")
	}

	public let location: URL
	let unitsyncWrapper: QueueLocked<UnitsyncWrapper>
    
    /// Launches spring.
    ///
    /// - parameter willRecordDemo: whether the script contains an isntruction to record a demo. If true, the replay controller will be instructed to reload replays after the game is done, to detect the new file.
    /// - parameter completionHandler: A function to be called when Spring closes or an error is thrown.
    public func launchGame(script: LaunchScriptConvertible, doRecordDemo: Bool, completionHandler: (() -> Void)?) throws {
        do {
            try script.launchScript(shouldRecordDemo: doRecordDemo).write(toFile: scriptFileURL.path, atomically: true, encoding: .utf8)
            system.launchApplication(at: location.path, with: [scriptFileURL.path], completionHandler: {
                completionHandler?()
//                if doRecordDemo {
//                    try? self?.replayController.loadReplays()
//                }
            })
        } catch {
            completionHandler?()
        }
    }
}
