// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WiiBridge",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "WiiBridge", targets: ["WiiBridge"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "WiiBridge",
            dependencies: [],
            path: "Sources/WiiBridge"
        ),
        .testTarget(
            name: "WiiBridgeTests",
            dependencies: ["WiiBridge"],
            path: "Tests/WiiBridgeTests"
        )
    ]
)
