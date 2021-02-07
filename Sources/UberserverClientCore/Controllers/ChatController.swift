//
//  ChatController.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 25/11/19.
//  Copyright © 2019 MasterBel2. All rights reserved.
//

import Foundation

/// Controls the model associated with channel and private messaging, and associated functionality.
public final class ChatController {

    /// The server the controller is associated with.
    public weak var server: TASServer?
    /// The client the controller is associated with.
    public weak var client: Client?
    /// Provides an API for the user interface associated with this 
    public let windowManager: ClientWindowManager

	/// A local cache of information about channels listed by the server.
    public internal(set) var channels: [ChannelSummary] = []

	/// Contains metadata describing channels listed by the server.
    public struct ChannelSummary {
        let title: String
        let description: String
        let members: String
        let isPrivate: Bool
    }

    public init(windowManager: ClientWindowManager) {
        self.windowManager = windowManager
    }

	/// Instructs the server to ring another user.
    public func ring(_ id: Int) {
		guard let client = client,
			  let recipient = client.userList.items[id],
			  let server = server else { return }
		server.send(CSRingCommand(target: recipient.profile.fullUsername))
	}

    public func sendMessage(_ message: String, toChannelNamed channelName: String) {
        server?.send(CSSayCommand(channelName: channelName, message: message))
    }

	/// Sends a private message to the user.
    public func sendPrivateMessage(_ message: String, toUserIdentifiedBy id: Int) {
        guard let client = client,
              let recipient = client.userList.items[id],
              let server = server else { return }
        server.send(CSSayPrivateCommand(intendedRecipient: recipient.profile.fullUsername, message: message))
    }

	/// [Verifies the intent, and] instructs the server to add a user to the ignore list.
    public func ignoreUser(_ id: Int) {
        // 1. Present a prompt asking for a reason ???? Should this be delegated somewhere else?

        // 2. Allow discarding of message and cancelling of the ignore action on

        // 3. Send message on prompt completion
    }

	/// Removes a user from the list of ignored users.
    public func unignoreUser(_ id: Int) {
		// TODO
    }

	/// Presents a menu to display a list of channels that may be joined.
    public func presentJoinChannelMenu() {
        // TODO (Consider delegating this elsewhere. We should only care about updating the list of channels here.)
    }

	/// Sends a message to the server requesting to join a channel.
	///
	/// If the listed channel is private, a prompt will be presented indicating that a password is required.
    public func joinChannel(_ channelName: String) {
        if channels.first(where: { $0.title == channelName })?.isPrivate == true {
            // TODO: Present a prompt
        }
        server?.send(CSJoinCommand(channelName: channelName, key: nil))
    }
}
