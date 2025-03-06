import Foundation

import ncurses

import ServerAddress
import UberserverClientCore



let dataDirectory = NSHomeDirectoryURL().appendingPathComponent(".spring", isDirectory: true)
let system = Linux()
let downloadController = DownloadController(system: system)
let replayController = ReplayController(dataDirectory: dataDirectory)
let archiveLoader = UnitsyncArchiveLoader(url: dataDirectory, system: system)
let resourceManager = ResourceManager(
    replayController: replayController, 
    remoteResourceFetcher: RemoteResourceFetcher(downloadController: downloadController),
    archiveLoader: archiveLoader
)

archiveLoader.load()

let client = Client(system: system, resourceManager: resourceManager)

let window = initscr()
noecho()
keypad(window, true)
timeout(500)

var shouldContinue = true
var notice = ""

func writeToScreen(_ string: String, attributes: CInt = 0) {
    attrset(attributes)
    for char in string {
        addch(UInt32(char.asciiValue ?? 0))
    }
    attrset(0)
}

protocol InputHandler {
    func handle(_ char: CInt)
    func writeAllToScreen()
}

class DefaultInputHandler: InputHandler {
    func handle(_ rawChar: CInt) {
        if (32...126).contains(rawChar) {
            let char = String(UnicodeScalar(UInt8(rawChar)))
            switch char {
            case "Q":
                shouldContinue = false
            case "C":
                if client.connection != nil {
                    client.disconnect()
                } else {
                    let textInputHandler = TextInputHandler(title: "Server Address", completionHandler: { address in         
                        currentInputHandler = DefaultInputHandler()
                        client.connect(to: ServerAddress(location: address, port: 8200), tls: false, defaultLobby: UnknownLobby())
                    })
                    textInputHandler.input = "170.64.140.123"
                    currentInputHandler = textInputHandler
                }
            case "A":
                if let connection = client.connection {
                    connection._connection.sync(block: { _connection in
                        if let tasLobby = _connection.lobby as? TASServerLobby,
                           case .preAgreement(let preAgreementSession) = tasLobby.session {
                            preAgreementSession.acceptAgreement(verificationCode: nil)
                        }
                    })
                }
            case "L":
                if let connection = client.connection {
                    connection._connection.sync(block: { _connection in
                        if let tasLobby = _connection.lobby as? TASServerLobby,
                            case .unauthenticated(let unauthenticatedSession) = tasLobby.session {
                            pendingAction = true
                            currentInputHandler = TextInputHandler(title: "Username", completionHandler: { username in
                                currentInputHandler = TextInputHandler(title: "Password", obscured: true, completionHandler: { password in
                                    currentInputHandler = DefaultInputHandler()
                                    unauthenticatedSession.submitLogin(username: username, password: password, completionHandler: { _ in
                                        pendingAction = false
                                    })
                                })
                            })
                        }
                    })
                }
            case "R":
                if let connection = client.connection {
                    connection._connection.sync(block: { _connection in
                        if let tasLobby = _connection.lobby as? TASServerLobby,
                            case .unauthenticated(let unauthenticatedSession) = tasLobby.session {
                            currentInputHandler = TextInputHandler(title: "Username", completionHandler: { username in
                                currentInputHandler = TextInputHandler(title: "Password", obscured: true, completionHandler: { password in
                                    currentInputHandler = TextInputHandler(title: "Confirm Password", obscured: true, completionHandler: { passwordConfirmation in
                                        guard password == passwordConfirmation else {
                                            notice = "Error: passwords do not match!"
                                            currentInputHandler = DefaultInputHandler()
                                            return
                                        }
                                        currentInputHandler = TextInputHandler(title: "Email", completionHandler: { email in
                                            if let emailAddress = try? EmailAddress.decode(from: email) {
                                                unauthenticatedSession.submitRegister(username: username, email: emailAddress, password: password, completionHandler: { result in
                                                    if let error = result {
                                                        notice = "Failed to register \(email) as \(username): \(error)"
                                                    } else {
                                                        notice = "Successfully registered \(email) as \(username)!"
                                                    }
                                                })
                                            } else {
                                                notice = "Error: \(email) is not a valid email address!"
                                            }
                                            currentInputHandler = DefaultInputHandler()
                                        })
                                    })
                                })
                            })
                        }
                    })
                }
            case "c":
                if let connection = client.connection {
                    connection._connection.sync(block: { _connection in
                        if let tasLobby = _connection.lobby as? TASServerLobby,
                            case .authenticated(let authenticatedSession) = tasLobby.session {
                            currentRoom = .Chat
                            selectedIndex = 0
                        }
                    })
                }
            case "b":
                if let connection = client.connection {
                    connection._connection.sync(block: { _connection in
                        if let tasLobby = _connection.lobby as? TASServerLobby,
                            case .authenticated(let authenticatedSession) = tasLobby.session {
                            currentRoom = .Battlelist
                            selectedIndex = 0
                        }
                    })
                }
            case "r":
                if let connection = client.connection {
                    connection._connection.sync(block: { _connection in
                        if let tasLobby = _connection.lobby as? TASServerLobby,
                            case .authenticated(let authenticatedSession) = tasLobby.session,
                            authenticatedSession.battleroom != nil {
                            currentRoom = .Battleroom
                        }
                    })
                }
            case "j":
                if let connection = client.connection {
                    connection._connection.sync(block: { _connection in
                        if let tasLobby = _connection.lobby as? TASServerLobby,
                            case .authenticated(let authenticatedSession) = tasLobby.session {
                            switch currentRoom {
                            case .Battlelist:
                                authenticatedSession.joinBattle(authenticatedSession.battleList.items.sorted(by: { $0.value.playerList.count - $0.value.spectatorCount > $1.value.playerList.count - $1.value.spectatorCount }).first!.key)
                            default:
                                break
                            }
                        }
                    })
                }
            default:
                break
            }
        }
        switch rawChar {
        case KEY_UP:
            selectedIndex = max(0, selectedIndex - 1)
        case KEY_DOWN:
            selectedIndex = selectedIndex + 1
        default:
            break
        }
    }

    enum Room: Equatable {
        case Chat
        case Battlelist
        case Battleroom
    }

    var currentRoom = Room.Chat
    var selectedIndex = 0

    func writeAllToScreen() {
        writeToScreen("(Q to quit)\r\n")

        if let connection = client.connection {
            connection._connection.sync(block: { _connection in
                writeToScreen("Connected to \(_connection.socket.address.description) (C to disconnect)\r\n")
                if let tasLobby = _connection.lobby as? TASServerLobby {
                    writeToScreen("TASSERVER | Last ping: \(tasLobby.lastPingTime.map({ "\($0 / 1000) ms" }) ?? "Unknown") | ")
                    switch tasLobby.session {
                    case .authenticated(let authenticatedSession):
                        writeToScreen("Logged in as \(authenticatedSession.username)\r\n")
                        writeToScreen("Chat (c)", attributes: currentRoom == .Chat ? 1 << (8 + 13) : 0)
                        writeToScreen(" | ")
                        writeToScreen("Battlelist (b)", attributes: currentRoom == .Battlelist ? 1 << (8 + 13) : 0)
                        if authenticatedSession.battleroom != nil {
                            writeToScreen(" | ")
                            writeToScreen("Battleroom (r)", attributes: currentRoom == .Battleroom ? 1 << (8 + 13) : 0)
                        }

                        writeToScreen("\r\n\n")

                        switch currentRoom {
                        case .Chat:
                            writeToScreen("We'll get to this later!")
                        case .Battleroom:
                            if authenticatedSession.battleroom == nil {
                                writeToScreen("You've left the battleroom!\r\n")
                                fallthrough
                            } else {
                            }
                        case .Battlelist:
                            writeToScreen("\(authenticatedSession.battleList.items.count) battle(s)\r\n")
                            for (index, battle) in authenticatedSession.battleList.items.map({ $0.value }).sorted(by: { $0.playerList.count - $0.spectatorCount > $1.playerList.count - $0.spectatorCount }).enumerated() {
                                writeToScreen("\(index == selectedIndex ? "[j]" : "[ ]") \(battle.title) - \(battle.mapIdentification.name) | \(battle.userList.items.count)/\(battle.maxPlayers) players | \(battle.spectatorCount) spectators\r\n", attributes: index == selectedIndex ? 1 << (8 + 13) : 0)
                            }
                        }
                    case .unauthenticated(let unauthenticatedSession):
                        writeToScreen("Login required (L to login) (R to register)\r\n")
                    case .preAgreement(let preAgreementSession):
                        writeToScreen("EULA approval required (A to agree)\r\n")
                    case .none:
                        break
                    }
                } else {
                    writeToScreen("Unknown Protocol")
                }
            })
        } else {
            writeToScreen("Not Connected! (C to connect)")
        }
    }
}

class TextInputHandler: InputHandler {
    var obscured = false
    let title: String
    var input: String = ""
    let completionHandler: (String) -> Void
    
    init(title: String, obscured: Bool = false, completionHandler: @escaping (String) -> Void) {
        self.title = title
        self.obscured = obscured
        self.completionHandler = completionHandler
    }

    func handle(_ char: CInt) {
        switch char {
        case KEY_BACKSPACE:
            guard input.count > 0 else { return }
            input.removeLast()
        case KEY_ENTER, 10 /* ascii LF */:
            completionHandler(input)
        case 32...126:
            input.append(String(UnicodeScalar(UInt8(char)))) 
        default:
            break
        }
    }

    var description: String {
        return "\(title): \(obscured ? String(repeating: "*", count: input.count) : input)"
    }

    func writeAllToScreen() {
        writeToScreen(description)    
    }
}

var currentInputHandler: InputHandler = DefaultInputHandler()
var pendingAction = false

while shouldContinue {
    // Redraw the screen

    erase()

    move(0, 0) 

    currentInputHandler.writeAllToScreen()

    writeToScreen("\r\n\n\(notice)")

    refresh()
    
    let char = getch()
    if char > 0 {
        notice = ""
        currentInputHandler.handle(char)
    }
}

endwin()
