import Testing

@Suite("Simple Swift Testing Example")
struct SimpleSwiftTests {
    @Test("Basic equality check")
    func equalityCheck() throws {
        #expect(1 == 1)
    }

    @Test("Boolean assertion")
    func booleanAssertion() {
        #expect(true)
    }
}
