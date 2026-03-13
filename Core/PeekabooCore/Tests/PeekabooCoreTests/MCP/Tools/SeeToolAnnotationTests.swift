import Foundation
import Testing

struct SeeToolAnnotationTests {
    @Test
    func `Annotation flag toggles path`() {
        let original = "/tmp/test.png"
        let annotated = original.replacingOccurrences(of: ".png", with: "_annotated.png")
        #expect(annotated == "/tmp/test_annotated.png")
    }
}
