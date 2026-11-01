// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TverKa",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "TverKaCore"),
        .executableTarget(name: "TverKa", dependencies: ["TverKaCore"]),
        .testTarget(name: "TverKaCoreTests", dependencies: ["TverKaCore"]),
    ]
)
