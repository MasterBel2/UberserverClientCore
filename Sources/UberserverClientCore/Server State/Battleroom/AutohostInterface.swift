import NIO
import Foundation

open class AutohostInterface: TCPClientDelegate {
    public init() {}

    private (set) var socket: TCPClient<UDPMessage>?

    public func open(port: Int) throws -> Int {
        let socket = try TCPClient<UDPMessage>.runUDP(host: "localhost", port: port, delegate: self)
        self.socket = socket // Allow assigning port 0
        return socket.channel.localAddress!.port!

        print("Autohost interface: opened socket!")
    }

    public func close() {
        socket?.stop()
        socket = nil
    }

    func socketError(_ error: Error) {
        close()
    }

    func received(_ data: Data) {
        
    }

    open func serverStarted() { print("Server started!") }
    open func serverQuit() {}
    open func gameStarted(gameID: [UInt8], demoName: String?) {}
    open func gameOver(winningAllyTeams: [Int]) {}
    open func message(_ message: String) {}
    open func warning(_ message: String) {}
    open func playerJoined(_ playerNumber: Int, playerName: String) {}
    open func playerLeft(_ playerNumber: Int) {}
    open func playerReady(playerNumber: Int, isReady: Bool) {}
    open func playerChat(_ playerNumber: Int, destination: PlayerChatDestination, message: String) {}
    open func playerDefeated(_ playerNumber: Int) {}
    open func luaMessage(_ message: String) {}

    public func sendChatMessage(_ message: String) {}

    public enum PlayerChatDestination {}
}

protocol AutohostInterfaceMessage {
    static var id: u_char { get }
    init(dataParser: DataParser) throws

    func execute(on autohostInterface: AutohostInterface)
}

public extension AutohostInterface {
    struct ServerStarted: AutohostInterfaceMessage {
        static let id: u_char = 0

        init(dataParser: DataParser) throws {}

        func execute(on autohostInterface: AutohostInterface) {
            // TODO: Cache address for chat messages - will likely require adjustments to Socket class (currently the class called TCPClient)
            autohostInterface.serverStarted()
        }
    }

    struct ServerQuit: AutohostInterfaceMessage {
        static let id: u_char = 1

        init(dataParser: DataParser) throws {}

        func execute(on autohostInterface: AutohostInterface) {
            autohostInterface.serverQuit()
        }

        enum DecodeError: Error {
            case messageSize(parserError: Error)
            case gameID(parserError: Error)
        }
    }

    struct StartPlaying: AutohostInterfaceMessage {
        static var id: u_char = 2

        let gameID: [UInt8]
        let demoName: String?

        init(dataParser: DataParser) throws {
            let messageSize: UInt32

            do {
                messageSize = try dataParser.parseData(ofType: UInt32.self)
            } catch {
                throw DecodeError.messageSize(parserError: error)
            }

            do {
                gameID = try dataParser.parseData(ofType: UInt8.self, count: 16)
            } catch {
                throw DecodeError.gameID(parserError: error)
            }

            let demoNameLength = Int(messageSize) - (MemoryLayout.size(ofValue: messageSize) + MemoryLayout<UInt8>.size * 16 /* gameID */)
            if demoNameLength == 0 {
                demoName = nil
            } else {
                do {
                    let demoNameData = try dataParser.parseData(ofType: CChar.self, count: demoNameLength)
                    demoName = String(cString: demoNameData, encoding: .utf8)
                } catch {
                    throw DecodeError.gameID(parserError: error)
                }   
            }
        }

        func execute(on autohostInterface: AutohostInterface) {
            autohostInterface.gameStarted(gameID: gameID, demoName: demoName)
        }

        enum DecodeError: Error {
            case messageSize(parserError: Error)
            case gameID(parserError: Error)
        }
    }

    struct GameOver: AutohostInterfaceMessage {

        static var id: u_char = 3
        let playerNumber: u_char
        let winningAllyTeams: [u_char]

        init(dataParser: DataParser) throws {
            let messageSize: UInt8

            do {
                messageSize = try dataParser.parseData(ofType: UInt8.self)
            } catch {
                throw DecodeError.messageSize(parserError: error)
            }

            do {
                playerNumber = try dataParser.parseData(ofType: u_char.self)
            } catch {
                throw DecodeError.playerNumber(parserError: error)
            }

            let winningALlyTeamsLength = Int(messageSize) - (MemoryLayout.size(ofValue: messageSize) + MemoryLayout.size(ofValue: playerNumber))
            do {
                winningAllyTeams = try dataParser.parseData(ofType: u_char.self, count: winningALlyTeamsLength)
            } catch {
                throw DecodeError.winningAllyTeams(parserError: error)
            }
        }

        func execute(on autohostInterface: AutohostInterface) {}

        enum DecodeError: Error {
            case messageSize(parserError: Error)
            case playerNumber(parserError: Error)
            case winningAllyTeams(parserError: Error)
        }
    }

    struct Message: AutohostInterfaceMessage {
        static var id: u_char = 4
        let message: String

        init(dataParser: DataParser) throws {
            let messageLength = dataParser.data[dataParser.currentIndex].distance(to: 0)
            
            guard let message = String(cString: try dataParser.parseData(ofType: CChar.self, count: messageLength), encoding: .utf8) else {
                throw DecodeError.messageDecode
            }
            self.message = message
        }

        enum DecodeError: Error {
            case messageDecode
        }

        func execute(on autohostInterface: AutohostInterface) {}
    }

    struct Warning: AutohostInterfaceMessage {
        static var id: u_char = 5

        let message: String

        init(dataParser: DataParser) throws {
            let messageLength = dataParser.data[dataParser.currentIndex].distance(to: 0)
            
            guard let message = String(cString: try dataParser.parseData(ofType: CChar.self, count: messageLength), encoding: .utf8) else {
                throw DecodeError.messageDecode
            }
            self.message = message
        }

        enum DecodeError: Error {
            case messageDecode
        }

        func execute(on autohostInterface: AutohostInterface) {}
    }

    struct PlayerJoined: AutohostInterfaceMessage {
        static var id: u_char = 10
        let playerNumber: u_char 
        let playerName: String

        init(dataParser: DataParser) throws {

            let messageSize: UInt8

            do {
                messageSize = try dataParser.parseData(ofType: UInt8.self)
            } catch {
                throw DecodeError.messageSize(parserError: error)
            }

            do {
                playerNumber = try dataParser.parseData(ofType: u_char.self)
            } catch {
                throw DecodeError.playerNumber(parserError: error)
            }

            let nameLength = Int(messageSize) - (MemoryLayout.size(ofValue: messageSize) + MemoryLayout.size(ofValue: playerNumber))
            do {
                let playerNameData = try dataParser.parseData(ofType: CChar.self, count: nameLength)
                guard let playerName = String(cString: playerNameData, encoding: .utf8) else {
                    throw DecodeError.playerNameDecode
                }
                self.playerName = playerName
            } catch {
                throw DecodeError.playerName(parserError: error)
            }
        }

        func execute(on autohostInterface: AutohostInterface) {}

        enum DecodeError: Error {
            case messageSize(parserError: Error)
            case playerNumber(parserError: Error)
            case playerName(parserError: Error)
            case playerNameDecode
        }
    }

    struct PlayerLeft: AutohostInterfaceMessage {
        static var id: u_char = 11
        let playerNumber: u_char
        let reason: u_char

        init(dataParser: DataParser) throws {
            playerNumber = try dataParser.parseData(ofType: u_char.self)
            reason = try dataParser.parseData(ofType: u_char.self)
        }

        func execute(on autohostInterface: AutohostInterface) {}
    }

    struct PlayerReady: AutohostInterfaceMessage {
        static var id: u_char = 12

        let playerNumber: u_char
        let readyState: u_char

        init(dataParser: DataParser) throws {
            playerNumber = try dataParser.parseData(ofType: u_char.self)
            readyState = try dataParser.parseData(ofType: u_char.self)
        }

        func execute(on autohostInterface: AutohostInterface) {}
    }

    struct PlayerChat: AutohostInterfaceMessage {
        static var id: u_char = 13

        let playerNumber: u_char
        let destination: u_char
        let message: String

        init(dataParser: DataParser) throws {
            playerNumber = try dataParser.parseData(ofType: u_char.self)
            destination = try dataParser.parseData(ofType: u_char.self)
            
            let messageLength = dataParser.data[dataParser.currentIndex].distance(to: 0)
            
            guard let message = String(cString: try dataParser.parseData(ofType: CChar.self, count: messageLength), encoding: .utf8) else {
                throw DecodeError.messageDecode
            }
            self.message = message
        }

        func execute(on autohostInterface: AutohostInterface) {}

        enum DecodeError: Error {
            case messageDecode
        }
    }

    struct PlayerDefeated: AutohostInterfaceMessage {
        static var id: u_char = 14
        let playerNumber: u_char

        init(dataParser: DataParser) throws {
            playerNumber = try dataParser.parseData(ofType: u_char.self)
        }

        func execute(on autohostInterface: AutohostInterface) {}
    }

    struct LuaMessage: AutohostInterfaceMessage {
        static var id: u_char = 20

        let message: String

        init(dataParser: DataParser) throws {
            let messageLength = dataParser.data[dataParser.currentIndex].distance(to: 0)
            
            guard let message = String(cString: try dataParser.parseData(ofType: CChar.self, count: messageLength), encoding: .utf8) else {
                throw DecodeError.messageDecode
            }
            self.message = message
        }

        enum DecodeError: Error {
            case messageDecode
        }

        func execute(on autohostInterface: AutohostInterface) {}
    }

    struct TeamStat: AutohostInterfaceMessage {
        static var id: u_char = 60
        let teamNumber: UInt8
        let stats: TeamStats

        init(dataParser: DataParser) throws {
            teamNumber = try dataParser.parseData(ofType: UInt8.self)
            stats = try dataParser.parseData(ofType: TeamStats.self)   
        }

        func execute(on autohostInterface: AutohostInterface) {}
    }
}

struct TeamStats {
    let frame: CInt
    let metalUsed: CFloat
    let metalProduced: CFloat
    let energyProduced: CFloat
    let metalExcess: CFloat
    let energyExcess: CFloat
    /* received from allies */
    let metalReceived: CFloat
    let energyReceived: CFloat
    /* sent to allies */
    let metalSent: CFloat
    let energySent: CFloat
    let damageDealt: CFloat
    let damageReceived: CFloat
    let unitsProduced: CInt
    let unitsDied: CInt
    let unitsReceived: CInt
    let unitsSent: CInt
    /* units captured from enemy by us */
    let unitsCaptured: CInt
    /* units captured from us by enemy */
    let unitsOutCaptured: CInt
    /* how many enemy units have been killed by this teams units */
    let unitsKilled: CInt
}