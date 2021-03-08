//
//  UnauthenticatedSession.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 13/7/19.
//  Copyright © 2019 MasterBel2. All rights reserved.
//

import Foundation
import ServerAddress

public struct LoginError: LocalizedError, CustomStringConvertible {
    public let description: String
}

/// The state of an unauthenticated session with a lobbyserver.
public final class UnauthenticatedSession {

    // MARK: - Dependencies

    /// The controller's interface with the keychain.
    private let credentialsManager: CredentialsManager
    /// The controller's interface with user defaults.
    private let preferencesController: PreferencesController

    // MARK: - Associated Objects
    weak var connection: Connection?

    // MARK: - Lifecycle

    init(preferencesController: PreferencesController) {
        self.preferencesController = preferencesController
        credentialsManager = CredentialsManager.shared
    }

    // MARK: - LoginDataSource

    /// Returns a list of usernames that have been previously used to log in to this server, if any.
    public func prefillableUsernames(serverAddress: ServerAddress) -> [String] {
        (try? credentialsManager.usernames(forServerWithAddress: serverAddress.description)) ?? []
    }

    /// Returns the last credentials used to log into the server, if any.
    public func lastCredentialsPair(serverAddress: ServerAddress) -> Credentials? {
        guard let lastUsername = preferencesController.lastUsername(for: serverAddress.description) else {
            return nil
        }
        return try? credentialsManager.credentials(forServerWithAddress: serverAddress.description, username: lastUsername)
    }

    // MARK: - Interacting With The Server

    /// Performs a registration attempt, and calls the completion handler on a response.
    ///
    /// The completion handler's argument is the username of the account logged in, or an error.
    public func submitLogin(username: String, password: String, completionHandler: @escaping (Result<String, LoginError>) -> Void) {
        guard let connection = connection else { return }
        connection.send(
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
                guard let self = self else { return true }
                if let loginAcceptedCommand = command as? SCLoginAcceptedCommand {
                    self.record(Credentials(username: loginAcceptedCommand.username, password: password), connection: connection)
                    connection.session = .authenticated(AuthenticatedSession(username: loginAcceptedCommand.username, password: password, connection: connection))
                    completionHandler(.success(loginAcceptedCommand.username))
                } else if let loginDeniedCommand = command as? SCLoginDeniedCommand {
                    completionHandler(.failure(LoginError(description: loginDeniedCommand.reason)))
                } else {
                    //                    completionHandler(.failure(LoginError(description: "A server error occured.")))
                    return false
                }
                return true
            }
        )
    }

    /// Performs a registration attempt, and calls the completion handler on a response.
    ///
    /// The completion handler's argument is an error, or nil.
    public func submitRegister(username: String, email: String, password: String, completionHandler: @escaping (String?) -> Void) {
        guard let connection = connection else { return }
        connection.send(
            CSRegisterCommand(
                username: username,
                password: password
            ),
            specificHandler: { [weak self] (command: SCCommand) in
                guard let self = self else { return true }
                if command is SCRegistrationAcceptedCommand {
                    self.record(Credentials(username: username, password: password), connection: connection)
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
                    //                    completionHandler("A server error occured.")
                    return false
                }
                return true
            }
        )
    }

    /// Stores a copy of the credentials associated with the connection for future reference.
    private func record(_ credentials: Credentials, connection: Connection) {
        preferencesController.setLastUsername(credentials.username, for: connection.address.description)
        try? credentialsManager.writeCredentials(credentials, forServerWithAddress: connection.address.description)
    }
}
