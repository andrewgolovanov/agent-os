// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AgentOS",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "AgentOS", targets: ["AgentOS"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.5"),
    ],
    targets: [
        .executableTarget(
            name: "AgentOS",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/AgentOS"
        ),
        .testTarget(
            name: "AgentOSTests",
            dependencies: ["AgentOS"]
        ),
    ]
)
