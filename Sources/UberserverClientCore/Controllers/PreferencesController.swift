//
//  PreferencesController.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 16/12/19.
//  Copyright © 2019 MasterBel2. All rights reserved.
//

import Foundation

final class DebugPreferencesController: PreferencesController {
    override func lastUsername(for serverName: String) -> String? {
        return "BelieveAndRise"
    }
}

/// An object that provides an API for persisting data about the user's preferences.
public class PreferencesController {

    fileprivate init() {}
    public static var `default`: PreferencesController = {
        #if DEBUG
        return DebugPreferencesController()
        #else
        return PreferencesController()
        #endif
    }()

	/// The standard user defaults object.
    private let userDefaults = UserDefaults.standard

	/// The player's preferred color.
    var preferredColor: Int32 {
        get {
            return value(for: .playerColor) ?? 0
        }
        set {
            setValue(newValue, for: .playerColor)
        }
    }

    /// Records the username as most recently used to log in to the server.
    public func setLastUsername(_ username: String, for serverName: String) {
        let key = serverAttributeKey(for: serverName, attributeKey: .lastUsername)
        userDefaults.set(username, forKey: key)
    }
    /// Returns the username most recently used to log in to the server.
    public func lastUsername(for serverName: String) -> String? {
        let key = serverAttributeKey(for: serverName, attributeKey: .lastUsername)
        return userDefaults.object(forKey: key) as? String
    }
	
	// MARK: - Private helpers

    private func serverAttributeKey(for serverAddress: String, attributeKey: ServerAttributeKey) -> String {
        return serverAddress + ":" + attributeKey.rawValue
    }

	/// Retrives the previously recorded value for the given key.
    private func value<ValueType>(for key: DefaultsKeys) -> ValueType? {
        return userDefaults.object(forKey: key.rawValue) as? ValueType
    }

	/// Records a value for the given key.
    private func setValue(_ value: Any?, for key: DefaultsKeys) {
        userDefaults.set(value, forKey: key.rawValue)
    }

    private enum ServerAttributeKey: String {
        /// The key associated with the username most recently used to log in to a server.
            case lastUsername
    }
	
	/// A set of keys corresponding to preference values.
    private enum DefaultsKeys: String {
		/// The key associated with player's preferred color.
        case playerColor
    }
}
