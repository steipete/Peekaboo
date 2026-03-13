import Testing
@testable import PeekabooVisualizer

@MainActor
struct VisualizerOverlaySizingTests {
    @Test
    func `Hotkey overlay grows with more keys`() {
        let compact = VisualizerCoordinator.estimatedHotkeyOverlaySize(for: ["cmd", "k"])
        let wide = VisualizerCoordinator.estimatedHotkeyOverlaySize(for: ["cmd", "shift", "option", "ctrl", "space"])

        #expect(compact.width >= 400)
        #expect(compact.height >= 160)
        #expect(wide.width > compact.width)
        #expect(wide.height >= compact.height)
    }

    @Test
    func `Menu overlay grows with path length`() {
        let short = VisualizerCoordinator.estimatedMenuOverlaySize(for: ["File", "New"])
        let long = VisualizerCoordinator.estimatedMenuOverlaySize(for: ["File", "New", "Project", "Swift Package"])

        #expect(short.width >= 600)
        #expect(long.width > short.width)
        #expect(short.height > 0)
        #expect(long.height == short.height)
    }
}
