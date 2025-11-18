import Foundation
import PeekabooFoundation
import Testing
@testable import PeekabooAutomation

@Suite("Watch CLI output shape (smoke)")
struct WatchCLISmokeTests {
    @Test("Contact sheet sampling metadata is present")
    func contactSheetMetadataPresent() throws {
        let sheet = WatchContactSheet(
            path: "/tmp/contact.png",
            file: "contact.png",
            columns: 6,
            rows: 2,
            thumbSize: CGSize(width: 200, height: 200),
            sampledFrameIndexes: [0, 2, 4])
        #expect(sheet.sampledFrameIndexes.count == 3)
        #expect(sheet.columns == 6)
    }

    @Test("Diff metadata is carried through result")
    func diffMetadata() throws {
        let result = WatchCaptureResult(
            source: .live,
            videoIn: nil,
            videoOut: nil,
            frames: [],
            contactSheet: WatchContactSheet(
                path: "/tmp/contact.png",
                file: "contact.png",
                columns: 1,
                rows: 1,
                thumbSize: CGSize(width: 100, height: 100),
                sampledFrameIndexes: []),
            metadataFile: "/tmp/metadata.json",
            stats: WatchStats(
                durationMs: 1000,
                fpsIdle: 2,
                fpsActive: 8,
                fpsEffective: 1,
                framesKept: 0,
                framesDropped: 0,
                maxFramesHit: false,
                maxMbHit: false),
            scope: WatchScope(kind: .screen),
            diffAlgorithm: "fast",
            diffScale: "w256",
            options: WatchOptionsSnapshot(
                duration: 60,
                idleFps: 2,
                activeFps: 8,
                changeThresholdPercent: 2.5,
                heartbeatSeconds: 5,
                quietMsToIdle: 1000,
                maxFrames: 800,
                maxMegabytes: Int?.none,
                highlightChanges: false,
                captureFocus: CaptureFocus.auto,
                resolutionCap: 1440,
                diffStrategy: WatchCaptureOptions.DiffStrategy.fast,
                diffBudgetMs: 30),
            warnings: [])
        #expect(result.diffAlgorithm == "fast")
        #expect(result.diffScale == "w256")
        #expect(result.options.diffBudgetMs == 30)
    }
}
