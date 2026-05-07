import CoreGraphics
import PeekabooCore
import Testing
@testable import PeekabooCLI

@MainActor
struct VisualizerCommandTests {
    @Test
    func `Visualizer smoke layout uses primary screen service frame`() {
        let primary = ScreenInfo(
            index: 1,
            name: "Built-in",
            frame: CGRect(x: 100, y: 200, width: 1728, height: 1117),
            visibleFrame: CGRect(x: 100, y: 200, width: 1728, height: 1080),
            isPrimary: true,
            scaleFactor: 2,
            displayID: 1
        )
        let secondary = ScreenInfo(
            index: 0,
            name: "External",
            frame: CGRect(x: -1920, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: -1920, y: 0, width: 1920, height: 1040),
            isPrimary: false,
            scaleFactor: 1,
            displayID: 2
        )

        let service = StubScreenService(screens: [secondary, primary])

        #expect(VisualizerSmokeLayout.screenFrame(using: service) == primary.frame)
    }

    @Test
    func `Visualizer smoke layout falls back when screen service is empty`() {
        let service = StubScreenService(screens: [])

        #expect(VisualizerSmokeLayout.screenFrame(using: service) == VisualizerSmokeLayout.fallbackFrame)
    }
}

@MainActor
private final class StubScreenService: ScreenServiceProtocol {
    private let screens: [ScreenInfo]

    init(screens: [ScreenInfo]) {
        self.screens = screens
    }

    func listScreens() -> [ScreenInfo] {
        self.screens
    }

    func screenContainingWindow(bounds: CGRect) -> ScreenInfo? {
        self.screens.first { $0.frame.intersects(bounds) }
    }

    func screen(at index: Int) -> ScreenInfo? {
        self.screens.first { $0.index == index }
    }

    var primaryScreen: ScreenInfo? {
        self.screens.first { $0.isPrimary }
    }
}
