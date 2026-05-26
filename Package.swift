// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TermTP",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "TermTPCore", targets: ["TermTPCore"]),
        .executable(name: "TermTPApp", targets: ["TermTPApp"]),
        .executable(name: "TermTPIconTool", targets: ["TermTPIconTool"])
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", revision: "73576f6f838414bab4c230cd1b56237bd16c3bbf"),
        .package(url: "https://github.com/orlandos-nl/Citadel.git", from: "0.9.2"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.81.0"),
        .package(url: "https://github.com/Wellz26/swift-nio-ssh.git", "0.3.4" ..< "0.4.0")
    ],
    targets: [
        .target(
            name: "TermTPCore",
            dependencies: [
                .product(name: "Citadel", package: "Citadel"),
                .product(name: "NIOSSH", package: "swift-nio-ssh"),
                .product(name: "NIOCore", package: "swift-nio")
            ]
        ),
        .executableTarget(
            name: "TermTPApp",
            dependencies: [
                "TermTPCore",
                .product(name: "SwiftTerm", package: "SwiftTerm")
            ],
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "TermTPIconTool"
        ),
        .testTarget(
            name: "TermTPCoreTests",
            dependencies: ["TermTPCore"]
        ),
        .testTarget(
            name: "TermTPAppTests",
            dependencies: ["TermTPApp"]
        )
    ]
)
