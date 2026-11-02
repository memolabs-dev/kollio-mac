// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "KollioServer",
    // The same floor as KollioCore and KollioApp. It was left at v14 when the
    // other two moved, and only the app's *test* target noticed: it links this
    // package through XCTVapor, so `swift test` refused to build a v26 product
    // into a target this package had declared as v14. The executable does not
    // import the server, which is why the app itself kept building.
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "KollioServerKit", targets: ["KollioServerKit"]),
        .executable(name: "kollio-server", targets: ["KollioServer"])
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.106.0"),
        .package(path: "../../packages/KollioCore")
    ],
    targets: [
        .target(
            name: "KollioServerKit",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "KollioCore", package: "KollioCore")
            ]
        ),
        .executableTarget(
            name: "KollioServer",
            dependencies: ["KollioServerKit"]
        ),
        .testTarget(
            name: "KollioServerKitTests",
            dependencies: [
                "KollioServerKit",
                .product(name: "Vapor", package: "vapor"),
                .product(name: "XCTVapor", package: "vapor"),
                .product(name: "KollioCore", package: "KollioCore")
            ]
        )
    ]
)
