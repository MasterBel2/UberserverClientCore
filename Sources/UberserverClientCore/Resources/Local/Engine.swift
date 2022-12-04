import Foundation
import SpringRTSStartScriptHandling

public struct Engine {
    private let system: System
    
    init(location: URL, version: String, isReleaseVersion: Bool, system: System, unitsyncWrapper: QueueLocked<UnitsyncWrapper>) throws {
        self.system = system
        self.version = version
        self.isReleaseVersion = isReleaseVersion
        self.location = location
        self.unitsyncWrapper = unitsyncWrapper

        #if os(macOS)

        executableURL = Bundle(url: location).throwIfNil().executableURL
        dedicatedURL = executableURL
        headlessURL = executableURL
        
        #elseif os(Linux)
        
        self.executableURL = location.appendingPathComponent("spring", isDirectory: false)
        self.dedicatedURL = location.appendingPathComponent("spring-dedicated", isDirectory: false)
        self.headlessURL = location.appendingPathComponent("spring-headless", isDirectory: false)
        
        #endif
    }
    
	public let version: String
	public let isReleaseVersion: Bool
    
    public var scriptFileURL: URL {
        return system.configDirectory.appendingPathComponent("script.txt", isDirectory: false)
    }

	/// Returns a string that may be used to determine if it will sync with another engine version. For a release version, this is the major
	/// and minor versions of the engine. For other versions, it is the entire version string.
	public var syncVersion: String {
        return String(cString: unitsyncWrapper.sync(block: { $0.GetSpringVersion() }))
	}

    public let executableURL: URL

    public let dedicatedURL: URL
    public let headlessURL: URL

	public let location: URL
	let unitsyncWrapper: QueueLocked<UnitsyncWrapper>
    
    /// Launches spring.
    ///
    /// - parameter willRecordDemo: whether the script contains an isntruction to record a demo. If true, the replay controller will be instructed to reload replays after the game is done, to detect the new file.
    /// - parameter completionHandler: A function to be called when Spring closes or an error is thrown.
    public func launchGame(script: LaunchScriptConvertible, doRecordDemo: Bool, flavor: Flavor = .full, completionHandler: (() -> Void)?) throws {
        let engineURL: URL
        let args: [String]
        switch flavor {
        case .dedicated:
            engineURL = dedicatedURL
            args = [scriptFileURL.path]
        case .headless:
            engineURL = headlessURL
            args = [scriptFileURL.path, "--write-dir=\(location.deletingLastPathComponent().deletingLastPathComponent().path)", "--isolation"]
        case .full:
            engineURL = executableURL
            args = [scriptFileURL.path, "--write-dir=\(location.deletingLastPathComponent().deletingLastPathComponent().path)", "--isolation"]
        }

        do {
            try script.launchScript(shouldRecordDemo: doRecordDemo).write(toFile: scriptFileURL.path, atomically: true, encoding: .utf8)
            system.launchApplication(at: engineURL.path, with: args, completionHandler: {
                completionHandler?()
//                if doRecordDemo {
//                    try? self?.replayController.loadReplays()
//                }
            })
        } catch {
            print("Failed to start engine! \(error)")
            completionHandler?()
        }
    }

    public enum Flavor {
        case dedicated
        case headless
        case full
    }
}
