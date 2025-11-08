import AppKit
import Foundation

@main
final class PeekabooVisualizerXPCEntryPoint {
    private static var service: VisualizerXPCService?

    static func main() {
        Task { @MainActor in
            let coordinator = VisualizerCoordinator()
            let service = VisualizerXPCService(visualizerCoordinator: coordinator)
            Self.service = service
            let listener = NSXPCListener.service()
            listener.delegate = service
            listener.resume()
        }
        RunLoop.current.run()
    }
}
