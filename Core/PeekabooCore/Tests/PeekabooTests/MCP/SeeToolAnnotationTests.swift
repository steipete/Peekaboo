import PeekabooAutomationKit
import Testing

struct SeeToolAnnotationTests {
    @Test
    func `annotated screenshot path comes from observation output writer`() {
        let original = "/tmp/test.png"
        let annotated = ObservationOutputWriter.annotatedScreenshotPath(forRawScreenshotPath: original)
        #expect(annotated == "/tmp/test_annotated.png")
    }
}
