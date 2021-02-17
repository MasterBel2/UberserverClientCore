//
//  Client.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 8/9/19.
//  Copyright © 2019 MasterBel2. All rights reserved.
//

import Foundation
import ServerAddress

/**
 An object that at an abstract level represents a client between a user and the server.

 A client handles the top-level data and windows associated with a client-server connection, as well as handling the outputting of commands back to the server.

 Updates received from the server are processed by instances of the SCServerCommand protocol. The Client object simply manages the interactions between its various components as needed.
 */
public final class Client {

    // MARK: - Delegating tasks

    /// Provides platform-specific windows.
    public let windowManager: ClientWindowManager

    // MARK: - Server

    public private(set) var server: TASServer?
    var featureAvailability: ProtocolFeatureAvailability?
    /// Processes chat-related information directed back towards the server

    // MARK: - Controlling specific data & interactions

    /// The user's preferences controller.
    public let preferencesController: PreferencesController
    public let chatController: ChatController
	public let battleController: BattleController
    public let accountInfoController = AccountInfoController()
    /// The server.
    public let userAuthenticationController: UserAuthenticationController
    
    // MARK: - Actions
    
    private lazy var withAddressInitialiseServer: (ServerAddress) -> Void = { [weak self] serverAddress in
        self?.initialiseServer(serverAddress)
    }

    // MARK: - Data

    /// Returns the User object associated with the account the client has connected to the server with.
    var connectedAccount: User? {
        guard let username = userAuthenticationController.credentials?.username,
        let userID = id(forPlayerNamed: username) else {
            return nil
        }
        return userList.items[userID]
    }

    public let channelList = List<Channel>(title: "All Channels", sortKey: .title)
    public let privateMessageList = List<Channel>(title: "Private Messages", sortKey: .title)
    public let forwardedMessageList = List<Channel>(title: "Forwarded Messages", sortKey: .title)
    public let userList = List<User>(title: "All Users", sortKey: .rank)
    public let battleList = List<Battle>(title: "All Battles", sortKey: .playerCount)

    // MARK: - Lifecycle


    public init(windowManager: ClientWindowManager, preferencesController: PreferencesController, address: ServerAddress? = nil, springProcessController: SpringProcessController) {

        // Initialise values

        self.windowManager = windowManager
        self.preferencesController = preferencesController

        self.userAuthenticationController = UserAuthenticationController(preferencesController: preferencesController)
        self.battleController = BattleController(battleList: battleList, windowManager: windowManager, springProcessController: springProcessController)
        self.chatController = ChatController(windowManager: windowManager)

        // Configuration

        windowManager.configure(for: self)

        chatController.client = self
        accountInfoController.client = self
        userAuthenticationController.client = self

        // Initialise server
        if let address = address {
            initialiseServer(address)
        }
    }

    func reset() {
        channelList.clear()
        userList.clear()
        battleList.clear()

        windowManager.resetServerWindows()

        userAuthenticationController.reset()

        chatController.channels = []
        battleController.battleroom = nil
        accountInfoController.invalidate()

        server?.disconnect()
        server = nil

        windowManager.selectServer(completionHandler: withAddressInitialiseServer)
    }

    // MARK: - Interacting with the server client

    /// Disconnects from the current server and connects to a new one.
	func redirect(to address: ServerAddress) {
        if let server = server {
            server.redirect(to: address)
        } else {
            initialiseServer(address)
        }
		#warning("Pass information to the user!")
	}
	
	public func initialiseServer(_ address: ServerAddress) {
        let server = TASServer(address: address, client: self)
		
        chatController.server = server
        battleController.server = server

        server.connect()
		
		self.server = server
	}

    // MARK: - Window

    /// 
    func createAndShowWindow() {
        windowManager.presentInitialWindow()
        if server == nil {
            windowManager.selectServer(completionHandler: withAddressInitialiseServer)
        }
    }

    // MARK: - Presenting information

    /// Presents a login control to the user.
    func presentLogin() {
        windowManager.presentLogin(controller: userAuthenticationController)
    }

    /// Handles an error from the server.
    func receivedError(_ error: ServerError) {
        switch error {
		default:
            Logger.log("\(error)", tag: .ServerError)
//            fatalError()
			#warning("FIXME")
        }
    }

    func didReceiveMessageFromServer(_ message: String) {
        if message.hasPrefix("Registration date:") {
            let components = message.components(separatedBy: " ")
            guard components.count >= 6 else {
                accountInfoController.setRegistrationDate(.none)
                return
            }
            let dateString = components[2..<5].joined(separator: " ")
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM DD, YYYY"
            guard let date = dateFormatter.date(from: dateString) else { return }
            accountInfoController.setRegistrationDate(date)
        } else if message.hasPrefix("Email address:") {
            let components = message.components(separatedBy: " ")
            if components.count == 3,
                components[2] != "",
                components[2] != "None" {
                accountInfoController.setEmail(components[2])
            } else {
                accountInfoController.setEmail("No email provided")
            }
        } else if message.hasPrefix("Ingame time:") {
            let ingameTimeString = message.components(separatedBy: " ")[2]
            guard let ingameTime = Int(ingameTimeString) else { return }
            accountInfoController.setIngameHours(ingameTime)
        }
    }

    // MARK: - Helpers

    var myID: Int? {
        if let myUsername = userAuthenticationController.credentials?.username {
            return id(forPlayerNamed: myUsername)
        }
        return nil
    }

    /// Returns ID of a player, if they are online.
    func id(forPlayerNamed username: String) -> Int? {
        return userList.items.first { (_, user) in
            return user.profile.fullUsername.lowercased() == username.lowercased()
        }?.key
    }

    /// The unique integer ID of channels, keyed by their name.
	private var channelIDs: [String : Int] = [:]
    /// Retrieves the unique integer ID for a channel.
	func id(forChannelnamed channelName: String) -> Int {
		if let id = channelIDs[channelName] {
			return id
		} else {
			let id = channelIDs.count
			channelIDs[channelName] = id
			return id
		}
	}

    func privateMessageChannel(withUserNamed username: String, userID: Int) -> Channel? {
        guard let myID = myID else { return nil }

        let channelID = id(forChannelnamed: username)
        
        let channel: Channel
        if let cachedChannel = privateMessageList.items[channelID] {
            channel = cachedChannel
        } else {
            channel = Channel(title: username, rootList: userList)
            channel.userlist.addItemFromParent(id: userID)
            channel.userlist.addItemFromParent(id: myID)

            privateMessageList.addItem(channel, with: channelID)
        }
        return channel
    }
}