// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "MuHands",
    platforms: [.iOS(.v17), .visionOS(.v2)],
    products: [.library( name: "MuHands",  targets: ["MuHands"] ) ],
    dependencies: [
        .package(url: "https://github.com/musesum/MuFlo.git", branch: "main"),
        .package(url: "https://github.com/musesum/MuPeers.git", branch: "main"),
    ],
    targets: [
        .target(  name: "MuHands",
                  dependencies: [
                    .product(name: "MuFlo", package: "MuFlo"),
                    .product(name: "MuPeers", package: "MuPeers"),
                  ]),
    ]
)
