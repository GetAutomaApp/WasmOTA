// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "WasmOTAExampleProject",
    platforms: [
        .macOS(.v15)
    ],
    dependencies: [
        .package(path: "../..")
    ],
    targets: [
        .executableTarget(
            name: "WasmOTAExampleProject",
            dependencies: ["WasmOTA"],
            resources: [
                .copy("Resources/main.wasm")
            ]
        )
    ]
)
