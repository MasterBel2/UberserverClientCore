//
//  Channel.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 24/6/19.
//  Copyright © 2019 MasterBel2. All rights reserved.
//

import Foundation

public final class Channel {

    public let title: String
    public let userlist: ManualSublist<User>
	public var topic: String = ""
    /// Describes how the channel should send a message.
    private let sendAction: (Channel, String) -> ()

    public let messageList: List<ChatMessage>

    // MARK: - Lifecycle

    /**
     Creates a new channel.

     - parameter title: A human-readable string naming this channel.
     - parameter rootList: The parent list containing all users that may be added to this channel's userlist.
     - parameter sendAction: A block that should implement the functionality of sending the message.
     */
    public init(title: String, rootList: List<User>, sendAction: @escaping (Channel, String) -> ()) {
        topic = title
        self.title = title
        self.sendAction = sendAction
        userlist = ManualSublist<User>(parent: rootList)
        messageList = List<ChatMessage>()
    }

    // MARK: - Messages

    private var messageCount = 0

    public func receivedNewMessage(_ message: ChatMessage) {
        messageList.addItem(message, with: messageCount)
        messageCount = messageCount + 1
    }

    /// Sends a message in this battle.
    ///
    /// The precise method of sending in a message is specified in the instance's `sendAction` property, which is provided in the initialiser.
    public func send(_ message: String) {
        sendAction(self, message)
    }
}
