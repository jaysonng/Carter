// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Carter",
    // Cross-platform as of 2.0: an app target and a Linux server process can
    // both use it. That matters for anything that validates a link before
    // storing it, since a rule enforced only on the client is not enforced.
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
