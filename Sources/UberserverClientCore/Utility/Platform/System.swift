//
//  System.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 5/2/20.
//  Copyright © 2020 MasterBel2. All rights reserved.
//

import Foundation

/// A set of platform-specific system functions.
public protocol System: AnyObject {
    /// Writes data to a file.
    func write(_ fileContents: Data, to directory: URL)
    /// Reveals a file in a system-provided GUI.
    func showFile(_ fileName: String?, at directory: URL)

    /**
    Launches an application.

    - parameter path: The path of the application bundle.
    - parameter arguments: Arguments passed to the application on launch.
    - parameter completionHandler: called after the termination of the application.
    */
    func launchApplication(at path: String, with arguments: [String]?, completionHandler: (() -> Void)?)
    /// Searches for and launches an application.
    func launchApplication(_ applicationName: String, with arguments: [String]?, completionHandler: (() -> Void)?)

    /// Spring's data directory.
    var dataDirectory: URL { get }
    /// Spring's configuration/cache directory.
    var configDirectory: URL { get }
}

#if os(macOS)

import Cocoa

/// MacOS-specific system functions.
public final class MacOS: System {

    public init() {}

    // MARK: - Dependencies
    private let fileManager = FileManager.default
    private(set) var processes: [Process] = []

    // MARK: - Directories

    public let dataDirectory = NSHomeDirectoryURL().appendingPathComponent(".spring", isDirectory: true)
    public let configDirectory = NSHomeDirectoryURL().appendingPathComponent(".config").appendingPathComponent("spring", isDirectory: true)

    // MARK: - System

    public func showFile(_ fileName: String?, at directory: URL) {
        let fullDirectory: URL?
        if let fileName = fileName {
            fullDirectory = directory.appendingPathComponent(fileName)
        } else {
            fullDirectory = nil
        }
        NSWorkspace.shared.selectFile(fullDirectory?.path, inFileViewerRootedAtPath: directory.path)
    }

    public func launchApplication(_ application: String, with arguments: [String]?, completionHandler: (() -> Void)?) {
        guard let path = NSWorkspace.shared.fullPath(forApplication: application) else {
            debugPrint("Non-Fatal Error: could not find \(application)")
            return
        }
        launchApplication(at: path, with: arguments, completionHandler: completionHandler)
    }

    public func launchApplication(at path: String, with arguments: [String]?, completionHandler: (() -> Void)?) {
        guard let bundle = Bundle(path: path) else {
            debugPrint("Non-Fatal Error: could not create bundle object at \(path)")
            return
        }

        let process = Process()
        process.launchPath = bundle.executablePath
        process.arguments = arguments
        process.terminationHandler = { [weak self] process in
            self?.processes.removeAll(where: {$0 === process})
            completionHandler?()
        }
        process.launch()
        processes.append(process)
    }

    public func write(_ fileContents: Data, to directory: URL) {
        fileManager.createFile(atPath: directory.path, contents: fileContents, attributes: nil)
    }
}
#endif // macOS
