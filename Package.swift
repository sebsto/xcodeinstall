// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "xcodeinstall",
    platforms: [
        .macOS(.v12)
    ],    
    products: [
        .executable(name: "xcodeinstall", targets: ["xcodeinstall"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-tools-support-core.git", from: "0.2.7"),
        .package(url: "https://github.com/apple/swift-system", from: "1.0.0"),
        .package(url: "https://github.com/soto-project/soto.git", from: "6.1.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .executableTarget(
            name: "xcodeinstall",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "SystemPackage", package: "swift-system"),
                .product(name: "SwiftToolsSupport", package: "swift-tools-support-core"),
                .product(name: "SotoSecretsManager", package: "soto"),
            ]
        ),
        .testTarget(
            name: "xcodeinstallTests",
            dependencies: ["xcodeinstall"]),
    ]
)
