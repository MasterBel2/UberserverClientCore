import SpringRTSStartScriptHandling
import ServerAddress

public class HostAPI: ListDelegate {
    init(session: AuthenticatedSession, engine: Engine, mapArchive: QueueLocked<UnitsyncMapArchive>, gameArchive: QueueLocked<UnitsyncModArchive>) {
        self.session = session
        self.mapArchive = mapArchive
        self.gameArchive = gameArchive
        self.engine = engine
    }

    public let engine: Engine
    public let gameArchive: QueueLocked<UnitsyncModArchive>
    public private(set) var mapArchive: QueueLocked<UnitsyncMapArchive>
    private weak var session: AuthenticatedSession?
    internal weak var battleroom: Battleroom? {
        didSet { // Set once directly after creation. Should not be mutated. 
            battleroom?.spectatorList.data.addObject(self.asAnyListDelegate())
        }
    }

    public func kickPlayer(id: Int) {
        guard let username = session?.battleroom?.battle.userList.items[id]?.profile.fullUsername else {
            return
        }
        session?.lobby.send(CSKickFromBattleCommand(username: username))
    }
    public func forceSpectatePlayer(id: Int) {
        guard let username = session?.battleroom?.battle.userList.items[id]?.profile.fullUsername else {
            return
        }
        session?.lobby.send(CSForceSpectatorModeCommand(username: username))
    }
    public func force(player id: Int, toAllyTeam allyTeam: Int) {
        guard let username = session?.battleroom?.battle.userList.items[id]?.profile.fullUsername else {
            return
        }
        session?.lobby.send(CSForceAllyNumberCommand(username: username, allyNumber: allyTeam))
    }
    public func force(player id: Int, toTeam teamNumber: Int) {
        guard let username = session?.battleroom?.battle.userList.items[id]?.profile.fullUsername else {
            return
        }
        session?.lobby.send(CSForceTeamNumberCommand(username: username, teamNumber: teamNumber))
    }

    public func addStartRect(_ startRect: StartRect, forAllyTeam allyNumber: Int) {
        session?.lobby.send(CSAddStartRectCommand(allyNumber: allyNumber, rect: startRect))
    }

    public func removeStartRect(forAllyTeam allyNumber: Int) {
        session?.lobby.send(CSRemoveStartRectCommand(allyNumber: allyNumber))
    }

    public func setMap(_ newMapArchive: QueueLocked<UnitsyncMapArchive>) {
        guard let battleroom = battleroom, let session = session else { return }
        
        let (mapName, mapHash) = newMapArchive.sync(block: { _mapArchive -> (String, Int32) in
            return (_mapArchive.name, _mapArchive.completeChecksum)
        })
        
        session.lobby.send(CSUpdateBattleInfoCommand(
            spectatorCount: battleroom.spectatorList.items.count, 
            locked: battleroom.battle.isLocked, 
            mapName: mapName,
            mapHash: mapHash
        ))

        self.mapArchive = newMapArchive
    }

        // MARK: - User Actions

    // MARK: - ReceivesBattleroomUpdates

    public func list(_ list: List<User>, didAdd item: User, identifiedBy id: Int) {
        guard let battleroom = battleroom, list === battleroom.spectatorList else { return }
        session?.lobby.send(CSUpdateBattleInfoCommand(
            spectatorCount: list.items.count, 
            locked: battleroom.battle.isLocked, 
            mapName: battleroom.battle.mapIdentification.name, 
            mapHash: battleroom.battle.mapIdentification.hash
        ))
    }
    public func list(_ list: List<User>, didRemoveItemIdentifiedBy id: Int) {
        guard let battleroom = battleroom, list === battleroom.spectatorList else { return }
        session?.lobby.send(CSUpdateBattleInfoCommand(
            spectatorCount: list.items.count, 
            locked: battleroom.battle.isLocked, 
            mapName: battleroom.battle.mapIdentification.name, 
            mapHash: battleroom.battle.mapIdentification.hash
        ))
    }

    public func list(_ list: List<User>, itemWithIDWasUpdated id: Int) {}
    public func listWillClear(_ list: List<User>) {}
}