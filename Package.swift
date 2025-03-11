// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ElectricSync",
    platforms: [
        .macOS(.v15), .iOS(.v18)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "ElectricSync",
            targets: ["ElectricSync"]),
    ],
    dependencies: [
        .package(url: "https://github.com/codewinsdotcom/PostgresClientKit.git", from: "1.5.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "ElectricSync",
            dependencies: []
        ),
        .testTarget(
            name: "ElectricSyncTests",
            dependencies: [
                "ElectricSync", 
                .product(name: "PostgresClientKit", package: "postgresclientkit"),
            ]
        ),
    ]
)
