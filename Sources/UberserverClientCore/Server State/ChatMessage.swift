//
//  ChatMessage.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 14/11/19.
//  Copyright © 2019 MasterBel2. All rights reserved.
//

import Foundation

/// A chat message received from another client in a channel or private message.
public final class ChatMessage {

    public init(time: Date, senderID: Int, senderName: String, content: String, isIRCStyle: Bool) {
        self.time = time
        self.senderID = senderID
        self.content = content
        self.isIRCStyle = isIRCStyle
        self.senderName = senderName
    }

    public let time: Date
    /// UserID of the message sender.
    public let senderID: Int
    /// Username of the sender. Used as a fallback when a user disconnects.
    public let senderName: String
    public let content: String
    public let isIRCStyle: Bool
}
