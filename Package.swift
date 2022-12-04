// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "UberserverClientCore",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v9)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "UberserverClientCore",
            targets: ["UberserverClientCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/MasterBel2/ServerAddress", .branch("master")),
        .package(url: "https://github.com/MasterBel2/CountryCode", .branch("master")),
        .package(url: "https://github.com/MasterBel2/SpringRTSStartScriptHandling", .branch("master")),
        .package(url: "https://github.com/MasterBel2/SpringRTSReplayHandling", .branch("master")),
        .package(url: "https://github.com/tsolomko/SWCompression", from: "4.7.0"),
        .package(url: "https://github.com/apple/swift-crypto", "1.0.0" ..< "3.0.0"),
        .package(url: "https://github.com/apple/swift-nio", .upToNextMajor(from: "2.0.0")),
        .package(url: "https://github.com/apple/swift-nio-ssl", .upToNextMajor(from: "2.0.0"))
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "UberserverClientCore",
            dependencies: [
                "ServerAddress",
                "CountryCode",
                "SpringRTSStartScriptHandling",
                "SpringRTSReplayHandling",
                "SWCompression",
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOFoundationCompat", package: "swift-nio"),
                .product(name: "NIOSSL", package: "swift-nio-ssl"),
            ]),
        .testTarget(
            name: "UberserverClientCoreTests",
            dependencies: ["UberserverClientCore"]),
    ]
)
