//
//  ErrorHandlingTests.swift
//  PeekabooCLI
//

import Testing
@testable import PeekabooCLI
@testable import PeekabooCore

@Suite("Focus Error Mapping", .tags(.safe))
struct FocusErrorMappingTests {
    @Test("application not running maps to APP_NOT_FOUND")
    func applicationNotRunning() {
        let code = errorCode(for: .applicationNotRunning("Finder"))
        #expect(code == .APP_NOT_FOUND)
    }

    @Test("AX element missing maps to WINDOW_NOT_FOUND")
    func axElementMissing() {
        let code = errorCode(for: .axElementNotFound(42))
        #expect(code == .WINDOW_NOT_FOUND)
    }

    @Test("focus verification timeout maps to TIMEOUT")
    func focusVerificationTimeout() {
        let code = errorCode(for: .focusVerificationTimeout(100))
        #expect(code == .TIMEOUT)
    }

    @Test("timeout waiting for condition maps to TIMEOUT")
    func waitForConditionTimeout() {
        let code = errorCode(for: .timeoutWaitingForCondition)
        #expect(code == .TIMEOUT)
    }
}
