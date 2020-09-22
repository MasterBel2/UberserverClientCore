//
//  ListSelectionHandler.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 13/11/19.
//  Copyright © 2019 MasterBel2. All rights reserved.
//

import Foundation
import ServerAddress
import SpringRTSReplayHandling
import SpringRTSStartScriptHandling

/// Executes an action corresponding to a selection on the behalf of a list.
public protocol ListSelectionHandler {
	func primarySelect(itemIdentifiedBy id: Int)
	func secondarySelect(itemIdentifiedBy id: Int)
}

/// Executes select actions for a battle list.
public struct DefaultBattleListSelectionHandler: ListSelectionHandler {
	
	let battleController: BattleController
	let battlelist: List<Battle>
	
	public init(battlelist: List<Battle>, battleController: BattleController) {
		self.battlelist = battlelist
		self.battleController = battleController
	}
	
	public func primarySelect(itemIdentifiedBy id: Int) {
		battleController.joinBattle(id)
	}
	
	public func secondarySelect(itemIdentifiedBy id: Int) {
		primarySelect(itemIdentifiedBy: id)
	}
}

/// Executes select actions for a list of replays.
public struct ReplayListSelectionHandler: ListSelectionHandler {

    public init(replayList: List<Replay>, springProcessController: SpringProcessController) {
        self.replayList = replayList
        self.springProcessController = springProcessController
    }

    public let springProcessController: SpringProcessController
    public let replayList: List<Replay>

    public func primarySelect(itemIdentifiedBy id: Int) {
        if springProcessController.canLaunchSpring,
            let first = replayList.items[id] {
            let demoSpecification = first.gameSpecification
            let newSpecification = GameSpecification(
                allyTeams: demoSpecification.allyTeams,
                spectators: demoSpecification.spectators,
                demoFile: first.fileURL,
                hostConfig: HostConfig(
                    userID: nil,
                    username: "Viewer",
                    type: .user(lobbyName: "BelieveAndRise"),
                    address: ServerAddress(location: "", port: 8452),
                    rank: nil,
                    countryCode: nil
                ),
                startConfig: demoSpecification.startConfig,
                mapName: demoSpecification.mapName,
                mapHash: demoSpecification.mapHash,
                gameType: demoSpecification.gameType,
                modHash: demoSpecification.modHash,
                gameStartDelay: demoSpecification.gameStartDelay,
                mapOptions: demoSpecification.mapOptions,
                modOptions: demoSpecification.modOptions,
                restrictions: demoSpecification.restrictions
            )
            let shouldRecordDemo = true
            springProcessController.startSpringRTS(script: newSpecification.launchScript(shouldRecordDemo: shouldRecordDemo), willRecordDemo: shouldRecordDemo, completionHandler: nil)
        }
    }

    public func secondarySelect(itemIdentifiedBy id: Int) {}
}
