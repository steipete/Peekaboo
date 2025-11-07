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
}
