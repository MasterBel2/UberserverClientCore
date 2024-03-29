//
//  AccountMetadataCommands.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 18/6/20.
//  Copyright © 2020 MasterBel2. All rights reserved.
//

import Foundation

/**
 Requests a verification code, to be sent to a new email address that the user wishes to associate to their account.

 Even if email verification is disabled, it is intended that the client will call this before calling `CSChangeEmailCommand`. If email verification is disabled, the response will be a SCChangeEmailRequestDeniedCommand, containing a message informing the user that a blank verification code will be accepted.

 # Response

 `CSChangeEmailRequestDenied` or `CSChangeEmailRequestAccepted`

 */
struct CSChangeEmailRequestCommand: CSCommand {

    static let title = "CHANGEEMAILREQUEST"

    /// The requested email address, which will have the verification code sent to it.
    let newEmail: String

    /**
     - parameter newEmail: The email address the user wishes to change too.
     */
    init(newEmail: String) {
        self.newEmail = newEmail
    }

    init?(payload: String) {
        guard let (words, _) = try? wordsAndSentences(for: payload, wordCount: 1, sentenceCount: 0) else {
            return nil
        }
        newEmail = words[0]
    }

    var payload: String {
        return newEmail
    }

    func execute(on server: LobbyServer) {
        //
    }
}

/**
 Asks the server to change the email address associated to the client. See also `CSChangeEmailRequestCommand`, which would typically be sent first.

 # Response

 `CSChangeEmailDenied` or `CSChangeEmailAccepted`
 */
struct CSChangeEmailWithoutVerificationCommand: CSCommand {

    static let title = "CHANGEEMAIL"

    let newEmail: String

    /**
     - parameter newEmail: The email address the user wishes to change too.
     */
    init(newEmail: String) {
        self.newEmail = newEmail
    }

    init?(payload: String) {
        guard let (words, _) = try? wordsAndSentences(for: payload, wordCount: 1, sentenceCount: 0) else {
            return nil
        }
        newEmail = words[0]
    }

    var payload: String {
        return newEmail
    }

    func execute(on server: LobbyServer) {
        // TODO
    }
}

/**
 Asks the server to change the email address associated to the client. See also `CSChangeEmailRequestCommand`, which would typically be sent first.

 # Response

 `CSChangeEmailDenied` or `CSChangeEmailAccepted`
 */
struct CSChangeEmailWithVerificationCommand: CSCommand {

    static let title = "CHANGEEMAIL"

    let newEmail: String
    let verificationCode: String

    /**
     - parameter newEmail: The email address the user wishes to change too.
     - parameter verificationCode: The verification code sent to the email address (as a response to `CSChangeEmailRequestCommand`).
     */
    init(newEmail: String, verificationCode: String) {
        self.newEmail = newEmail
        self.verificationCode = verificationCode
    }

    init?(payload: String) {
        guard let (words, _) = try? wordsAndSentences(for: payload, wordCount: 2, sentenceCount: 0) else {
            return nil
        }
        newEmail = words[0]
        self.verificationCode = words[1]
    }

    var payload: String {
        return "\(newEmail) \(verificationCode)"
    }

    func execute(on server: LobbyServer) {
        // TODO
    }
}
/**
 Will change the password of the users's account, if `oldPassword` matches the password stored in the database.

 # Response
 No formal response is required, although the server may reply with a `SCServerMessageCommand`.
 */
struct CSChangePasswordCommand: CSCommand {

    static let title = "CHANGEPASSWORD"

    let oldPassword: String
    let newPassword: String

    init(oldPassword: String, newPassword: String) {
        self.oldPassword = oldPassword
        self.newPassword = newPassword
    }

    init?(payload: String) {
        guard let (words, _) = try? wordsAndSentences(for: payload, wordCount: 2, sentenceCount: 0) else {
            return nil
        }
        oldPassword = words[0]
        newPassword = words[1]
    }

    var payload: String {
        return "\(oldPassword) \(newPassword)"
    }

    func execute(on server: LobbyServer) {
        // TODO
    }
}

/**
 Will rename the current account name to `newUsername`. The user has to be logged in for this to work. After the server renames the account, it will disconnect the client.

 # Response

 No formal response is required, although the server may reply with a `SCServerMsg`.

 # Examples

 `RENAMEACCOUNT Johnny2`

 */
struct CSRenameAccountCommand: CSCommand {
    static let title = "RENAMEACCOUNT"

    /// The new username for the account.
    let newUsername: String

    init(newUsername: String) {
        self.newUsername = newUsername
    }

    init?(payload: String) {
        guard let (words, _) = try? wordsAndSentences(for: payload, wordCount: 1, sentenceCount: 0) else {
            return nil
        }
        newUsername = words[0]
    }

    var payload: String {
        return "\(newUsername)"
    }

    func execute(on server: LobbyServer) {
        // TODO
    }
}
