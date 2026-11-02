// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "KollioApp",
    defaultLocalization: "en",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "Kollio", targets: ["KollioApp"])
    ],
    dependencies: [
        .package(path: "../KollioCore"),
        .package(path: "../../services/KollioServer"),
        .package(url: "https://github.com/vapor/vapor.git", from: "4.106.0")
    ],
    targets: [
        .target(
            name: "KollioEvaluationKit",
            dependencies: [.product(name: "KollioCore", package: "KollioCore")]
        ),
        .executableTarget(
            name: "KollioApp",
            dependencies: [.product(name: "KollioCore", package: "KollioCore")],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "KollioAppTests",
            dependencies: [
                "KollioApp",
                .product(name: "KollioCore", package: "KollioCore"),
                .product(name: "KollioServerKit", package: "KollioServer"),
                .product(name: "Vapor", package: "vapor"),
                .product(name: "XCTVapor", package: "vapor"),
                "KollioEvaluationKit"
            ]
        )
    ]
)
