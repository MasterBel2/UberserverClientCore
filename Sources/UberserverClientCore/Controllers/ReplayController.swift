//
//  ReplayController.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 28/7/20.
//  Copyright © 2020 MasterBel2. All rights reserved.
//

import Foundation
import SpringRTSReplayHandling
import SWCompression
import CoreFoundation

/// Handles loading of replays from the file system.
public final class ReplayController {

    /**
     - Parameter dataDirectory: Maps to the replays from a given data directory - e.g. given `~/.config/spring`, we'll look in  `~/.config/spring/demos`.
     */
    public init(dataDirectory: URL) {
        demoDir = dataDirectory.appendingPathComponent("demos", isDirectory: true)
    }

    /**
     - Parameter demoDir: the directory directly enclosing replays - e.g. given `~/.config/spring/demos`, we'll expect demo files such as `~/.config/spring/demos/example.sdfz`.
     */ 
    public init(demoDir: URL) {
        self.demoDir = demoDir
    }

    let demoDir: URL

    public let replays = List<Replay>()

    let fileManager =  FileManager.default
    let loadQueue = DispatchQueue(label: "com.believeandrise.replaycontroller.load", qos: .background)
    let updateQueue = DispatchQueue(label: "com.believeandrise.replaycontroller.update", qos: .userInteractive)

    /// Asynchronously loads replays from disk.
    public func loadReplays() throws {
        let urls = try fileManager.contentsOfDirectory(at: demoDir, includingPropertiesForKeys: nil)
        for replayURL in urls {
            if replays.items.contains(where: {$0.value.fileURL == replayURL }) { continue }
            loadQueue.async { [weak self] in
                do {
                    if let self = self,
                       let compressedData = self.fileManager.contents(atPath: replayURL.path) {
                        let data = try GzipArchive.unarchive(archive: compressedData)
                        let replay = try Replay(data: data, fileURL: replayURL)
                        // Concurrently updating the list is a sure fire way to corrupt it. So we'll
                        self.updateQueue.async { [weak self] in
                            self?.replays.addItem(replay, with: Int.random(in: Int.min...Int.max))
                        }
                    }
                } catch {
                    print(error)
                }
            }
        }
    }
}
