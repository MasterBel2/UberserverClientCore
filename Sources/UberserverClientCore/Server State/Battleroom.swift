//
//  Battleroom.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 24/6/19.
//  Copyright © 2019 MasterBel2. All rights reserved.
//

import Foundation
import SpringRTSStartScriptHandling

// MARK: - Protocols

public protocol ReceivesBattleroomUpdates {

    // Map Options
    
    func addCustomisedMapOption(_ option: String, value: ArchiveOption.ValueType)
    func removeCustomisedMapOption(_ option: String)
    
    // Game Options
    
    func addCustomisedGameOption(_ option: String, value: ArchiveOption.ValueType)
    func removeCustomisedGameOption(_ option: String)
    
    // Status
    
    /// Notifies the display of the host's and user's updated in-game states.
    func display(isHostIngame: Bool, isPlayerIngame: Bool)
    /// Notifies the display that an updated ready state should be displayed.
    func displayReadySate(_ isReady: Bool)
    
    // Start Rect
    
    /// Draws a start rect overlay on the minimap for the specified allyteam.
    func addStartRect(_ rect: StartRect, for allyTeam: Int)
    /// Removes the start rect coresponding to the specified ally team.
    func removeStartRect(for allyTeam: Int)
    /// Removes all start rects that have been displayed.
    func removeAllStartRects()
    
    // Teams
    
    /// Notifiies the display that a new team was added.
    func addedTeam(named teamName: String)
    /// Notifies the display that a team was removed.
    func removedTeam(named teamName: String)
}

public extension ReceivesBattleroomUpdates {
    func addCustomisedMapOption(_ option: String, value: ArchiveOption.ValueType) {}
    func removeCustomisedMapOption(_ option: String) {}

    func addCustomisedGameOption(_ option: String, value: ArchiveOption.ValueType) {}
    func removeCustomisedGameOption(_ option: String) {}
    
    func display(isHostIngame: Bool, isPlayerIngame: Bool) {}
    func displayReadySate(_ isReady: Bool) {}
    
    func addStartRect(_ rect: StartRect, for allyTeam: Int) {}
    func removeStartRect(for allyTeam: Int) {}
    func removeAllStartRects() {}
    
    func addedTeam(named teamName: String) {}
    func removedTeam(named teamName: String) {}
}

public final class Battleroom: UpdateNotifier, ListDelegate, ReceivesBattleUpdates {

    // MARK: - Data
    
    private weak var server: TASServer?
    
    // MARK: - Dependencies

    /// The battleroom's associated battle.
    public let battle: Battle
    /// The battleroom's associated channel.
    public let channel: Channel
    
    // MARK: - Users
    
    public private(set) var allyNamesForAllyNumbers: [Int : String] = [:]
    public let allyTeamLists: [List<User>]
    public let spectatorList: List<User>
    var bots: [Bot] = []
    
    // MARK: - Game Attributes

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

    // MARK: - Information about the Local Client

    let myID: Int

    public var myBattleStatus: Battleroom.UserStatus {
        return userStatuses[myID] ?? UserStatus(
            isReady: false,
            teamNumber: 0,
            allyNumber: 0,
            isSpectator: false,
            handicap: 0,
            syncStatus: battle.isSynced ? .synced : .unsynced,
            side: 0
        )
    }

    public var myColor: Int32 {
        return colors[myID] ?? Int32(myID.hashValue & 0x00FFFFFF)
    }
    /// Whether the player is ingame.
    public var isPlayerIngame: Bool {
        return battle.userList.items[myID]?.status.isIngame ?? false
    }

    /// Whether the host is ingame.
    public var isHostIngame: Bool {
        return battle.userList.items[battle.founderID]?.status.isIngame ?? false
    }

    public func trueSkill(for id: Int) -> Float? {
        guard let string = trueSkills[id] else { return nil }
        return Float(string.filter({ $0.isNumber || $0 == "." }))
    }

    // MARK: - Lifecycle

    init(battle: Battle, channel: Channel, server: TASServer, hashCode: Int32, myID: Int) {
        self.battle = battle
        self.hashCode = hashCode
        self.channel = channel

        self.myID = myID

        let battleroomSorter = BattleroomPlayerListSorter()

        // + 1 – Users will count from 1, not from 0
        allyTeamLists = (0...15).map({ List(title: "Ally \(String($0 + 1))", sorter: battleroomSorter, parent: battle.userList) })
        spectatorList = List<User>(title: "Spectators", sorter: battleroomSorter, parent: battle.userList)
        
        self.server = server

        battleroomSorter.battleroom = self
        battle.addObject(self)
		battle.userList.addObject(self)
        
        battle.shouldAutomaticallyDownloadMap = true
        
        updateSync()
    }
    
    deinit {
        battle.shouldAutomaticallyDownloadMap = false
    }

    // MARK: - Updates

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
                    applyActionToChainedObjects({ $0.removedTeam(named: allyName) })
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
                    applyActionToChainedObjects({ $0.addedTeam(named: allyName) })
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
            applyActionToChainedObjects({ $0.displayReadySate(newUserStatus.isReady) })
		}

        // Update the view
        battle.userList.respondToUpdatesOnItem(identifiedBy: userID)
    }

    /// Adds a start rect.
    func addStartRect(_ rect: StartRect, for allyTeam: Int) {
        startRects[allyTeam] = rect
        applyActionToChainedObjects({ $0.addStartRect(rect, for: allyTeam) })
    }

    /// Removes a start rect.
    func removeStartRect(for allyTeam: Int) {
        startRects.removeValue(forKey: allyTeam)
        applyActionToChainedObjects({ $0.removeStartRect(for: allyTeam) })
    }
    
    // MARK: - User Actions
    
    public func startGame() {
        #warning("Consider moving this to Battle")
        guard let server = server,
            let myAccount = battle.userList.items[myID] else {
            return
        }
        guard let engine = battle.engine else {
            #warning("Throw an error here!")
            return
        }
        server.send(CSMyStatusCommand(status: myAccount.status.changing(isIngame: true)))
        server.send(CSMyBattleStatusCommand(battleStatus: myBattleStatus.changing(isReady: false), color: myColor))
        
        let specification = ClientSpecification(ip: battle.ip, port: battle.port, username: myAccount.profile.username, scriptPassword: battle.myScriptPassword)
        try? engine.launchGame(script: specification, doRecordDemo: true) { [weak self] in
            self?.server?.send(CSMyStatusCommand(status: myAccount.status.changing(isIngame: false)))
        }
    }
    
    // MARK: - UpdateNotifier
    
    public var objectsWithLinkedActions: [() -> ReceivesBattleroomUpdates?] = []
    
    // MARK: - Battle Updates
    
    public func mapDidUpdate(to map: Battle.MapIdentification) { updateSync() }
    public func loadedMapArchive(_ mapArchive: MapArchive, checksumMatch: Bool, usedPreferredEngineVersion: Bool) { updateSync() }
    public func loadedEngine(_ engine: Engine) { updateSync() }
    public func loadedGameArchive(_ gameArchive: ModArchive) { updateSync() }
    
    private func updateSync() {
        server?.send(
            CSMyBattleStatusCommand(
                battleStatus: myBattleStatus.changing(syncStatus: battle.isSynced ? .synced : .unsynced),
                color: myColor
            )
        )
    }

    // MARK: - ListDelegate
    // The Battleroom needs to update when the battle updates.

    public func list(_ list: ListProtocol, didAddItemWithID id: Int, at index: Int) {}

    public func list(_ list: ListProtocol, didMoveItemFrom index1: Int, to index2: Int) {}

    public func list(_ list: ListProtocol, didRemoveItemAt index: Int) {}

    public func list(_ list: ListProtocol, itemWasUpdatedAt index: Int) {
        if list.sortedItemsByID[index] == myID || list.sortedItemsByID[index] == battle.founderID {
            applyActionToChainedObjects({ $0.display(isHostIngame: isHostIngame, isPlayerIngame: isPlayerIngame)})
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
