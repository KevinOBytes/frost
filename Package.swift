// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Frost",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Frost",
            path: "Sources/Frost"
        ),
        .testTarget(
            name: "FrostTests",
            dependencies: ["Frost"],
            path: "Tests/FrostTests"
        )
    ]
)