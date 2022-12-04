//
//  ArchiveLoader.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 29/7/20.
//  Copyright © 2020 MasterBel2. All rights reserved.
//

import Foundation
import SpringRTSStartScriptHandling

#if os(macOS)
import Cocoa
#endif

// public protocol DescribesArchivesOnDisk {
// 	func reload()
// 	func load()

//     var url: URL { get }
	
// 	var engines: [Engine] { get }
// 	var modArchives: [QueueLocked<ModArchive>] { get }
// 	var mapArchives: [QueueLocked<MapArchive>] { get }
// 	var skirmishAIArchives: [QueueLocked<SkirmishAIArchive>] { get }
// }

/// A loader for Unitsync archives.
public final class UnitsyncArchiveLoader {

    /// Whether the archives have been loaded.
    private(set) var archivesAreLoaded = false
    private let system: System
    public let url: URL
    
    public init(url: URL, system: System) {
        self.system = system
        self.url = url
    }

	public func reload() {
		for engine in engines {
            engine.unitsyncWrapper.sync { $0.refresh() }
		}
        archivesAreLoaded = false
        load()
    }

	/// Attempts to auto-detect spring versions in common directories by attempting to initialise unitsync on their contents.
	public func autodetectSpringVersions() {
        // // this potentially breaks, for example, searching in the Applications folder on MacOS, so some nice alternative to this needs to be established.
        let engineFolderCandidates = try! FileManager.default.contentsOfDirectory(at: url.appendingPathComponent("engine"), includingPropertiesForKeys: [.isDirectoryKey])
        for candidate in engineFolderCandidates {
            do {
                let wrapper = try UnitsyncWrapper(springDirectory: candidate)
                let version = wrapper.springVersion
                engines.append(try Engine(
                    location: candidate,
                    version: version,
                    isReleaseVersion: wrapper.IsSpringReleaseVersion(),
                    system: system,
                    unitsyncWrapper: QueueLocked(lockedObject: wrapper, queue: DispatchQueue(label: "Unitsync Wrapper", qos: .userInteractive))
                ))
                print("Loaded engine candidate: \(candidate)")
            } catch {
                print("Failed to load candidate engine at: \(candidate): \(error)")
            }
        }
	}

    /// Retrieves the lists of archives from Unitsync.
	public func load() {
		guard !archivesAreLoaded else { return }
		
        autodetectSpringVersions()
        print("\(Date()): Loaded Engines!")

		guard let unitsyncWrapper = mostRecentUnitsync else { return }

        let minimapLoadQueue = DispatchQueue(label: "MinimapLoadQueue")
		
        mapArchives = (0..<unitsyncWrapper.sync { $0.GetMapCount()}).map({ index in
            return UnitsyncMapArchive.onSameQueue(
                as: unitsyncWrapper,
                args: UnitsyncMapArchive.Args(
                    name: String(cString: unitsyncWrapper.sync { $0.GetMapName(index) }), 
                    index: index, 
                    minimapLoadQueue: minimapLoadQueue
                )
            )
        })
        modArchives = (0..<unitsyncWrapper.sync { $0.GetPrimaryModCount() }).map({ index in
            return UnitsyncModArchive.onSameQueue(as: unitsyncWrapper, args: index)
        })
        skirmishAIArchives = (0..<unitsyncWrapper.sync { $0.GetSkirmishAICount() }).map({ index in
            return UnitsyncSkirmishAIArchive.onSameQueue(as: unitsyncWrapper, args: index)
        })
        archivesAreLoaded = true
    }

	public private(set) var engines: [Engine] = []
	public private(set) var modArchives: [QueueLocked<UnitsyncModArchive>] = []
	public private(set) var mapArchives: [QueueLocked<UnitsyncMapArchive>] = []
	public private(set) var skirmishAIArchives: [QueueLocked<UnitsyncSkirmishAIArchive>] = []
	
	private var mostRecentUnitsync: QueueLocked<UnitsyncWrapper>? {
		return engines.sorted(by: { $0.version > $1.version }).first?.unitsyncWrapper
	}
}