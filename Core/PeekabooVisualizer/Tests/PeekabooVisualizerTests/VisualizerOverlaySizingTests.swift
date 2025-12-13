import Testing
@testable import PeekabooVisualizer

@Suite("Visualizer overlay sizing")
@MainActor
struct VisualizerOverlaySizingTests {
    @Test("Hotkey overlay grows with more keys")
    func hotkeyOverlayGrows() {
        let compact = VisualizerCoordinator.estimatedHotkeyOverlaySize(for: ["cmd", "k"])
        let wide = VisualizerCoordinator.estimatedHotkeyOverlaySize(for: ["cmd", "shift", "option", "ctrl", "space"])

        #expect(compact.width >= 400)
        #expect(compact.height >= 160)
        #expect(wide.width > compact.width)
        #expect(wide.height >= compact.height)
    }

    @Test("Menu overlay grows with path length")
    func menuOverlayGrows() {
        let short = VisualizerCoordinator.estimatedMenuOverlaySize(for: ["File", "New"])
        let long = VisualizerCoordinator.estimatedMenuOverlaySize(for: ["File", "New", "Project", "Swift Package"])

        #expect(short.width >= 600)
        #expect(long.width > short.width)
        #expect(short.height > 0)
        #expect(long.height == short.height)
    }
}
