# UberserverClientCore

A Swift implementation of the common functionality required for multiplayer lobby clients connecting to implementations of the [Spring Lobby Protocol](https://springrts.com/dl/LobbyProtocol/ProtocolDescription.html). 

This project is primarily experiemental, and as such has been prioritising exploration over completeness. Contact [MasterBel2](https://github.com/MasterBel2) if you wish to make use of this project, and require any guidance or further functionality, he will be more than happy to help you out.

## Structure

The implementation is based around the concept of a [`Client`](https://github.com/MasterBel2/UberserverClientCore/blob/master/Sources/UberserverClientCore/Application%20Structure/Client.swift), which may initiate a connection to a server. See a diagram below:

```
 Client
    |
 Connection?
    |
AutheticatedSession or UnauthenticatedSession (default)
    |                             |
(Information about server     (Implements login + register
state, login credentials,     functionality.)
etc.)
```

When connected to a server, a client will own a [`Connection`](https://github.com/MasterBel2/UberserverClientCore/blob/master/Sources/UberserverClientCore/Server/Connection.swift). By default a connection maintains an [`UnauthenticatedSession`](https://github.com/MasterBel2/UberserverClientCore/blob/master/Sources/UberserverClientCore/Account/UnauthenticatedSession.swift), which allows the client to log in or register. When logged in the connection will maintain an [`AuthenticatedSession`](https://github.com/MasterBel2/UberserverClientCore/blob/master/Sources/UberserverClientCore/Server%20State/AuthenticatedSession.swift) which contains all information about the server state, including the [battle list](https://github.com/MasterBel2/UberserverClientCore/blob/master/Sources/UberserverClientCore/Server%20State/AuthenticatedSession.swift#L50), [user list](https://github.com/MasterBel2/UberserverClientCore/blob/master/Sources/UberserverClientCore/Server%20State/AuthenticatedSession.swift#L48), an optional battleroom, [battleroom](https://github.com/MasterBel2/UberserverClientCore/blob/master/Sources/UberserverClientCore/Server%20State/AuthenticatedSession.swift#L53), and a [channel list](https://github.com/MasterBel2/UberserverClientCore/blob/master/Sources/UberserverClientCore/Server%20State/AuthenticatedSession.swift#L42). It also contains information about the account the client used to authenticate, such as its [username](https://github.com/MasterBel2/UberserverClientCore/blob/master/Sources/UberserverClientCore/Server%20State/AuthenticatedSession.swift#L35).

## Implementing your custom client

Your lobby client should create a `Client` object for each `Connection` they wish to create, and connect using [`Client.connect(to serverAddress:)`](https://github.com/MasterBel2/UberserverClientCore/blob/master/Sources/UberserverClientCore/Application%20Structure/Client.swift#L75). Most major data stores conform to [`UpdateNotifier`](https://github.com/MasterBel2/UberserverClientCore/blob/master/Sources/UberserverClientCore/Utility/UpdateNotifier.swift). `UpdateNotifier` will inform associated objects . Add an associated object with [`addObject(_:)`](https://github.com/MasterBel2/UberserverClientCore/blob/master/Sources/UberserverClientCore/Utility/UpdateNotifier.swift#L24).

[See here for an example implementation.](https://github.com/MasterBel2/BelieveAndRise)

## Relevant data

Various other systems (such as downloading resources and launching games) are implemented in this package.
- For downloading, and downloaded assets, see [`ResourceManager`](https://github.com/MasterBel2/UberserverClientCore/blob/master/Sources/UberserverClientCore/Resources/ResourceManager.swift). Battles are automatically integrated with this system, see [`Battle`](https://github.com/MasterBel2/UberserverClientCore/blob/master/Sources/UberserverClientCore/Server%20State/Battle.swift).
- For interacting with engines, see [`Engine`](https://github.com/MasterBel2/UberserverClientCore/blob/master/Sources/UberserverClientCore/Resources/Local/ArchiveLoader.swift#L105)
- For loading replays, see [`ReplayController`](https://github.com/MasterBel2/UberserverClientCore/blob/master/Sources/UberserverClientCore/Controllers/ReplayController.swift)

Some systems are implemented outside this package.
- For replay file handling, see [`SpringRTSReplayHandling`](https://github.com/MasterBel2/SpringRTSReplayHandling)
- For start scripts, see [`SpringRTSStartScriptHandling`](https://github.com/MasterBel2/SpringRTSStartScriptHandling)
