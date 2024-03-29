//
//  Battle.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 24/6/19.
//  Copyright © 2019 MasterBel2. All rights reserved.
//

import Foundation
import ServerAddress

public protocol ReceivesBattleUpdates: AnyObject {
    
    // Map
    
    func mapDidUpdate(to map: Battle.MapIdentification)
    func loadedMapArchive(_ mapArchive: QueueLocked<UnitsyncMapArchive>, checksumMatch: Bool, usedPreferredEngineVersion: Bool)
    
    func loadedGameArchive(_ gameArchive: QueueLocked<UnitsyncModArchive>)
    func loadedEngine(_ engine: Engine)
    
    // Host
    
    func hostIsInGameChanged(to hostIsIngame: Bool)

    func asAnyReceivesBattleUpdates() -> AnyReceivesBattleUpdates
}

public extension ReceivesBattleUpdates {
    func mapDidUpdate(to map: Battle.MapIdentification) {}
    func loadedMapArchive(_ mapArchive: QueueLocked<UnitsyncMapArchive>, checksumMatch: Bool, usedPreferredEngineVersion: Bool) {}
    
    func loadedGameArchive(_ gameArchive: QueueLocked<UnitsyncModArchive>) {}
    func loadedEngine(_ engine: Engine) {}
    
    func hostIsInGameChanged(to hostIsIngame: Bool) {}

    func asAnyReceivesBattleUpdates() -> AnyReceivesBattleUpdates {
        return AnyReceivesBattleUpdates(wrapping: self)
    }
}

public final class AnyReceivesBattleUpdates: ReceivesBattleUpdates, Box {
    let wrapped: ReceivesBattleUpdates
    public var wrappedAny: AnyObject {
        return wrapped
    }

    public init(wrapping: ReceivesBattleUpdates) {
        self.wrapped = wrapping
    }

    public func mapDidUpdate(to map: Battle.MapIdentification) {
        wrapped.mapDidUpdate(to: map)
    }

    public func loadedMapArchive(_ mapArchive: QueueLocked<UnitsyncMapArchive>, checksumMatch: Bool, usedPreferredEngineVersion: Bool) {
        wrapped.loadedMapArchive(mapArchive, checksumMatch: checksumMatch, usedPreferredEngineVersion: usedPreferredEngineVersion)
    }

    public func loadedGameArchive(_ gameArchive: QueueLocked<UnitsyncModArchive>) {
        wrapped.loadedGameArchive(gameArchive)
    }

    public func loadedEngine(_ engine: Engine) {
        wrapped.loadedEngine(engine)
    }

    public func hostIsInGameChanged(to hostIsIngame: Bool) {
        wrapped.hostIsInGameChanged(to: hostIsIngame)
    }

    public func asAnyReceivesBattleUpdates() -> AnyReceivesBattleUpdates {
        return self
    }
}

public final class Battle: UpdateNotifier {
    
    // MARK: - Dependencies
    
    let resourceManager: ResourceManager

    // MARK: - Server State
    
    public let userList: ManualSublist<User>
    public internal(set) var spectatorCount: Int = 0
    public var mapIdentification: MapIdentification {
        didSet {
            if mapIdentification != oldValue {
                loadedMap = nil
                applyActionToChainedObjects({ $0.mapDidUpdate(to: mapIdentification)})
                loadMap()
            }
        }
    }

    public var playerCount: Int {
        return userList.items.count - spectatorCount
	}
	
    public let title: String
    public let isReplay: Bool
    public let channel: String
	
    public let gameName: String
    public let engineName: String
	public let engineVersion: String
	
	public let maxPlayers: Int
	public let hasPassword: Bool
	public internal(set) var isLocked: Bool = false
	public let rank: Int
	
    public let founder: String
	public let founderID: Int
	public let port: Int
	public let ip: String
	public let natType: NATType
    
    // MARK: - Identity
    
    public let myScriptPassword: String
    
    // MARK: - Local State

    /// Indicates whether `engine` has a value.
    public var hasEngine: Bool {
        return engine != nil
    }
    /// Indicates whether `gameArchive` has a value.
    public var hasGame: Bool {
        return gameArchive != nil
    }
    /// Indicates whether `loadedMap` has a value.
    public var hasMap: Bool {
        return loadedMap != nil
    }

    /// An amalgam of `hasEngine`, `hasGame`, and `hasMap`.
    public var isSynced: Bool {
        return hasGame && hasMap && hasEngine
    }
    
    public private(set) var gameArchive: QueueLocked<UnitsyncModArchive>?
    public private(set) var engine: Engine?
    public private(set) var loadedMap: QueueLocked<UnitsyncMapArchive>?
    
    public var shouldAutomaticallyDownloadMap: Bool = false {
        didSet {
            if shouldAutomaticallyDownloadMap && !hasMap {
                loadMap()
            }
        }
    }
    
    public func loadEngine() {
        engine = resourceManager.archiveLoader.engines.first(where: { $0.syncVersion == engineVersion })
        if let engine = engine {
            applyActionToChainedObjects({ $0.loadedEngine(engine) })
        }
    }

    public func loadGame() {
        gameArchive = resourceManager.archiveLoader.modArchives.first(where: { $0.sync { $0.name } == gameName })
        if let gameArchive = gameArchive {
            applyActionToChainedObjects({ $0.loadedGameArchive(gameArchive) })
        }
    }
    
    /// Attempts to load the map archive.
    public func loadMap() {
        resourceManager.loadMap(named: mapIdentification.name, checksum: mapIdentification.hash, preferredVersion: engineVersion, shouldDownload: shouldAutomaticallyDownloadMap) { [weak self] result in
            guard let self = self else {
                return
            }
            switch result {
            case .success(let (mapArchive, checksumMatch, usedPreferredEngineVersion)):
                if !checksumMatch {
                    Logger.log("Warning: Map checksums do not match.", tag: .General)
                }
                
                self.loadedMap = mapArchive
                self.applyActionToChainedObjects({ $0.loadedMapArchive(mapArchive, checksumMatch: checksumMatch, usedPreferredEngineVersion: usedPreferredEngineVersion)})
            case .failure(let error):
                self.loadedMap = nil
                Logger.log("Unsuccessful download of map \(self.mapIdentification.name)", tag: .General)
            }
        }
    }
	
	// MARK: - Nested types
	
    public struct MapIdentification: Equatable {
		public let name: String
		public let hash: Int32
	}
	
	// MARK: - Lifecycle
    
    public init(serverUserList: List<User>,
        isReplay: Bool, natType: NATType, founder: String, founderID: Int, ip: String, port: Int,
        maxPlayers: Int, hasPassword: Bool, rank: Int, mapHash: Int32, engineName: String,
        engineVersion: String, mapName: String, title: String, gameName: String, channel: String, scriptPasswordCacheDirectory: URL, resourceManager: ResourceManager) {
        
        // Setup

        self.isReplay = isReplay
        self.natType = natType
        self.founder = founder
        self.founderID = founderID
        self.ip = ip
        self.port = port
        self.maxPlayers = maxPlayers
        self.hasPassword = hasPassword
        self.rank = rank
        self.mapIdentification = MapIdentification(name: mapName, hash: mapHash)
        
        self.engineName = engineName
        self.engineVersion = engineVersion
        self.title = title
        self.gameName = gameName

        self.channel = channel
        
        self.resourceManager = resourceManager
		
        userList = ManualSublist<User>(parent: serverUserList)
        
        myScriptPassword = {
            let directory = scriptPasswordCacheDirectory.appendingPathComponent(String(founderID))
            do {
                return try String(contentsOf: directory)
            } catch {
                let password = UUID().uuidString
                try? password.write(toFile: directory.path, atomically: false, encoding: .utf8)
                return password
            }
        }()

        userList.addItemFromParent(id: founderID)
        
        // Additional Setup
        
        loadEngine()
        loadGame()
        loadMap()
    }

    public enum NATType: Int {
        case none
        case holePunching
        case fixedSourcePorts
    }
    
    // MARK: - UpdateNotifier
    
    public var objectsWithLinkedActions: [AnyReceivesBattleUpdates] = []
}
