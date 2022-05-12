//
//  PreAgreementSession.swift
//  UberserverClientCore
//
//  Created by MasterBel2 on 12/5/2022.
//

import Foundation

public protocol RecievesPreAgreementSessionUpdates {
    func preAgreementSession(_ session: PreAgreementSession, didReceiveAgreement agreement: String)
}

final public class PreAgreementSession: UpdateNotifier {

    public var objectsWithLinkedActions: [() -> RecievesPreAgreementSessionUpdates?] = []

    private let connection: UnownedQueueLocked<ThreadUnsafeConnection>

    init(connection: UnownedQueueLocked<ThreadUnsafeConnection>) {
        self.connection = connection
    }

    var agreement: String = ""

    func agreementComplete() {
        applyActionToChainedObjects({ $0.preAgreementSession(self, didReceiveAgreement: agreement) })
    }

    public func acceptAgreement(verificationCode: String?) {
        connection.async(block: { $0.object?.send(CSConfirmAgreementCommand(verificationCode: verificationCode)) })
    }
}
