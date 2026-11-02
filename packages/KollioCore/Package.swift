// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "KollioCore",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "KollioCore", targets: ["KollioCore"])
    ],
    targets: [
        .target(name: "KollioCore"),
        .testTarget(name: "KollioCoreTests", dependencies: ["KollioCore"])
    ]
)
