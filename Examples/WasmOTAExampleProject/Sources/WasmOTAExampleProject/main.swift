import Foundation
import WasmOTA

let fallbackURL = Bundle.module.url(forResource: "main", withExtension: "wasm")
let remoteURL = URL(string: "http://127.0.0.1:8000/main.wasm")!
let runtime = try WasmOTA.load(from: remoteURL, fallbackPath: fallbackURL?.path)
let result = try runtime.call("test")
print("test() returned \(result)")
