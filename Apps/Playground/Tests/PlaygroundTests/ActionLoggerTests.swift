import Testing
@testable import Playground

@Suite("Playground action logger tests")
@MainActor
struct ActionLoggerTests {
    @Test("log records entries and updates derived state")
    func logRecordsEntries() {
        let logger = ActionLogger.shared
        logger.clearLogs()

        logger.log(.click, "Clicked button", details: "Primary CTA")

        #expect(logger.entries.count == 1)
        #expect(logger.actionCount == 1)
        #expect(logger.lastAction == "Clicked button")
        #expect(logger.entries.first?.details == "Primary CTA")
        #expect(logger.entries.first?.category == .click)
        #expect(logger.categoryCounts[.click] == 1)
    }

    @Test("clearLogs resets counters and appends status message")
    func clearLogsResetsState() {
        let logger = ActionLogger.shared
        logger.clearLogs()
        logger.log(.text, "Typed name")

        logger.clearLogs()

        #expect(logger.entries.isEmpty)
        #expect(logger.actionCount == 0)
        #expect(logger.lastAction == "Logs cleared")
        #expect(logger.categoryCounts.values.allSatisfy { $0 == 0 })
    }

    @Test("exportLogs emits human readable lines")
    func exportLogsIncludesEntries() {
        let logger = ActionLogger.shared
        logger.clearLogs()

        logger.log(.menu, "Opened File menu")
        logger.log(.control, "Toggled switch", details: "Dark Mode")

        let exported = logger.exportLogs()

        #expect(exported.contains("Peekaboo Playground Action Log"))
        #expect(exported.contains("Opened File menu"))
        #expect(exported.contains("Toggled switch"))
    }

    @Test("log enforces bounded history")
    func logKeepsBoundedHistory() {
        let logger = ActionLogger.shared
        logger.clearLogs()

        for index in 0...ActionLogger.entryLimit {
            logger.log(.click, "Event \(index)")
        }

        #expect(logger.entries.count == ActionLogger.entryLimit)
        #expect(logger.categoryCounts[.click] == ActionLogger.entryLimit)
        #expect(logger.actionCount == ActionLogger.entryLimit + 1)
        #expect(logger.entries.first?.message == "Event 1")
    }
}
