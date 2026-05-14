// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TermC",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "TermCCore", targets: ["TermCCore"]),
        .executable(name: "TermCApp", targets: ["TermCApp"]),
        .executable(name: "TermCIconTool", targets: ["TermCIconTool"])
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", revision: "73576f6f838414bab4c230cd1b56237bd16c3bbf"),
        .package(url: "https://github.com/orlandos-nl/Citadel.git", from: "0.9.2")
    ],
    targets: [
        .target(
            name: "TermCCore",
            dependencies: [
                .product(name: "Citadel", package: "Citadel")
            ]
        ),
        .executableTarget(
            name: "TermCApp",
            dependencies: [
                "TermCCore",
                .product(name: "SwiftTerm", package: "SwiftTerm")
            ],
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "TermCIconTool"
        ),
        .testTarget(
            name: "TermCCoreTests",
            dependencies: ["TermCCore"]
        ),
        .testTarget(
            name: "TermCAppTests",
            dependencies: ["TermCApp"]
        )
    ]
)
