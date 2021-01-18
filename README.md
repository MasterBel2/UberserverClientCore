# UberserverClientCore

A Swift implementation of the common functionality required for multiplayer lobby clients connecting to implementations of the [Spring Lobby Protocol](https://springrts.com/dl/LobbyProtocol/ProtocolDescription.html). 

This project is primarily experiemental, and as such has been prioritising exploration over completeness. Contact [MasterBel2](https://github.com/MasterBel2) if you wish to make use of this project, and require any guidance or further functionality, he will be more than happy to help you out.

## Structure

The implementation is based around the concept of a [`Client`](https://github.com/MasterBel2/UberserverClientCore/blob/master/Sources/UberserverClientCore/Core/Client.swift), which describes a connection to a server, and contains the data relating to that connection. Various other systems (such as downloading and launching games) are integrated directly into the structure of the `Client` class. This is best discovered through investigating the inline documentation in the file linked above.  

## Implementing a custom Client

Clients may be instantiated individually, but it is reccomended you use a [`ClientController`](https://github.com/MasterBel2/UberserverClientCore/blob/master/Sources/UberserverClientCore/Core/ClientController.swift) if you intend to create and manage multiple clients. Custom client behaviour can be configured through an instance of your custom implementation of [`ClientWindowManager`](https://github.com/MasterBel2/UberserverClientCore/blob/master/Sources/UberserverClientCore/ClientWindowManager.swift). (Note: `ClientWindowManager` may be renamed to `ClientInterfaceManager` to acknowledge that some clients will prefer to process information in other ways than simply presenting it to a window. The final structure of this is currently under re-evaluation.)

[See here for an example implementation.](https://github.com/MasterBel2/BelieveAndRise) 
