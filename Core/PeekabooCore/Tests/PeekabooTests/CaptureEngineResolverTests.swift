import Testing
@testable import PeekabooAutomation

@Suite("Capture engine env resolver")
struct CaptureEngineResolverTests {
    @Test("auto defaults to modern+legacy")
    func autoDefault() {
        let apis = ScreenCaptureAPIResolver.resolve(environment: [:])
        #expect(apis == [.modern, .legacy])
    }

    @Test("modern-only selection")
    func modernOnly() {
        let apis = ScreenCaptureAPIResolver.resolve(environment: ["PEEKABOO_CAPTURE_ENGINE": "modern"])
        #expect(apis == [.modern])
    }

    @Test("classic selection")
    func classicOnly() {
        let apis = ScreenCaptureAPIResolver.resolve(environment: ["PEEKABOO_CAPTURE_ENGINE": "classic"])
        #expect(apis == [.legacy])
    }

    @Test("disable CG via env")
    func disableCG() {
        let apis = ScreenCaptureAPIResolver.resolve(environment: [
            "PEEKABOO_CAPTURE_ENGINE": "auto",
            "PEEKABOO_DISABLE_CGWINDOWLIST": "1",
        ])
        #expect(apis == [.modern])
    }
}
