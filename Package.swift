// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Carter",
    // Carter is CROSS-PLATFORM as of 2.0. It runs in an iOS app and in a
    // Linux server process (Vapor), because link ingestion belongs on the
    // server: a publisher whitelist enforced only on the client is not
    // enforcement — anyone can call the cloud function directly.
    //
    // iOS 14 / macOS 11 are the floors for os.Logger, which the logging shim
    // uses on Apple platforms. Linux has no platform floor to declare.
    platforms: [.iOS(.v14), .macOS(.v11), .tvOS(.v14), .watchOS(.v7)],
    products: [
        .library(name: "Carter", targets: ["Carter"]),
    ],
    dependencies: [
        // Kanna wraps libxml2 and builds on Linux via pkgConfig "libxml-2.0".
        // A Linux host/image must provide libxml2-dev.
        .package(url: "https://github.com/tid-kijyun/Kanna", from: "5.0.0"),
    ],
    targets: [
        .target(name: "Carter", dependencies: ["Kanna"]),
        .testTarget(name: "CarterTests", dependencies: ["Carter"]),
    ]
)
