import Foundation
import Testing

@Suite("SeeTool Annotation Tests")
struct SeeToolAnnotationTests {
    @Test("Annotation flag toggles path")
    func annotationFlagTogglesPath() {
        let original = "/tmp/test.png"
        let annotated = original.replacingOccurrences(of: ".png", with: "_annotated.png")
        #expect(annotated == "/tmp/test_annotated.png")
    }
}
