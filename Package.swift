// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TuneMouse",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "TuneMouse",
            path: "Sources/TuneMouse"
        )
    ]
)
