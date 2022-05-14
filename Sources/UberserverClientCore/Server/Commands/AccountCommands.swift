//
//  LoginAcceptedCommand.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 15/7/19.
//  Copyright © 2019 MasterBel2. All rights reserved.
//

import Foundation

/**
 Requests metadata about the currently logged in account. The server will respond with server messages describing the account.
 */
struct CSGetUserInfoCommand: CSCommand {

    static let title = "GETUSERINFO"

    init() {}
    init?(payload: String) {}

    var payload: String {
        return ""
    }

    func execute(on server: LobbyServer) {
        // TODO
    }
}

/**
 Confirm that the user agreed to the user agreement, and supply an email verification code (if necessary).

 # Response

 ACCEPTED, if the verification was either accepted or was not needed.
 DENIED, if the verification code was not accepted.
 */
struct CSConfirmAgreementCommand: CSCommand {
    static let title = "CONFIRMAGREEMENT"

    let verificationCode: String?

    init(verificationCode: String?) {
        self.verificationCode = verificationCode
    }

    init?(payload: String) {
        guard let (_, _, optionalWords, _) = try? wordsAndSentences(for: payload, wordCount: 0, sentenceCount: 1, optionalWordCount: 1) else {
            return nil
        }

        verificationCode = optionalWords.first
    }

    var payload: String {
        return verificationCode ?? ""
    }

    func execute(on server: LobbyServer) {
        // TODO
    }
}

/**
 Sent as a response to the LOGIN command, if it succeeded. Next, the server will send much info
 about clients and battles:

 - multiple MOTD, each giving one line of the current welcome message
 - multiple ADDUSER, listing all users currently logged in
 - multiple BATTLEOPENED, UPDATEBATTLEINFO, detailing the state of all currently open battles
 - multiple JOINEDBATTLE, indiciating the clients present in each battle
 - multiple CLIENTSTATUS, detailing the statuses of all currently logged in users
 */
struct SCLoginAcceptedCommand: SCCommand {

    static let title = "ACCEPTED"

    // MARK: Properties

    let username: String

    // MARK: Manual Construction

    init(username: String) {
        self.username = username
    }

    // MARK: SCCommand

    init?(payload: String) {
        guard let (words, _) = try? wordsAndSentences(for: payload, wordCount: 1, sentenceCount: 0) else {
            return nil
        }
        username = words[0]
    }

    var payload: String {
        return username
    }

    /// Uberserver does not handle command IDs properly, so this hacks around that (since we know that we don't send a second command handler before login completes).
    public func execute(on lobby: TASServerLobby) {
        _ = lobby.specificCommandHandlers.first?.value(self)
        lobby.specificCommandHandlers = [:]
    }
}

/**
Sent as a response to a failed LOGIN command.
*/
struct SCLoginDeniedCommand: SCCommand {

    static let title = "DENIED"
	
	let reason: String
	
	// MARK: Manual Construction
	
	init(reason: String) {
		self.reason = reason
	}
	
	// MARK: SCCommand
	
	init?(payload: String) {
		guard let (_ , sentences) = try? wordsAndSentences(for: payload, wordCount: 0, sentenceCount: 1) else {
			return nil
		}
		self.reason = sentences[0]
	}

    /// Uberserver does not handle command IDs properly, so this hacks around that (since we know that we don't send a second command handler before login completes).
    public func execute(on lobby: TASServerLobby) {
        _ = lobby.specificCommandHandlers.first?.value(self)
        lobby.specificCommandHandlers = [:]
    }

	var payload: String {
		return reason
	}
}


/**
Sent in response to a REGISTER command, if registration has been refused.
*/
struct SCRegistrationDeniedCommand: SCCommand {

    static let title = "REGISTRATIONDENIED"
	
	let reason: String
	
	// MARK: Manual Construction
	
	init(reason: String) {
		self.reason = reason
	}
	
	// MARK: SCCommand
	
	init?(payload: String) {
		guard let (_, sentences) = try? wordsAndSentences(for: payload, wordCount: 0, sentenceCount: 1) else {
			return nil
		}
		self.reason = sentences[0]
	}
	
    public func execute(on lobby: TASServerLobby) {}
	
	var payload: String {
		return reason
	}
}


/**
Sent in response to a REGISTER command, if registration has been accepted.

If email verification is enabled, sending of this command notifies that the server has sent a verification code to the users email address. This verification code is expected back from the client in CONFIRMAGREEMENT

Upon reciept of this command, a lobby client would normally be expected to reply with a LOGIN attempt (but this is not a requirement of the protocol).
*/
struct SCRegistrationAcceptedCommand: SCCommand {

    static let title = "REGISTRATIONACCEPTED"
	
	// MARK: Manual Construction
	
	init() {}
	
	// MARK: SCCommand
	
	init?(payload: String) {}
	
    public func execute(on lobby: TASServerLobby) {}
	
	var payload: String { return "" }
}


struct SCLoginInfoEndCommand: SCCommand {

    static let title = "LOGININFOEND"
	
	// MARK: Manual Construction
	
	init() {
	}
	
	// MARK: SCCommand
	
	init?(payload: String) {
	}
	
    public func execute(on lobby: TASServerLobby) {

    }
	
	var payload: String { return "" }
}


struct SCAgreementCommand: SCCommand {

    static let title = "AGREEMENT"
	
	let agreement: String
	
	// MARK: Manual Construction
	
	init(agreement: String) {
		self.agreement = agreement
	}
	
	// MARK: SCCommand
	
	init?(payload: String) {
		guard let (_, sentences) = try? wordsAndSentences(for: payload, wordCount: 0, sentenceCount: 1) else {
			return nil
		}
		self.agreement = sentences[0]
	}
	
    public func execute(on lobby: TASServerLobby) {
        let preAgreementSession: PreAgreementSession

        switch lobby.session {
        case let .preAgreement(session):
            preAgreementSession = session
            preAgreementSession.agreement += "\n" + agreement
        default:
            preAgreementSession = PreAgreementSession(lobby: MakeUnownedQueueLocked(lockedObject: lobby, queue: lobby.connection.queue))
            lobby.session = .preAgreement(preAgreementSession)

            preAgreementSession.agreement = agreement
        }
    }
	
	var payload: String {
		return agreement
	}
}


struct SCAgreementEndCommand: SCCommand {

    static let title = "AGREEMENTEND"
	
	// MARK: Manual Construction
	
	init() {
	}
	
	// MARK: SCCommand
	
	init?(payload: String) {
	}
	
    public func execute(on lobby: TASServerLobby) {
        guard case let .preAgreement(preAgreementSession) = lobby.session else {
            return
        }

        preAgreementSession.agreementComplete()
    }
	
	var payload: String { return "" }
}


struct SCChangeEmailRequestAcceptedCommand: SCCommand {

    static let title = "CHANGEEMAILREQUESTACCEPTED"
	
	// MARK: Manual Construction
	
	init() {
	}
	
	// MARK: SCCommand
	
	init?(payload: String) {
	}
	
    public func execute(on lobby: TASServerLobby) {}
	
	var payload: String { return "" }
}


struct SCChangeEmailRequestDeniedCommand: SCCommand {

    static let title = "CHANGEEMAILREQUESTDENIED"
	
	let errorMessage: String
	
	// MARK: Manual Construction
	
	init(errorMessage: String) {
		self.errorMessage = errorMessage
	}
	
	// MARK: SCCommand
	
	init?(payload: String) {
		guard let (_, sentences) = try? wordsAndSentences(for: payload, wordCount: 0, sentenceCount: 1) else {
			return nil
		}
		self.errorMessage = sentences[0]
	}
	
    public func execute(on lobby: TASServerLobby) {}
	
	var payload: String {
		return errorMessage
	}
}


struct SCChangeEmailAcceptedCommand: SCCommand {

    static let title = "CHANGEEMAILACCEPTED"
	
	// MARK: Manual Construction
	
	init() {
	}
	
	// MARK: SCCommand
	
	init?(payload: String) {
	}
	
    public func execute(on lobby: TASServerLobby) {}
	
	var payload: String { return "" }
}


struct SCChangeEmailDeniedCommand: SCCommand {

    static let title = "CHANGEEMAILDENIED"
	
	let errorMessage: String
	
	// MARK: Manual Construction
	
	init(errorMessage: String) {
		self.errorMessage = errorMessage
	}
	
	// MARK: SCCommand
	
	init?(payload: String) {
		guard let (_, sentences) = try? wordsAndSentences(for: payload, wordCount: 0, sentenceCount: 1) else {
			return nil
		}
		self.errorMessage = sentences[0]
	}
	
    public func execute(on lobby: TASServerLobby) {}
	
	var payload: String {
		return errorMessage
	}
}


struct SCResendVerificationAcceptedCommand: SCCommand {

    static let title = "RESENDVERIFICATIONACCEPTED"
	
	// MARK: Manual Construction
	
	init() {
	}
	
	// MARK: SCCommand
	
	init?(payload: String) {
		#warning("Should display some kind of success here")
	}

    /// Noop: this is a response and does not need an action.
    public func execute(on lobby: TASServerLobby) {}
	
	var payload: String { return "" }
}


struct SCResendVerificationDeniedCommand: SCCommand {

    static let title = "RESENDVERIFICATIONDENIED"
	
	let errorMessage: String
	
	// MARK: Manual Construction
	
	init(errorMessage: String) {
		self.errorMessage = errorMessage
	}
	
	// MARK: SCCommand
	
	init?(payload: String) {
		guard let (_, sentences) = try? wordsAndSentences(for: payload, wordCount: 0, sentenceCount: 1) else {
			return nil
		}
		self.errorMessage = sentences[0]
	}
	
    public func execute(on lobby: TASServerLobby) {}
	
	var payload: String {
		return errorMessage
	}
}

struct SCResetPasswordRequestAcceptedCommand: SCCommand {

    static let title = "RESETPASSWORDREQUESTACCEPTED"
	
	// MARK: Manual Construction
	
	init() {
	}
	
	// MARK: SCCommand
	
	init?(payload: String) {
	}
	
    public func execute(on lobby: TASServerLobby) {}
	
	var payload: String { return "" }
}

struct SCResetPasswordRequestDeniedCommand: SCCommand {

    static let title = "RESETPASSWORDREQUESTDENIED"
	
	let errorMessage: String
	
	// MARK: Manual Construction
	
	init(errorMessage: String) {
		self.errorMessage = errorMessage
	}
	
	// MARK: SCCommand
	
	init?(payload: String) {
		guard let (_, sentences) = try? wordsAndSentences(for: payload, wordCount: 0, sentenceCount: 1) else {
			return nil
		}
		self.errorMessage = sentences[0]
	}
	
    public func execute(on lobby: TASServerLobby) {}
	
	var payload: String {
		return errorMessage
	}
}


/**
 Notifies that client that their password was changed, in response to RESETPASSWORD. The new password will be emailed to the client.
*/
struct SCResetPasswordAcceptedCommand: SCCommand {

    static let title = "RESETPASSWORDACCEPTED"
	
	// MARK: Manual Construction
	
	init() {}
	
	// MARK: SCCommand
	
	init?(payload: String) {}
	
    public func execute(on lobby: TASServerLobby) {}
	
	var payload: String { return "" }
}


struct SCResetPasswordDeniedCommand: SCCommand {

    static let title = "RESETPASSWORDDENIED"
	
	let errorMessage: String
	
	// MARK: Manual Construction
	
	init(errorMessage: String) {
		self.errorMessage = errorMessage
	}
	
	// MARK: SCCommand
	
	init?(payload: String) {
		guard let (_, sentences) = try? wordsAndSentences(for: payload, wordCount: 0, sentenceCount: 1) else {
			return nil
		}
		errorMessage = sentences[0]
	}
	
    public func execute(on lobby: TASServerLobby) {}
	
	var payload: String {
		return errorMessage
	}
}

