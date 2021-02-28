//
//  AccountInfoController.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 30/6/20.
//  Copyright © 2020 MasterBel2. All rights reserved.
//

import Foundation

/// A set of account metadata.
public struct AccountData {

    public init(email: String, ingameHours: Int, registrationDate: Date?) {
        self.email = email
        self.ingameHours = ingameHours
        self.registrationDate = registrationDate
    }

    /// The user's email address.
    public let email: String
    /// The number of hours the server has recorded as the user's status has indicated that they are ingame.
    public let ingameHours: Int
    /// The date the user's account was registered.
    public let registrationDate: Date?
}

/// Manages information about a user's account.
public final class AccountInfoController {

    // MARK: - Depedencies

    /// The client associated with the account.
    public weak var client: Client?

    // MARK: - Data

    /// The logged-in user which the metadata describes.
    public var user: User? {
        return client?.inAuthenticatedState { (authenticatedClient: AuthenticatedClient, _: Connection) -> User? in
            return authenticatedClient.userList.items.first(where: { $0.value.profile.fullUsername == authenticatedClient.username })?.value
        } ?? nil
    }

    /// A cached value for email. Wiped on present.
    private var email: String?
    /// A cached value for ingame hours. Wiped on present.
    private var ingameHours: Int?
    /// A cached value for registration date. Wiped on present. (Wiping)
    private var registrationDate: Date?

    /// A block to execute when account data has been retrieved and is ready to present.
    private var completionBlock: ((AccountData) -> ())?

    // MARK: - Updating data

    /// Records the registration date of the user for presentation.
    public func setRegistrationDate(_ registrationDate: Date?) {
        self.registrationDate = registrationDate
        presentIfReady()
    }

    /// Records the ingame hours of the user for presentation.
    public func setIngameHours(_ ingameHours: Int) {
        self.ingameHours = ingameHours
        presentIfReady()
    }

    /// Records the email of the user for presentation.
    public func setEmail(_ email: String) {
        self.email = email
        presentIfReady()
    }

    /// Wipes the cached information.
    public func invalidate() {
        email = nil
        ingameHours = nil
        registrationDate = nil
    }

    // MARK: - Private helpers

    /// Presents cached data and wipes the cache.
    private func presentIfReady() {
        if let email = email,
            let ingameHours = ingameHours {
            let accountData = AccountData(email: email, ingameHours: ingameHours, registrationDate: registrationDate)
            completionBlock?(accountData)
            invalidate()
        }
    }

    // MARK: - AccountDataSource

    public func retrieveAccountData(completionBlock: @escaping (AccountData) -> ()) {
        client?.inAuthenticatedState { _, connection in
            self.completionBlock = completionBlock
            connection.send(CSGetUserInfoCommand())
            presentIfReady()
        }
    }

    // MARK: - AccountInfoDelegate

    /// Requests a verification code to be sent to the new email address, before changing email address.
    ///
    /// Automatically detects whether a verification code is required, and will call `changeEmailWithoutVerification(to:password:completion:)` with the provided arguments, and return.
    public func requestVerficationCodeForChangingEmail(to newEmailAddress: String, password: String, completionBlock: @escaping (String?) -> ()) {
        client?.inAuthenticatedState { authenticatedClient, connection in
            guard connection.featureAvailability?.requiresVerificationCodeForChangeEmail == true else {
                changeEmailWithoutVerification(to: newEmailAddress, password: password, completionBlock: completionBlock)
                return
            }

            if password == authenticatedClient.password {
                connection.send(CSChangeEmailRequestCommand(newEmail: newEmailAddress)) { response in
                    if let _ = response as? SCChangeEmailRequestAcceptedCommand {
                        completionBlock(nil)
                    } else if let failureResponse = response as? SCChangeEmailRequestDeniedCommand {
                        completionBlock(failureResponse.errorMessage)
                    } else {
    //                    completionBlock("A server error occurred!")
                        return false
                    }
                    return true
                }
            } else {
                completionBlock("Incorrect password.")
            }
        }
    }

    /// Attempts to change the user's email to the new email address.
    ///
    /// Requires the verification code that will be sent after a successful `requestVerificationCodeForChangingEmail(to:password:completionBlock:)`
    public func changeEmail(to newEmailAddress: String, password: String, verificationCode: String, completionBlock: @escaping (String?) -> ()) {
        client?.inAuthenticatedState { authenticatedClient, connection in
            if password == authenticatedClient.password {
                connection.send(CSChangeEmailWithVerificationCommand(newEmail: newEmailAddress, verificationCode: verificationCode)) { response in
                    if let _ = response as? SCChangeEmailAcceptedCommand {
                        completionBlock(nil)
                        connection.send(CSGetUserInfoCommand())
                    } else if let failureResponse = response as? SCChangeEmailDeniedCommand {
                        completionBlock(failureResponse.errorMessage)
                    } else {
                        return false
                        //                    completionBlock("A server error occurred!")
                    }
                    return true
                }
            } else {
                completionBlock("Incorrect password.")
            }
        }
    }
    
    /// Attempts to change email where a verification code is not required.
    public func changeEmailWithoutVerification(to newEmailAddress: String, password: String, completionBlock: @escaping (String?) -> ()) {
        client?.inAuthenticatedState { authenticatedClient, connection in
            if password == authenticatedClient.password {
                connection.send(CSChangeEmailWithoutVerificationCommand(newEmail: newEmailAddress)) { response in
                    if let _ = response as? SCChangeEmailAcceptedCommand {
                        completionBlock(nil)
                        connection.send(CSGetUserInfoCommand())
                    } else if let failureResponse = response as? SCChangeEmailDeniedCommand {
                        completionBlock(failureResponse.errorMessage)
                    } else {
                        return false
                        //                    completionBlock("A server error occurred!")
                    }
                    return true
                }
            } else {
                completionBlock("Incorrect password.")
            }
        }
    }

    /// Attempts to change the user's username to the new value..
    public func renameAccount(to newAccountName: String, password: String, completionBlock: @escaping (String?) -> ()) {
        client?.inAuthenticatedState { authenticatedClient, connection in
            if password == authenticatedClient.password {
                connection.send(CSRenameAccountCommand(newUsername: newAccountName))
                completionBlock(nil)
            }
        }
    }

    /// Attempts to change the user's password to the new value.
    public func changePassword(from oldPassword: String, to newPassword: String, completionBlock: @escaping (String?) -> ()) {
        client?.inAuthenticatedState { authenticatedClient, connection in
            if oldPassword == authenticatedClient.password {
                connection.send(CSChangePasswordCommand(oldPassword: oldPassword, newPassword: newPassword))
                completionBlock(nil)
            }
        }
    }
}
