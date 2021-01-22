//
//  SpringProcessController.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 4/12/19.
//  Copyright © 2019 MasterBel2. All rights reserved.
//

import Cocoa
import ServerAddress
import SpringRTSReplayHandling
import SpringRTSStartScriptHandling

/// Describes a data object with the necessary information to start Spring.
protocol LaunchScriptConvertible {
    /// Generates a string suitable for launching the engine to a specification.
    func launchScript(shouldRecordDemo: Bool) -> String
}

/// Handles configuring and launching of a single instance of the SpringRTS engine.
public final class SpringProcessController {
    private(set) var canLaunchSpring: Bool = true

    private let system: System
    private let replayController: ReplayController

    private var scriptFileURL: URL {
        return system.configDirectory.appendingPathComponent("script.txt")
    }

    public init(system: System, replayController: ReplayController) {
        self.system = system
        self.replayController = replayController
    }

    /// Launches a spring instance with instructions to connect to the specified host.
    public func launchSpringAsClient(andConnectTo ip: String, at port: Int, with username: String, and password: String, completionHandler: (() -> Void)?) throws {

        let specification = ClientSpecification(ip: ip, port: port, username: username, scriptPassword: password)


        let shouldRecordDemo = true
        try startSpringRTS(script: specification.launchScript(shouldRecordDemo: shouldRecordDemo), willRecordDemo: shouldRecordDemo, completionHandler: completionHandler)
    }

    /// Launches spring.
	///
	/// - parameter willRecordDemo: whether the script contains an isntruction to record a demo. If true, the replay controller will be instructed to reload replays after the game is done, to detect the new file.
	/// - parameter completionHandler: A function to be called when Spring closes or an error is thrown.
    public func startSpringRTS(script: String, willRecordDemo: Bool, completionHandler: (() -> Void)?) throws {
		guard canLaunchSpring else {
			// (This is not an inherent limitation of the engine, and thus it should be considered whether this restriction should remain.)
			// (At time of writing this restriction appears to be enforced by all available lobbies.)
			completionHandler?()
			throw SpringLaunchError.alreadyRunning
		}
        do {
            try script.write(toFile: scriptFileURL.path, atomically: true, encoding: .utf8)
            let app = "Spring_103.0.app"
            system.launchApplication(app, with: [scriptFileURL.path], completionHandler: { [weak self] in
                completionHandler?()
                if willRecordDemo {
                    try? self?.replayController.loadReplays()
                }
                self?.canLaunchSpring = true
            })
            canLaunchSpring = false
        } catch {
            completionHandler?()
            canLaunchSpring = true
        }
    }
	
	/// Launches a replay, as described by the infolog.
	public func launchReplay(_ replay: Replay, shouldRecordDemo: Bool) throws {
		// For ease of typing; this has no consequence.
		let demoSpecification = replay.gameSpecification
		let newSpecification = GameSpecification(
			allyTeams: demoSpecification.allyTeams,
			spectators: demoSpecification.spectators,
			demoFile: replay.fileURL,
			hostConfig: HostConfig(
				userID: nil,
				username: "Viewer",
				type: .user(lobbyName: "BelieveAndRise"), // TODO: Use the user's logged-in name if possible
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
		try startSpringRTS(script: newSpecification.launchScript(shouldRecordDemo: shouldRecordDemo), willRecordDemo: shouldRecordDemo, completionHandler: nil)
	}
	
	// MARK: - Errors
	
	private enum SpringLaunchError: Error {
		case alreadyRunning
	}
}
