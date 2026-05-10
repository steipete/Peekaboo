import Testing
@_spi(Testing) import PeekabooAutomationKit

struct CaptureEngineResolverTests {
    @Test
    func `auto defaults to legacy+modern`() {
        let apis = ScreenCaptureAPIResolver.resolve(environment: [:])
        #expect(apis == [.legacy, .modern])
    }

    @Test
    func `modern-only selection`() {
        let apis = ScreenCaptureAPIResolver.resolve(environment: ["PEEKABOO_CAPTURE_ENGINE": "modern"])
        #expect(apis == [.modern])
    }

    @Test
    func `classic selection`() {
        let apis = ScreenCaptureAPIResolver.resolve(environment: ["PEEKABOO_CAPTURE_ENGINE": "classic"])
        #expect(apis == [.legacy])
    }

    @Test
    func `disable CG via env`() {
        let apis = ScreenCaptureAPIResolver.resolve(environment: [
            "PEEKABOO_CAPTURE_ENGINE": "auto",
            "PEEKABOO_DISABLE_CGWINDOWLIST": "1",
        ])
        #expect(apis == [.modern])
    }
}
