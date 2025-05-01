// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name:"Gooey Writer",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
    ],
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-collections.git",
            from: "1.1.1"
        ),
        .package(
            url: "https://github.com/orlandos-nl/Citadel.git",
            from: "0.7.2"
        )
    ]
)