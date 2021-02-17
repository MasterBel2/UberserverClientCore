//
//  Battle.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 24/6/19.
//  Copyright © 2019 MasterBel2. All rights reserved.
//

import Foundation

public protocol ReceivesBattleUpdates {
    
    // Map
    
    func mapDidUpdate(to map: Battle.MapIdentification)
    func loadedMapArchive(_ mapArchive: MapArchive, checksumMatch: Bool, usedPreferredEngineVersion: Bool)
    
    // Host
    
    func hostIsInGameChanged(to hostIsIngame: Bool)
}

public extension ReceivesBattleUpdates {
    func mapDidUpdate(to map: Battle.MapIdentification) {}
    func loadedMapArchive(_ mapArchive: MapArchive, checksumMatch: Bool, usedPreferredEngineVersion: Bool) {}
    
    func hostIsInGameChanged(to hostIsIngame: Bool) {}
}

public final class Battle: UpdateNotifier, Sortable {

    // MARK: - Properties
    
    public let userList: List<User>
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
        return userList.sortedItemCount - spectatorCount
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
    
    // MARK: - Sync

    /// Whether the client can verify the presence of the engine in the file system.
    public var hasEngine: Bool {
        return ResourceManager.default.hasEngine(version: engineVersion)
    }
    /// Whether the client can verify the presence of the game in the file system.
    public var hasGame: Bool {
        return ResourceManager.default.hasGame(name: gameName)
    }

    public var hasMap: Bool {
        return loadedMap != nil
    }

    /// Returns true if the client has verified all downloadable content (game, map, and engine).
    public var isSynced: Bool {
        return hasGame && hasMap && hasEngine
    }
    
    public var loadedMap: MapArchive?
    public var shouldAutomaticallyDownloadMap: Bool = false {
        didSet {
            if shouldAutomaticallyDownloadMap && !hasMap {
                loadMap()
            }
        }
    }
    
    /// Updates sync status, and loads minimap if the map is found.
    public func loadMap() {
        ResourceManager.default.loadMap(named: mapIdentification.name, checksum: mapIdentification.hash, preferredVersion: engineVersion, shouldDownload: shouldAutomaticallyDownloadMap) { [weak self] result in
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
    
    init(serverUserList: List<User>,
        isReplay: Bool, natType: NATType, founder: String, founderID: Int, ip: String, port: Int,
        maxPlayers: Int, hasPassword: Bool, rank: Int, mapHash: Int32, engineName: String,
        engineVersion: String, mapName: String, title: String, gameName: String, channel: String) {

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
		
		userList = List<User>(title: "", sortKey: .rank, parent: serverUserList)
		
        userList.addItemFromParent(id: founderID)
        
        loadMap()
    }
    
    // MARK: - UpdateNotifier
    
    public var objectsWithLinkedActions: [() -> ReceivesBattleUpdates?] = []
	
	// MARK: - Sortable
	
	public enum PropertyKey {
		case playerCount
	}
	
	public func relationTo(_ other: Battle, forSortKey sortKey: Battle.PropertyKey) -> ValueRelation {
		switch sortKey {
		case .playerCount:
			return ValueRelation(value1: self.playerCount, value2: other.playerCount)
		}
	}
    
    public enum NATType: Int {
        case none
        case holePunching
        case fixedSourcePorts
    }
}