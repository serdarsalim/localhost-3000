// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "localhost-3000",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.2.4")
    ],
    targets: [
        .executableTarget(
            name: "LocalhostApp",
            dependencies: [
                .product(name: "SwiftTerm", package: "SwiftTerm")
            ],
            path: "Sources/LocalhostApp"
        )
    ]
)
