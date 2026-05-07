import Algorithms
import Commander
import CoreGraphics
import Foundation
import PeekabooCore

private typealias ScreenOutput = UnifiedToolOutput<ScreenListData>

extension ListCommand {
    // MARK: - Screens

    @MainActor
    struct ScreensSubcommand: ErrorHandlingCommand, OutputFormattable, RuntimeOptionsConfigurable {
        @RuntimeStorage private var runtime: CommandRuntime?
        var runtimeOptions = CommandRuntimeOptions()

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        private var services: any PeekabooServiceProviding {
            self.resolvedRuntime.services
        }

        private var logger: Logger {
            self.resolvedRuntime.logger
        }

        var outputLogger: Logger {
            self.logger
        }

        var jsonOutput: Bool {
            self.runtime?.configuration.jsonOutput ?? self.runtimeOptions.jsonOutput
        }

        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            self.logger.setJsonOutputMode(self.jsonOutput)

            let screens = self.services.screens.listScreens()
            let screenListData = self.buildScreenListData(from: screens)
            let output = UnifiedToolOutput(
                data: screenListData,
                summary: self.buildScreenSummary(for: screens),
                metadata: self.buildScreenMetadata()
            )

            if self.jsonOutput {
                outputSuccessCodable(data: output.data, logger: self.outputLogger)
            } else {
                self.displayScreenDetails(screens, count: screens.count)
            }
        }

        @MainActor
        private func displayScreenDetails(_ screens: [PeekabooCore.ScreenInfo], count: Int) {
            Swift.print("Screens (\(count) total):")
            for screen in screens {
                let primaryBadge = screen.isPrimary ? " (Primary)" : ""
                Swift.print("\n\(screen.index). \(screen.name)\(primaryBadge)")
                Swift.print("   Resolution: \(Int(screen.frame.width))×\(Int(screen.frame.height))")
                Swift.print("   Position: \(Int(screen.frame.origin.x)),\(Int(screen.frame.origin.y))")
                let retinaBadge = screen.scaleFactor > 1 ? " (Retina)" : ""
                Swift.print("   Scale: \(screen.scaleFactor)x\(retinaBadge)")
                if screen.visibleFrame.size != screen.frame.size {
                    Swift.print("   Visible Area: \(Int(screen.visibleFrame.width))×\(Int(screen.visibleFrame.height))")
                }
            }
            Swift.print("\n💡 Use 'peekaboo see --screen-index N' to capture a specific screen")
        }

        @MainActor
        private func buildScreenListData(from screens: [PeekabooCore.ScreenInfo]) -> ScreenListData {
            let details = screens.map { screen in
                ScreenListData.ScreenDetails(
                    index: screen.index,
                    name: screen.name,
                    resolution: ScreenListData.Resolution(
                        width: Int(screen.frame.width),
                        height: Int(screen.frame.height)
                    ),
                    position: ScreenListData.Position(
                        x: Int(screen.frame.origin.x),
                        y: Int(screen.frame.origin.y)
                    ),
                    visibleArea: ScreenListData.Resolution(
                        width: Int(screen.visibleFrame.width),
                        height: Int(screen.visibleFrame.height)
                    ),
                    isPrimary: screen.isPrimary,
                    scaleFactor: screen.scaleFactor,
                    displayID: Int(screen.displayID)
                )
            }

            return ScreenListData(
                screens: details,
                primaryIndex: screens.firstIndex { $0.isPrimary }
            )
        }

        private func buildScreenSummary(for screens: [PeekabooCore.ScreenInfo]) -> ScreenOutput.Summary {
            let count = screens.count
            let highlights = screens.indexed().compactMap { index, screen in
                screen.isPrimary ? ScreenOutput.Summary.Highlight(
                    label: "Primary",
                    value: "\(screen.name) (Index \(index))",
                    kind: .primary
                ) : nil
            }
            return ScreenOutput.Summary(
                brief: "Found \(count) screen\(count == 1 ? "" : "s")",
                detail: nil,
                status: ScreenOutput.Summary.Status.success,
                counts: ["screens": count],
                highlights: highlights
            )
        }

        private func buildScreenMetadata() -> ScreenOutput.Metadata {
            ScreenOutput.Metadata(
                duration: 0.0,
                warnings: [],
                hints: ["Use 'peekaboo see --screen-index N' to capture a specific screen"]
            )
        }
    }
}

// MARK: - Screen List Data Model

struct ScreenListData {
    let screens: [ScreenDetails]
    let primaryIndex: Int?

    struct ScreenDetails {
        let index: Int
        let name: String
        let resolution: Resolution
        let position: Position
        let visibleArea: Resolution
        let isPrimary: Bool
        let scaleFactor: CGFloat
        let displayID: Int
    }

    struct Resolution {
        let width: Int
        let height: Int
    }

    struct Position {
        let x: Int
        let y: Int
    }
}

nonisolated extension ScreenListData: Sendable, Codable {}
nonisolated extension ScreenListData.ScreenDetails: Sendable, Codable {}
nonisolated extension ScreenListData.Resolution: Sendable, Codable {}
nonisolated extension ScreenListData.Position: Sendable, Codable {}

@MainActor
extension ListCommand.ScreensSubcommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        _ = values
    }
}
