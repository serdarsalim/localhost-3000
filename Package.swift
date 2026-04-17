// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "localhost-3000",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "LocalhostApp",
            path: "Sources/LocalhostApp"
        )
    ]
)
