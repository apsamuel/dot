// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "applevm-helper",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "applevm-helper",
            dependencies: [],
            path: "Sources"
        )
    ]
)
