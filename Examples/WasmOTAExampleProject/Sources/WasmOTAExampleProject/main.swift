import Foundation
import WasmOTA

let currentDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let fileManager = FileManager.default
let wasmCandidates = [
    currentDirectory
        .appendingPathComponent("Examples/TestWasmProject/.build/wasm32-unknown-wasi/debug/TestWasmProject.wasm"),
    currentDirectory
        .appendingPathComponent("../TestWasmProject/.build/wasm32-unknown-wasi/debug/TestWasmProject.wasm"),
]

guard let wasmPath = wasmCandidates
    .map({ $0.standardizedFileURL.path })
    .first(where: { fileManager.fileExists(atPath: $0) })
else {
    throw NSError(
        domain: "WasmOTAExampleProject",
        code: 1,
        userInfo: [
            NSLocalizedDescriptionKey: "Could not find TestWasmProject.wasm"
        ]
    )
}

let runtime = try WasmOTA(path: wasmPath)
let result = try runtime.call("test")
print("test() returned \(result)")
