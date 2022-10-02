//
//  PreAgreementSession.swift
//  UberserverClientCore
//
//  Created by MasterBel2 on 12/5/2022.
//

import Foundation

public protocol RecievesPreAgreementSessionUpdates: AnyObject {
    func preAgreementSession(_ session: PreAgreementSession, didReceiveAgreement agreement: String)

    func asAnyRecievesPreAgreementSessionUpdates() -> AnyRecievesPreAgreementSessionUpdates
}

public extension RecievesPreAgreementSessionUpdates {
    func asAnyRecievesPreAgreementSessionUpdates() -> AnyRecievesPreAgreementSessionUpdates {
        return AnyRecievesPreAgreementSessionUpdates(wrapping: self)
    }
}

public final class AnyRecievesPreAgreementSessionUpdates: RecievesPreAgreementSessionUpdates, Box {
    public let wrapped: RecievesPreAgreementSessionUpdates
    public var wrappedAny: AnyObject {
        return wrapped
    }

    public init(wrapping: RecievesPreAgreementSessionUpdates) {
        self.wrapped = wrapping
    }

    public func preAgreementSession(_ session: PreAgreementSession, didReceiveAgreement agreement: String) {
        wrapped.preAgreementSession(session, didReceiveAgreement: agreement)
    }

    public func asAnyRecievesPreAgreementSessionUpdates() -> AnyRecievesPreAgreementSessionUpdates {
        return self
    }
}

final public class PreAgreementSession: UpdateNotifier {

    public var objectsWithLinkedActions: [AnyRecievesPreAgreementSessionUpdates] = []

    private let lobby: UnownedQueueLocked<TASServerLobby>

    init(lobby: UnownedQueueLocked<TASServerLobby>) {
        self.lobby = lobby
    }

    var agreement: String = ""

    func agreementComplete() {
        applyActionToChainedObjects({ $0.preAgreementSession(self, didReceiveAgreement: agreement) })
    }

    public func acceptAgreement(verificationCode: String?) {
        lobby.async(block: { $0.object?.send(CSConfirmAgreementCommand(verificationCode: verificationCode)) })
    }
}
