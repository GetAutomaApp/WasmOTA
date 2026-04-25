// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "TestWasmProject",
    products: [
        .executable(
            name: "TestWasmProject",
            targets: ["TestWasmProject"])
    ],
    targets: [
        .executableTarget(
            name: "TestWasmProject",
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ],
            linkerSettings: [
                .unsafeFlags(["-Xclang-linker", "-mexec-model=reactor"])
            ]
        )
    ]
)
