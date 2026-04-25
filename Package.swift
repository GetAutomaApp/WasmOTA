// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WasmOTA",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "WasmOTA",
            targets: ["WasmOTA"])
    ],
    dependencies: [
        .package(url: "https://github.com/swiftwasm/WasmKit.git", from: "0.2.1"),
        .package(url: "https://github.com/apple/swift-system.git", from: "1.5.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "WasmOTA",
            dependencies: [
                .product(name: "WasmKit", package: "wasmkit"),
                .product(name: "WasmKitWASI", package: "wasmkit"),
                .product(name: "SystemPackage", package: "swift-system")
            ]
        ),
        .testTarget(
            name: "WasmOTATests",
            dependencies: ["WasmOTA"]
        ),
    ]
)
