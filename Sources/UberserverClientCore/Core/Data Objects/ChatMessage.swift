//
//  ChatMessage.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 14/11/19.
//  Copyright © 2019 MasterBel2. All rights reserved.
//

import Foundation

/// A chat message received from another client in a channel or private message.
public final class ChatMessage: Sortable {

    init(time: Date, senderID: Int, senderName: String, content: String, isIRCStyle: Bool) {
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

    public enum PropertyKey {
        case time
    }

    public func relationTo(_ other: ChatMessage, forSortKey sortKey: ChatMessage.PropertyKey) -> ValueRelation {
        switch sortKey {
        case .time:
            // Reverse order, since we want the lowest time at the top, and the highest time at the bottom
            return ValueRelation(value1: other.time, value2: self.time)
        }
    }
}
