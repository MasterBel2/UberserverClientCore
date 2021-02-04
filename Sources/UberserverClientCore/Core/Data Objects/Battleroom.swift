//
//  Battleroom.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 24/6/19.
//  Copyright © 2019 MasterBel2. All rights reserved.
//

import Foundation

// MARK: - Protocols

public protocol BattleroomMapInfoDisplay: AnyObject {
    func displayMapName(_ mapName: String)
//    func addCustomisedMapOption(_ option: String, value: UnitsyncWrapper.InfoValue)
    func removeCustomisedMapOption(_ option: String)
}

public protocol BattleroomGameInfoDisplay: AnyObject {
//    func addCustomisedGameOption(_ option: String, value: UnitsyncWrapper.InfoValue)
    func removeCustomisedGameOption(_ option: String)
}

public protocol BattleroomDisplay: AnyObject {
    /// Notifies the display of the host's and user's updated in-game states.
    func display(isHostIngame: Bool, isPlayerIngame: Bool)
    /// Notifiies the display that a new team was added.
    func addedTeam(named teamName: String)
    /// Notifies the display that a team was removed.
    func removedTeam(named teamName: String)
    /// Notifies the display that an updated sync status should be displayed.
    func displaySyncStatus(_ isSynced: Bool)
	/// Notifies the display that an updated ready state should be displayed.
	func displayReadySate(_ isReady: Bool)
}

public protocol MinimapDisplay: AnyObject {
    /// Draws a start rect overlay on the minimap for the specified allyteam.
    func addStartRect(_ rect: StartRect, for allyTeam: Int)
    /// Removes the start rect coresponding to the specified ally team.
    func removeStartRect(for allyTeam: Int)
    /// Removes all start rects that have been displayed.
    func removeAllStartRects()

    /// Displays an image in place of the map, indicating the minimap cannot be loaded for the specified map (likely because the map
    /// has not yet been downloaded).
    func displayMapUnknown()

    /// Prepares the view with the given map dimensions. Must be set before `displayMapImage(for:dimension:)` is called.
    func setMapDimensions(_ width: Int, _ height: Int)
    /// Displays a minimap with the given image dimension. Must be called after  `setMapDimensions(_:_:)`.
    func displayMapImage(for imageData: [RGB565Color], dimension: Int)
}

public final class Battleroom: BattleDelegate, ListDelegate {

    // MARK: - Data

    /// The battleroom's associated battle.
    public let battle: Battle
    /// The battleroom's associated channel.
    public let channel: Channel

    public let allyTeamLists: [List<User>]
    public let spectatorList: List<User>
    var bots: [Bot] = []

    private(set) var startRects: [Int : StartRect] = [:]

    /// Indexed by ID.
	/// Updated by CLIENTBATTLESTATUS command.
	public internal(set) var userStatuses: [Int : UserStatus] = [:]
    /// Updated by CLIENTBATTLESTATUS command.
    /// Indexed by ID.
    public internal(set) var colors: [Int : Int32] = [:]
	/// Updated by SETSCRIPTTAGS command.
    public internal(set) var trueSkills: [Int : String] = [:]
    /// Updated by SETSCRIPTTAGS command.
    public internal(set) var modOptions: [String : String] = [:]
	/// Computed by the host's unitsync using the current map, game, and other dependencies.
	/// It is used to check that the client has correct non-corrupt downloads of the required content.
    public internal(set) var disabledUnits: [String] = []

    /// A hash code taken from the map, game, and engine. Calculated by Unitsync.
    public private(set) var hashCode: Int32

    public private(set) var allyNamesForAllyNumbers: [Int : String] = [:]

    // MARK: - Sync

    /// Whether the client can verify the presence of the engine in the file system.
    var hasEngine: Bool {
        return resourceManager.hasEngine(version: battle.engineVersion)
    }
    /// Whether the client can verify the presence of the game in the file system.
    var hasGame: Bool {
        return resourceManager.hasGame(name: battle.gameName)
    }

    /// Whether the client can verify the presence of the map in the file system.
    ///
    /// Updates sync status on change.
    private(set) var hasMap: Bool = false {
        didSet {
            #warning("This should be ")
            updateSync()
        }
    }

    /// Returns true if the client has verified all downloadable content (game, map, and engine).
    var isSynced: Bool {
        return hasGame && hasMap && hasEngine
    }

    // MARK: - Dependencies

    let resourceManager: ResourceManager
    private unowned let battleController: BattleController

    // MARK: - Displays

    public weak var allyTeamListDisplay: ListDisplay? {
        didSet {
            if let allyTeamListDisplay = allyTeamListDisplay {
                allyTeamLists.forEach(allyTeamListDisplay.addSection(_:))
            }
        }
    }

    public weak var spectatorListDisplay: ListDisplay? {
        didSet {
            spectatorListDisplay?.addSection(spectatorList)
        }
    }

    public weak var minimapDisplay: MinimapDisplay?
    public weak var mapInfoDisplay: BattleroomMapInfoDisplay?
    public weak var gameInfoDisplay: BattleroomGameInfoDisplay?
    public weak var generalDisplay: BattleroomDisplay?

    // MARK: - Player information

    let myID: Int

    public var myBattleStatus: Battleroom.UserStatus {
        return userStatuses[myID] ?? UserStatus(
            isReady: false,
            teamNumber: 0,
            allyNumber: 0,
            isSpectator: false,
            handicap: 0,
            syncStatus: isSynced ? .synced : .unsynced,
            side: 0
        )
    }

    var myColor: Int32 {
        return colors[myID] ?? Int32(myID.hashValue & 0x00FFFFFF)
    }
    /// Whether the player is ingame.
    private var isPlayerIngame: Bool {
        return battle.userList.items[myID]?.status.isIngame ?? false
    }

    /// Whether the host is ingame.
    private var isHostIngame: Bool {
        return battle.userList.items[battle.founderID]?.status.isIngame ?? false
    }

    public func trueSkill(for id: Int) -> Float? {
        guard let string = trueSkills[id] else { return nil }
        return Float(string.filter({ $0.isNumber || $0 == "." }))
    }

    // MARK: - Lifecycle

    init(battle: Battle, channel: Channel, hashCode: Int32, resourceManager: ResourceManager, battleController: BattleController, myID: Int) {
        self.battle = battle
        self.hashCode = hashCode
        self.channel = channel

        self.resourceManager = resourceManager
        self.myID = myID

        self.battleController = battleController

        let battleroomSorter = BattleroomPlayerListSorter()

        // + 1 – Users will count from 1, not from 0
        allyTeamLists = (0...15).map({ List(title: "Ally \(String($0 + 1))", sorter: battleroomSorter, parent: battle.userList) })
        spectatorList = List<User>(title: "Spectators", sorter: battleroomSorter, parent: battle.userList)

        battleroomSorter.battleroom = self
        battle.delegate = self
		battle.userList.addObject(object: self)

        if !hasEngine {
            resourceManager.download(.engine(name: battle.engineVersion, platform: platform), completionHandler: { [weak self] _ in
                self?.updateSync()
            })
        }
        if !hasGame {
            resourceManager.download(.game(name: battle.gameName), completionHandler: { [weak self] _ in
                self?.updateSync()
            })
        }
    }

    // MARK: - Updates

    #warning("Seriously?")
    public func displayIngameStatus() {
        generalDisplay?.display(isHostIngame: isHostIngame, isPlayerIngame: isPlayerIngame)
    }

    /// Updates the status for a user, as specified by their ID.
    func updateUserStatus(_ newUserStatus: UserStatus, forUserIdentifiedBy userID: Int) {
        // Ally/spectator
        let previousUserStatus = userStatuses[userID]
        Logger.log("Updating user status for \(userID): \(previousUserStatus?.description ?? "nil") -> \(newUserStatus.description)", tag: .BattleStatusUpdate)
        let value = (previous: previousUserStatus?.isSpectator, new: newUserStatus.isSpectator)
        // Only ally/spectator if the user's status has changed.
        if !(value == (previous: true, new: true) ||
            (value == (previous: false, new: false) && previousUserStatus?.allyNumber == newUserStatus.allyNumber)) {
            if value.previous == true {
                // The user is no longer a spectator.
                spectatorList.removeItem(withID: userID)
            } else if let previousAllyNumber = previousUserStatus?.allyNumber {
                // The user is no longer a player on an allyteam.
                let allyTeamList = allyTeamLists[previousAllyNumber]
                allyTeamList.removeItem(withID: userID)
                if allyTeamList.sortedItemCount == 0,
                    let allyName = allyNamesForAllyNumbers[previousAllyNumber] {
                    generalDisplay?.removedTeam(named: allyName)
                    allyNamesForAllyNumbers.removeValue(forKey: previousAllyNumber)
                }
            }
            if value.new {
                // The user is becoming a spectator.
                spectatorList.addItemFromParent(id: userID)
            } else {
                // The user has changed to an ally team – I.e. joined a new ally.
                let allyTeamList = allyTeamLists[newUserStatus.allyNumber]
                allyTeamList.addItemFromParent(id: userID)
                if allyTeamList.sortedItemCount == 1 {
                    let allyName = String(newUserStatus.allyNumber + 1)
                    allyNamesForAllyNumbers[newUserStatus.allyNumber] = allyName
                    generalDisplay?.addedTeam(named: allyName)
                }
            }
        }

        // Update the data
        userStatuses[userID] = newUserStatus

        if previousUserStatus?.allyNumber != newUserStatus.allyNumber {
            if userID == myID {
                allyTeamLists.forEach({ allyTeamList in
                    allyTeamList.sortedItemsByID.forEach({
                        allyTeamList.respondToUpdatesOnItem(identifiedBy: $0)
                    })
                })
                allyTeamLists.reduce([], { $0 + $1.sortedItemsByID }).forEach({ id in
                    channel.messageList.items.filter({ (key, value) in value.senderID == id })
                        .forEach({
                            channel.messageList.respondToUpdatesOnItem(identifiedBy: $0.key)
                        })
                })
            } else {
                channel.messageList.items.filter({ (key, value) in value.senderID == userID })
                    .forEach({ channel.messageList.respondToUpdatesOnItem(identifiedBy: $0.key) })
            }
        }

        if userID == myID {
			generalDisplay?.displayReadySate(newUserStatus.isReady)
		}

        // Update the view
        battle.userList.respondToUpdatesOnItem(identifiedBy: userID)
    }

    /// Adds a start rect.
    func addStartRect(_ rect: StartRect, for allyTeam: Int) {
        startRects[allyTeam] = rect
        minimapDisplay?.addStartRect(rect, for: allyTeam)
    }

    /// Removes a start rect.
    func removeStartRect(for allyTeam: Int) {
        startRects.removeValue(forKey: allyTeam)
        minimapDisplay?.removeStartRect(for: allyTeam)
    }

    /// Updates the sync status for the user and the server.
    private func updateSync() {
        battleController.setBattleStatus(Battleroom.UserStatus(
            isReady: myBattleStatus.isReady,
            teamNumber: myBattleStatus.teamNumber,
            allyNumber: myBattleStatus.allyNumber,
            isSpectator: myBattleStatus.isSpectator,
            handicap: myBattleStatus.handicap,
            syncStatus: isSynced ? .synced : .unsynced,
            side: myBattleStatus.side
        ))
        generalDisplay?.displaySyncStatus(isSynced)
    }

    // MARK: - Map

    /// Updates sync status, and loads minimap if the map is found.
    public func mapDidUpdate(to map: Battle.Map) {

        mapInfoDisplay?.displayMapName(map.name)
        minimapDisplay?.removeAllStartRects()

        let (nameMatch, checksumMatch, _) = resourceManager.hasMap(named: map.name, checksum: map.hash, preferredVersion: battle.engineVersion)
        self.hasMap = nameMatch
        if self.hasMap {
            if !checksumMatch {
                debugOnlyPrint("Warning: Map checksums do not match.")
            }

            displayMinimap(for: map)
        } else {
            resourceManager.download(.map(name: map.name), completionHandler: { [weak self] successful in
                guard let self = self else {
                    return
                }
                if successful,
                    // Because this is async, check the map hasn't changed yet.
                    map == self.battle.map {
                    self.displayMinimap(for: map)
                    self.hasMap = true
                } else {
                    print("Unsuccessful download of map \(map.name)")
                }
            })
        }
        minimapDisplay?.displayMapUnknown()
    }

    /// Sends map presentation data to the minimap display for it to display the map.
    ///
    /// Fails silently when the map's width and height cannot be retreived from the resource manager.
    private func displayMinimap(for map: Battle.Map) {
        guard let (width, height) = resourceManager.dimensions(forMapNamed: map.name) else {
            return
        }
        minimapDisplay?.setMapDimensions(width, height)

        resourceManager.loadMinimapData(forMapNamed: map.name, mipLevels: Range(0...5)) { [weak self] result in
            guard let self = self,
                let minimapDisplay = self.minimapDisplay,
                let (imageData, dimension) = result else {
                return
            }

            minimapDisplay.displayMapImage(for: imageData, dimension: dimension)
        }
    }

    // MARK: - ListDelegate
    // The Battleroom is the delegate of the battle's userlist. Updates happen there.

    public func list(_ list: ListProtocol, didAddItemWithID id: Int, at index: Int) {}

    public func list(_ list: ListProtocol, didMoveItemFrom index1: Int, to index2: Int) {}

    public func list(_ list: ListProtocol, didRemoveItemAt index: Int) {}

    public func list(_ list: ListProtocol, itemWasUpdatedAt index: Int) {
        if list.sortedItemsByID[index] == myID {
            displayIngameStatus()
        }
    }

    public func listWillClear(_ list: ListProtocol) {}

    // MARK: - Nested Types
	
	final class Bot {
		let name: String
		let owner: User
		var status: UserStatus
		var color: Int32
		
		init(name: String, owner: User, status: UserStatus, color: Int32) {
			self.name = name
			self.owner = owner
			self.status = status
			self.color = color
		}
	}
	
	public struct UserStatus {
		public let isReady: Bool
        public let teamNumber: Int
        /// The alliance the user is a part of.
        ///
        /// There are 16 possible alliances, numbered 0 through 15.
        public let allyNumber: Int
        public let isSpectator: Bool
        public let handicap: Int
        public let syncStatus: SyncStatus
        public let side: Int

        public func changing(
            isReady: Bool? = nil,
            teamNumber: Int? = nil,
            allyNumber: Int? = nil,
            isSpectator: Bool? = nil,
            syncStatus: SyncStatus? = nil,
            side: Int? = nil
        ) -> UserStatus {
            return UserStatus(
                isReady: isReady ?? self.isReady,
                teamNumber: teamNumber ?? self.teamNumber,
                allyNumber: allyNumber ?? self.allyNumber,
                isSpectator: isSpectator ?? self.isSpectator,
                handicap: handicap,
                syncStatus: syncStatus ?? self.syncStatus,
                side: side ?? self.side
            )
        }
		
        public enum SyncStatus: Int {
			case unknown = 0
			case synced = 1
			case unsynced = 2
		}

        var description: String {
            return "|Sync: \(syncStatus), R: \(isReady), S: \(isSpectator), A# \(allyNumber), T# \(teamNumber), H: \(handicap), Fac: \(side)|"
        }

        public static var `default`: UserStatus {
            return UserStatus(
                isReady: false,
                teamNumber: 1,
                allyNumber: 1,
                isSpectator: true,
                handicap: 0,
                syncStatus: .unknown,
                side: 0
            )
        }

        public init(isReady: Bool, teamNumber: Int, allyNumber: Int, isSpectator: Bool, handicap: Int = 0, syncStatus: SyncStatus, side: Int) {
            self.isReady = isReady
            self.teamNumber = teamNumber
            self.allyNumber = allyNumber
            self.isSpectator = isSpectator
            self.handicap = handicap
            self.syncStatus = syncStatus
            self.side = side
        }
		
        init?(statusValue: Int) {
			isReady = (statusValue & 0b10) == 0b10
			teamNumber = (statusValue & 0b111100) >> 2
			allyNumber = (statusValue & 0b1111000000) >> 6
			isSpectator = (statusValue & 0b10000000000) != 0b10000000000
			handicap = (statusValue & 0b111111100000000000) >> 11
			
			let syncValue = (statusValue & 0b110000000000000000000000) >> 22
			
			switch syncValue {
			case 1:
				syncStatus = .synced
			case 2:
				syncStatus = .unsynced
			default:
				syncStatus = .unknown
			}
			
			self.side = (statusValue & 0b1111000000000000000000000000) >> 24
		}
		
		var integerValue: Int32 {
			var battleStatus: Int32 = 0
			if isReady {
				battleStatus += 2 // 2^1
			}
			battleStatus += Int32(teamNumber*4) // 2^2
			battleStatus += Int32(allyNumber*64) // 2^6
			if !isSpectator {
				battleStatus += 1024// 2^10
			}
			battleStatus += Int32(syncStatus.rawValue*4194304) // 2^22
			battleStatus += Int32(side*16777216) // 2^24
			return battleStatus
		}
	}
}
