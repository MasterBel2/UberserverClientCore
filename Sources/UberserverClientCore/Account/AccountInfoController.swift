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

    /// The authenticatedClient associated with the account.
    weak var authenticatedClient: AuthenticatedSession?
    weak var lobby: TASServerLobby?

    // MARK: - Data

    /// A cached value for email. Wiped on present.
    private var email: String?
    /// A cached value for ingame hours. Wiped on present.
    private var ingameHours: Int?
    /// A cached value for registration date. Wiped on present. (Wiping)
    private var registrationDate: Date?

    /// Wipes the cached information.
    public func invalidate() {
        email = nil
        ingameHours = nil
        registrationDate = nil
    }

    // MARK: - Private helpers

    // MARK: - AccountDataSource

    public func retrieveAccountData(completionBlock: @escaping (AccountData) -> ()) {
        guard let lobby = lobby else { return }

        lobby.send(CSGetUserInfoCommand(), specificHandler: { [weak self] response in
            guard let self = self else { return true }

            if let serverMessage = response as? SCServerMessageCommand {
                let message = serverMessage.message

                if message.hasPrefix("Registration date:") {
                    let components = message.components(separatedBy: " ")
                    if components.count >= 6 {
                        let dateString = components[2..<5].joined(separator: " ")
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "MMM DD, YYYY"
                        if let date = dateFormatter.date(from: dateString) {
                            self.registrationDate = date
                        }
                    } else {
                        self.registrationDate = .none
                    }
                } else if message.hasPrefix("Email address:") {
                    let components = message.components(separatedBy: " ")
                    if components.count == 3,
                        components[2] != "",
                        components[2] != "None" {
                        self.email = components[2]
                    } else {
                        self.email = "No email provided"
                    }
                } else if message.hasPrefix("Ingame time:") {
                    let ingameTimeString = message.components(separatedBy: " ")[2]
                    if let ingameTime = Int(ingameTimeString) {
                        self.ingameHours = ingameTime
                    }
                }
            }

            if let email = self.email,
               let ingameHours = self.ingameHours {
                let accountData = AccountData(email: email, ingameHours: ingameHours, registrationDate: self.registrationDate)
                completionBlock(accountData)
                self.invalidate()
                return true
            } else {
                return false
            }
        })
    }

    // MARK: - AccountInfoDelegate

    /// Requests a verification code to be sent to the new email address, before changing email address.
    ///
    /// Automatically detects whether a verification code is required, and will call `changeEmailWithoutVerification(to:password:completion:)` with the provided arguments, and return.
    public func requestVerficationCodeForChangingEmail(to newEmailAddress: String, password: String, completionBlock: @escaping (String?) -> ()) {
        guard let authenticatedClient = authenticatedClient, let lobby = lobby else { return }
        guard lobby.featureAvailability?.requiresVerificationCodeForChangeEmail == true else {
            changeEmailWithoutVerification(to: newEmailAddress, password: password, completionBlock: completionBlock)
            return
        }

        if password == authenticatedClient.password {
            lobby.send(CSChangeEmailRequestCommand(newEmail: newEmailAddress)) { response in
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

    /// Attempts to change the user's email to the new email address.
    ///
    /// Requires the verification code that will be sent after a successful `requestVerificationCodeForChangingEmail(to:password:completionBlock:)`
    public func changeEmail(to newEmailAddress: String, password: String, verificationCode: String, completionBlock: @escaping (String?) -> ()) {
        guard let authenticatedClient = authenticatedClient, let lobby = lobby else { return }
        if password == authenticatedClient.password {
            lobby.send(CSChangeEmailWithVerificationCommand(newEmail: newEmailAddress, verificationCode: verificationCode)) { response in
                if let _ = response as? SCChangeEmailAcceptedCommand {
                    completionBlock(nil)
                    lobby.send(CSGetUserInfoCommand())
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
    
    /// Attempts to change email where a verification code is not required.
    public func changeEmailWithoutVerification(to newEmailAddress: String, password: String, completionBlock: @escaping (String?) -> ()) {
        guard let authenticatedClient = authenticatedClient, let lobby = lobby else { return }
        if password == authenticatedClient.password {
            lobby.send(CSChangeEmailWithoutVerificationCommand(newEmail: newEmailAddress)) { response in
                if let _ = response as? SCChangeEmailAcceptedCommand {
                    completionBlock(nil)
                    lobby.send(CSGetUserInfoCommand())
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

    /// Attempts to change the user's username to the new value..
    public func renameAccount(to newAccountName: String, password: String, completionBlock: @escaping (String?) -> ()) {
        guard let authenticatedClient = authenticatedClient, let lobby = lobby else { return }
        if password == authenticatedClient.password {
            lobby.send(CSRenameAccountCommand(newUsername: newAccountName))
            completionBlock(nil)
        }
    }

    /// Attempts to change the user's password to the new value.
    public func changePassword(from oldPassword: String, to newPassword: String, completionBlock: @escaping (String?) -> ()) {
        guard let authenticatedClient = authenticatedClient, let lobby = lobby else { return }
        if oldPassword == authenticatedClient.password {
            lobby.send(CSChangePasswordCommand(oldPassword: oldPassword, newPassword: newPassword))
            completionBlock(nil)
        }
    }
}
