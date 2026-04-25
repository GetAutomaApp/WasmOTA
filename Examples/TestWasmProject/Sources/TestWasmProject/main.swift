@_expose(wasm, "test")
@_cdecl("test")
public func test() -> Int32 {
    print("Bye..Bye, World!")
    return 0
}
