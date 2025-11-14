import Foundation
import PeekabooVisualizer
import PeekabooFoundation
import PeekabooProtocols
import Testing

@Suite("Visualizer event contract")
@MainActor
struct VisualizerEventStoreContractTests {
    @Test("Payload encoding round-trips annotated screenshot")
    func annotatedScreenshotPayload() throws {
        let payload = VisualizerEvent.Payload.annotatedScreenshot(
            imageData: Data([0x89, 0x50]),
            elements: [DetectedElement(id: "A1", type: .button, bounds: .zero, label: nil, value: nil, isEnabled: true)],
            windowBounds: .zero,
            duration: 1.0)

        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(VisualizerEvent.Payload.self, from: data)
        switch decoded {
        case let .annotatedScreenshot(_, elements, _, _):
            #expect(elements.count == 1)
        default:
            Issue.record("Decoded payload mismatch")
        }
    }
}
