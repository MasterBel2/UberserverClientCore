//
//  UserAuthenticationController.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 13/7/19.
//  Copyright © 2019 MasterBel2. All rights reserved.
//

import Foundation

public struct LoginError: LocalizedError, CustomStringConvertible {
    public let description: String
}

public protocol LoginDelegate: AnyObject {
    func submitLogin(
        username: String,
        password: String,
        completionHandler: @escaping (Result<String, LoginError>) -> Void
    )
    func submitRegister(
        username: String,
        email: String,
        password: String,
        completionHandler: @escaping (String?) -> Void
    )
    var prefillableUsernames: [String] { get }
    var lastCredentialsPair: Credentials? { get }
}

/// A controller for the user authentication process.
public final class UserAuthenticationController: LoginDelegate {

    // MARK: - Data

    public private(set) var credentials: Credentials?

    // MARK: - Dependencies

    /// The controller's interface with the keychain.
    private let credentialsManager: CredentialsManager
    /// The controller's interface with user defaults.
    private let preferencesController: PreferencesController

    // MARK: - Associated Objects
    unowned var client: Client!

    /// A string that uniquely identifies the server
    private var serverDescription: String? {
        if let server = client.server {
            return "\(server.socket.address):\(server.socket.port)"
        }
        return nil
    }

    // MARK: - Lifecycle

    init(preferencesController: PreferencesController) {
        self.preferencesController = preferencesController
        credentialsManager = CredentialsManager.shared
    }

    func reset() {
        credentials = nil
    }

    // MARK: - LoginDataSource

    public var prefillableUsernames: [String] {
        if let serverDescription = serverDescription {
            return (try? credentialsManager.usernames(forServerWithAddress: serverDescription)) ?? []
        } else {
            return []
        }
    }

    public var lastCredentialsPair: Credentials? {
        if let serverDescription = serverDescription,
            let lastUsername = preferencesController.lastUsername(for: serverDescription) {
            return try? credentialsManager.credentials(forServerWithAddress: serverDescription, username: lastUsername)
        }
        return nil
    }

    // MARK: - LoginDelegate

    /// Performs a registration attempt, and calls the completion handler on a response.
    ///
    /// The completion handler's argument is the username of the account logged in, or an error.
    public func submitLogin(username: String, password: String, completionHandler: @escaping (Result<String, LoginError>) -> Void) {
        client.server?.send(
            CSLoginCommand(
                username: username,
                password: password,
                compatabilityFlags: [
                    .sayForBattleChatAndSayFrom,
                    .springEngineVersionAndNameInBattleOpened,
                    .lobbyIDInAddUser,
                    .joinBattleRequestAcceptDeny,
                    .scriptPasswords
                ]
            ),
            specificHandler: { [weak self] (command: SCCommand) in
                guard let self = self else { return }
                if let loginAcceptedCommand = command as? SCLoginAcceptedCommand {
                    self.record(Credentials(username: loginAcceptedCommand.username, password: password))
                    completionHandler(.success(loginAcceptedCommand.username))
                } else if let loginDeniedCommand = command as? SCLoginDeniedCommand {
                    completionHandler(.failure(LoginError(description: loginDeniedCommand.reason)))
                } else {
                    completionHandler(.failure(LoginError(description: "A server error occured.")))
                }
            }
        )
    }

    /// Performs a registration attempt, and calls the completion handler on a response.
    ///
    /// The completion handler's argument is an error, or nil.
    public func submitRegister(username: String, email: String, password: String, completionHandler: @escaping (String?) -> Void) {
        client.server?.send(
            CSRegisterCommand(
                username: username,
                password: password
            ),
            specificHandler: { [weak self] (command: SCCommand) in
                guard let self = self else { return }
                if command is SCRegistrationAcceptedCommand {
                    completionHandler(nil)
                    self.submitLogin(
                        username: username,
                        password: password,
                        completionHandler: { result in
                            switch result {
                            case .success:
                                break
                            case .failure(let error):
                                fatalError("Login failed: \(error.description)")
                            }
                        }
                    )
                } else if let deniedCommand = command as? SCRegistrationDeniedCommand {
                    completionHandler(deniedCommand.reason)
                } else {
                    completionHandler("A server error occured.")
                }
            }
        )
    }

    private func record(_ credentials: Credentials) {
        if let serverDescription = serverDescription {
            preferencesController.setLastUsername(credentials.username, for: serverDescription)
            self.credentials = credentials
            try? credentialsManager.writeCredentials(
                credentials, forServerWithAddress: serverDescription)
        }
    }
}
