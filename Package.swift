// swift-tools-version: 5.9
import PackageDescription

// UCITTCore holds the pure, device-independent logic for the UCI TT Position
// Checker: geometry, the pixel->mm homography, and the UCI rules engine.
// It deliberately depends on Foundation only (no UIKit / Vision / AVFoundation)
// so it builds and unit-tests on any Swift toolchain, with no device required.
let package = Package(
    name: "UCITTCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v13)
    ],
    products: [
        .library(name: "UCITTCore", targets: ["UCITTCore"])
    ],
    targets: [
        .target(name: "UCITTCore"),
        .testTarget(
            name: "UCITTCoreTests",
            dependencies: ["UCITTCore"]
        )
    ]
)
