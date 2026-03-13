//
//  ErrorHandlingTests.swift
//  PeekabooCLI
//

import Testing
@testable import PeekabooCLI
@testable import PeekabooCore

@Suite(.tags(.safe))
struct FocusErrorMappingTests {
    @Test
    func `application not running maps to APP_NOT_FOUND`() {
        let code = errorCode(for: .applicationNotRunning("Finder"))
        #expect(code == .APP_NOT_FOUND)
    }

    @Test
    func `AX element missing maps to WINDOW_NOT_FOUND`() {
        let code = errorCode(for: .axElementNotFound(42))
        #expect(code == .WINDOW_NOT_FOUND)
    }

    @Test
    func `focus verification timeout maps to TIMEOUT`() {
        let code = errorCode(for: .focusVerificationTimeout(100))
        #expect(code == .TIMEOUT)
    }

    @Test
    func `timeout waiting for condition maps to TIMEOUT`() {
        let code = errorCode(for: .timeoutWaitingForCondition)
        #expect(code == .TIMEOUT)
    }
}
