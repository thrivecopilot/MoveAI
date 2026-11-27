// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MoveAICLI",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MoveAICLI", targets: ["MoveAICLI"])
    ],
    targets: [
        .target(
            name: "MoveAICore",
            path: "Sources/MoveAICore"
        ),
        .executableTarget(
            name: "MoveAICLI",
            dependencies: ["MoveAICore"],
            path: "Sources/MoveAICLI"
        ),
        .testTarget(
            name: "MoveAICLITests",
            dependencies: ["MoveAICore"],
            path: "Tests/MoveAICLITests"
        )
    ]
)
