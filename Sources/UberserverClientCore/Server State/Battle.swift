//
//  Battle.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 24/6/19.
//  Copyright © 2019 MasterBel2. All rights reserved.
//

import Foundation

public protocol BattleDelegate: AnyObject {
    func mapDidUpdate(to map: Battle.Map)
}

public final class Battle: Sortable {

    // MARK: - Dependencies

    public weak var delegate: BattleDelegate?

    // MARK: - Properties
    
    public let userList: List<User>
    public internal(set) var spectatorCount: Int = 0
    public var map: Map {
        didSet {
            if map != oldValue {
                delegate?.mapDidUpdate(to: map)
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
	
	// MARK: - Nested types
	
    public struct Map: Equatable {
		let name: String
		let hash: Int32
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
        self.map = Map(name: mapName, hash: mapHash)
        
        self.engineName = engineName
        self.engineVersion = engineVersion
        self.title = title
        self.gameName = gameName

        self.channel = channel
		
		userList = List<User>(title: "", sortKey: .rank, parent: serverUserList)
		
        userList.addItemFromParent(id: founderID)
    }
	
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
