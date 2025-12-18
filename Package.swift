// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .defaultIsolation(MainActor.self),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances")
]

let package = Package(
    name: "xcodeinstall",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "xcodeinstall", targets: ["xcodeinstall"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.6.2"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.4"),
        
        // do not use Soto 7.x
        // it has a transitive dependency on swift-service-context whichs fails to compile 
        // under the brew sandbox (when creating the bottle) 
        // see https://github.com/orgs/Homebrew/discussions/59
        // .package(url: "https://github.com/soto-project/soto.git", from: "6.8.0"), 
        .package(url: "https://github.com/soto-project/soto.git", from: "7.12.0"), 
        
        .package(url: "https://github.com/sebsto/CLIlib/", branch: "main"),
        .package(url: "https://github.com/adam-fowler/swift-srp", from: "2.1.0"),
        
        // disable "SubprocessSpan" until Swift 6.2.1 is resolved
        // https://github.com/swiftlang/swift/issues/84379
        // https://github.com/swiftlang/swift-package-manager/issues/9163
        .package(url: "https://github.com/swiftlang/swift-subprocess.git", from: "0.2.0", traits: ["SubprocessFoundation"]), 
        .package(url: "https://github.com/apple/swift-crypto", from: "3.15.1"),
        .package(url: "https://github.com/apple/swift-system", from: "1.5.0"),
        .package(url: "https://github.com/saagarjha/unxip.git", from: "3.2.0")
        //.package(path: "../CLIlib")
    ],

    targets: [
        .executableTarget(
            name: "xcodeinstall",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "SotoSecretsManager", package: "soto"),
                .product(name: "SRP", package: "swift-srp"),
                .product(name: "CLIlib", package: "CLIlib"),
                .product(name: "_CryptoExtras", package: "swift-crypto"),
                .product(name: "Subprocess", package: "swift-subprocess"),
                .product(name: "SystemPackage", package: "swift-system"),
                .product(name: "libunxip", package: "unxip"),
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "xcodeinstallTests",
            dependencies: [
                "xcodeinstall",
                .product(name: "Logging", package: "swift-log")
            ],
            // https://stackoverflow.com/questions/47177036/use-resources-in-unit-tests-with-swift-package-manager
            resources: [.process("data/download-list-20220723.json"),
                        .process("data/download-list-20231115.json"),
                        .process("data/download-error.json"),
                        .process("data/download-unknown-error.json")
            ],
            swiftSettings: swiftSettings
        )
    ]
)
