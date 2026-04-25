import Foundation
import CryptoKit
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

    public static func load(from url: URL, fallbackPath: String? = nil) throws -> WasmOTA {
        let cacheDirectory = try cacheDirectory()
        try FileManager.default.createDirectory(
            at: cacheDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let cacheKey = sha256(url.absoluteString)
        let cachedPath = cacheDirectory.appendingPathComponent("\(cacheKey).wasm")
        let cachedFileExists = FileManager.default.fileExists(atPath: cachedPath.path)

        if cachedFileExists {
            print("[WasmOTA] Cache hit for \(url.absoluteString)")
        } else {
            print("[WasmOTA] Cache miss for \(url.absoluteString)")
        }

        let localETag = cachedFileExists ? computeETag(path: cachedPath) : nil
        if let localETag {
            print("[WasmOTA] Local ETag \(localETag)")
        }

        do {
            let response = try fetch(url: url, etag: localETag)
            switch response {
            case .notModified:
                print("[WasmOTA] Remote returned 304 Not Modified")
                return try WasmOTA(path: cachedPath.path)
            case let .downloaded(data):
                print("[WasmOTA] Downloaded updated binary")
                try data.write(to: cachedPath, options: .atomic)
                return try WasmOTA(path: cachedPath.path)
            }
        } catch {
            print("[WasmOTA] Remote load failed: \(error)")
            if cachedFileExists {
                print("[WasmOTA] Falling back to cached binary")
                return try WasmOTA(path: cachedPath.path)
            }
            if let fallbackPath {
                print("[WasmOTA] Falling back to bundled binary")
                return try WasmOTA(path: fallbackPath)
            }
            throw error
        }
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

    private static func cacheDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return base.appendingPathComponent("WasmOTA", isDirectory: true)
    }

    private static func fetch(url: URL, etag: String?) throws -> RemoteFetchResult {
        var request = URLRequest(url: url)
        if let etag {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }

        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<RemoteFetchResult, Error>?

        URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }

            if let error {
                result = .failure(error)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                result = .failure(WasmOTAError.invalidResponse)
                return
            }

            switch httpResponse.statusCode {
            case 200:
                result = .success(.downloaded(data ?? Data()))
            case 304:
                result = .success(.notModified)
            default:
                result = .failure(WasmOTAError.httpStatus(httpResponse.statusCode))
            }
        }.resume()

        semaphore.wait()
        return try result!.get()
    }

    private static func computeETag(path: URL) -> String {
        let data = (try? Data(contentsOf: path)) ?? Data()
        let digest = Insecure.MD5.hash(data: data)
        let hash = digest.map { String(format: "%02hhx", $0) }.joined()
        return "\"\(hash)\""
    }

    private static func sha256(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
}

public enum WasmOTAError: Error {
    case missingFunction(String)
    case invalidReturnCount(function: String, count: Int)
    case invalidReturnType(function: String)
    case invalidResponse
    case httpStatus(Int)
}

private enum RemoteFetchResult {
    case notModified
    case downloaded(Data)
}
