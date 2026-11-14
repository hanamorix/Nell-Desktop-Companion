// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Nell",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "NellCore"),
        .executableTarget(name: "Nell", dependencies: ["NellCore"]),
        .testTarget(name: "NellCoreTests", dependencies: ["NellCore"], resources: [.copy("Fixtures")]),
    ]
)
