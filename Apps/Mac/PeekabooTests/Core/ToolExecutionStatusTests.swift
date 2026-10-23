import Testing
@testable import Peekaboo

struct ToolExecutionStatusTests {
    @Test
    func `an error payload is a failed tool row`() {
        let result = #"{"error":"Element not found"}"#
        #expect(PeekabooAgent.toolExecutionStatus(for: result) == .failed)
    }

    @Test
    func `a cancelled payload stays cancelled when it also has an error`() {
        let result = #"{"cancelled":true,"error":"Agent execution was cancelled","success":false}"#
        #expect(PeekabooAgent.toolExecutionStatus(for: result) == .cancelled)
    }

    @Test
    func `a failed success flag is a failed tool row`() {
        let result = #"{"success":false}"#
        #expect(PeekabooAgent.toolExecutionStatus(for: result) == .failed)
    }

    @Test
    func `plain text that mentions an error stays completed`() {
        let result = "Click failed: element not found"
        #expect(PeekabooAgent.toolExecutionStatus(for: result) == .completed)
    }

    @Test
    func `a normal result stays completed`() {
        let result = #"{"success":true,"result":"clicked"}"#
        #expect(PeekabooAgent.toolExecutionStatus(for: result) == .completed)
    }
}
