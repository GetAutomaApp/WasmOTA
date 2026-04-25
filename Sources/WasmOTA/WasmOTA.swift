import SystemPackage
import WasmKit
import WasmKitWASI

public final class WasmOTA {
    private let store: Store
    private let instance: Instance
    private let wasi: WASIBridgeToHost

    public init(path: String) throws {
        let engine = Engine()
        let module = try parseWasm(filePath: FilePath(path))
        let store = Store(engine: engine)
        let wasi = try WASIBridgeToHost(args: [path])
        var imports = Imports()

        wasi.link(to: &imports, store: store)

        self.store = store
        self.wasi = wasi
        self.instance = try module.instantiate(store: store, imports: imports)
        try wasi.initialize(self.instance)
    }

    public func call(_ name: String) throws -> Int32 {
        guard let fn = instance.exports[function: name] else {
            throw WasmOTAError.missingFunction(name)
        }
        let results = try fn([])
        return try Self.readSingleI32(results, function: name)
    }

    public func call(_ name: String, value: Int32) throws -> Int32 {
        guard let fn = instance.exports[function: name] else {
            throw WasmOTAError.missingFunction(name)
        }
        let results = try fn([.i32(UInt32(bitPattern: value))])
        return try Self.readSingleI32(results, function: name)
    }

    private static func readSingleI32(_ results: [Value], function: String) throws -> Int32 {
        guard results.count == 1 else {
            throw WasmOTAError.invalidReturnCount(function: function, count: results.count)
        }

        guard case let .i32(value) = results[0] else {
            throw WasmOTAError.invalidReturnType(function: function)
        }

        return Int32(bitPattern: value)
    }
}

public enum WasmOTAError: Error {
    case missingFunction(String)
    case invalidReturnCount(function: String, count: Int)
    case invalidReturnType(function: String)
}
