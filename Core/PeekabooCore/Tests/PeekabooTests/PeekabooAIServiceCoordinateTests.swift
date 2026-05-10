import CoreGraphics
import Testing
@testable import PeekabooAutomation

struct PeekabooAIServiceCoordinateTests {
    @Test
    func `GLM normalized boxes are converted to pixels`() {
        let text = "Continue button: [283, 263, 463, 295]"

        let normalized = PeekabooAIService.normalizeCoordinateTextIfNeeded(
            text,
            model: "glm-4.6v-flash",
            imageSize: CGSize(width: 1920, height: 1080))

        #expect(normalized.contains("[543, 284, 889, 319]"))
        #expect(normalized.contains("converted from GLM normalized [283, 263, 463, 295]"))
    }

    @Test
    func `non GLM models keep coordinate text unchanged`() {
        let text = "Continue button: [283, 263, 463, 295]"

        let normalized = PeekabooAIService.normalizeCoordinateTextIfNeeded(
            text,
            model: "gpt-5.5",
            imageSize: CGSize(width: 1920, height: 1080))

        #expect(normalized == text)
    }

    @Test
    func `invalid GLM boxes are left unchanged`() {
        let text = "Color sample [283, 263, 200, 295] and point [120, 44]"

        let normalized = PeekabooAIService.normalizeCoordinateTextIfNeeded(
            text,
            model: "glm-4.6v-flash",
            imageSize: CGSize(width: 1920, height: 1080))

        #expect(normalized == text)
    }
}
