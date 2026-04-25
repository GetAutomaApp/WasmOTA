@_expose(wasm, "test")
@_cdecl("test")
public func test() -> Int32 {
    print("Hello, World!")
    return 0
}
