//
//  SpringProcessController.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 4/12/19.
//  Copyright © 2019 MasterBel2. All rights reserved.
//

import Cocoa
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

    let system: System
    let replayController: ReplayController

    var scriptFileURL: URL {
        return system.configDirectory.appendingPathComponent("script.txt")
    }

    public init(system: System, replayController: ReplayController) {
        self.system = system
        self.replayController = replayController
    }

    /// Launches a spring instance with instructions to connect to the specified host.
    func launchSpringAsClient(andConnectTo ip: String, at port: Int, with username: String, and password: String, completionHandler: (() -> Void)?) {

        let specification = ClientSpecification(ip: ip, port: port, username: username, scriptPassword: password)


        let shouldRecordDemo = true
        startSpringRTS(script: specification.launchScript(shouldRecordDemo: shouldRecordDemo), willRecordDemo: shouldRecordDemo, completionHandler: completionHandler)
    }

    /// Launches spring.
    func startSpringRTS(script: String, willRecordDemo: Bool, completionHandler: (() -> Void)?) {
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
}
