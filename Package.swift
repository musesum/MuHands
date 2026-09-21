// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "MuHands",
    platforms: [.iOS(.v17), .visionOS(.v2), .watchOS(.v10)],
    products: [.library( name: "MuHands",  targets: ["MuHands"] ) ],
    dependencies: [
        // DEV: local paths during watchOS port. Restore github URLs before publish.
        .package(name: "MuFlo", path: "../MuFlo"),
        .package(name: "MuPeers", path: "../MuPeers"),
        // PlaGo: TouchBuffer imports NIOCore; local graph had no provider
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0"),
    ],
    targets: [
        .target(  name: "MuHands",
                  dependencies: [
                    .product(name: "MuFlo", package: "MuFlo"),
                    .product(name: "MuPeers", package: "MuPeers"),
                    .product(name: "NIOCore", package: "swift-nio"),
                  ]),
    ]
)
