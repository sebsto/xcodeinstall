// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "xcodeinstall",
    platforms: [
        .macOS(.v15)
    ],    
    products: [
        .executable(name: "xcodeinstall", targets: ["xcodeinstall"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.6.0"),
        .package(url: "https://github.com/soto-project/soto.git", from: "7.9.0"),
        .package(url: "https://github.com/sebsto/CLIlib/", branch: "main"),
        .package(url: "https://github.com/adam-fowler/swift-srp", from: "2.1.0"),
        .package(url: "https://github.com/swiftlang/swift-subprocess.git", branch: "main"),
        .package(url: "https://github.com/apple/swift-crypto", from: "3.14.0"),
        .package(url: "https://github.com/apple/swift-system", from: "1.6.0"),
        .package(url: "https://github.com/saagarjha/unxip.git", from: "3.2.0"),
        //.package(path: "../CLIlib")
    ],

    targets: [
        .executableTarget(
            name: "xcodeinstall",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "SotoSecretsManager", package: "soto"),
                .product(name: "SRP", package: "swift-srp"),
                .product(name: "CLIlib", package: "CLIlib"),
                .product(name: "_CryptoExtras", package: "swift-crypto"),
                .product(name: "Subprocess", package: "swift-subprocess"),
                .product(name: "SystemPackage", package: "swift-system"),
                .product(name: "libunxip", package: "unxip")
            ]
        ),
        .testTarget(
            name: "xcodeinstallTests",
            dependencies: ["xcodeinstall"],
            // https://stackoverflow.com/questions/47177036/use-resources-in-unit-tests-with-swift-package-manager
            resources: [.process("data/download-list-20220723.json"),
                        .process("data/download-list-20231115.json"),
                        .process("data/download-error.json"),
                        .process("data/download-unknown-error.json")] //,
        )
    ],
)
