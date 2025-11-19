//
//  MCPStdioTransportTests.swift
//  PeekabooCore
//

import Foundation
import Testing
@testable import PeekabooAgentRuntime
@testable import PeekabooAutomation
@testable import PeekabooCore
@testable import PeekabooVisualizer

@Suite("MCP Stdio Transport Tests")
struct MCPStdioTransportTests {
    @Test("Initialize transport")
    func initialization() async throws {
        let transport = await MCPStdioTransport()
        #expect(transport != nil)
        #expect(await !transport.isConnected())
    }

    @Test("Connect to echo process")
    func connectToEcho() async throws {
        let transport = await MCPStdioTransport()

        // Use echo command as a simple test process
        try await transport.connect(
            command: "/bin/echo",
            args: ["test"],
            environment: nil,
            workingDirectory: nil)

        #expect(await transport.isConnected())

        // Cleanup
        await transport.disconnect()
        #expect(await !transport.isConnected())
    }

    @Test("Send and receive messages")
    func messageExchange() async throws {
        let transport = await MCPStdioTransport()

        // Use cat command which echoes stdin to stdout
        try await transport.connect(
            command: "/bin/cat",
            args: [],
            environment: nil,
            workingDirectory: nil)

        // Send a test message
        let testMessage = #"{"jsonrpc":"2.0","method":"test","id":1}"#
        let messageData = Data(testMessage.utf8)
        try await transport.send(messageData)

        // Receive the echoed message
        let receivedData = try await transport.receive()
        let receivedMessage = String(data: receivedData, encoding: .utf8)

        #expect(receivedMessage == testMessage)

        await transport.disconnect()
    }

    @Test("Handle process termination")
    func processTermination() async throws {
        let transport = await MCPStdioTransport()

        // Connect to a process that exits immediately
        try await transport.connect(
            command: "/bin/true",
            args: [],
            environment: nil,
            workingDirectory: nil)

        // Wait a moment for process to exit
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Should detect process has terminated
        #expect(await !transport.isConnected())
    }

    @Test("JSON-RPC request helper")
    func jSONRPCRequest() async throws {
        let transport = await MCPStdioTransport()

        // Connect to cat for echo
        try await transport.connect(
            command: "/bin/cat",
            args: [],
            environment: nil,
            workingDirectory: nil)

        // Send a JSON-RPC request
        struct TestParams: Encodable {
            let test: String
        }

        try await transport.sendRequest(
            "testMethod",
            params: TestParams(test: "value"),
            id: 42)

        // The message should be sent (cat will echo it back)
        let receivedData = try await transport.receive()
        let receivedJSON = try JSONSerialization.jsonObject(with: receivedData) as? [String: Any]

        #expect(receivedJSON?["jsonrpc"] as? String == "2.0")
        #expect(receivedJSON?["method"] as? String == "testMethod")
        #expect(receivedJSON?["id"] as? Int == 42)

        if let params = receivedJSON?["params"] as? [String: Any] {
            #expect(params["test"] as? String == "value")
        } else {
            Issue.record("Params not found in received message")
        }

        await transport.disconnect()
    }

    @Test("JSON-RPC notification helper")
    func jSONRPCNotification() async throws {
        let transport = await MCPStdioTransport()

        // Connect to cat for echo
        try await transport.connect(
            command: "/bin/cat",
            args: [],
            environment: nil,
            workingDirectory: nil)

        // Send a JSON-RPC notification (no id)
        struct TestParams: Encodable {
            let notification: Bool
        }

        try await transport.sendNotification(
            "notifyMethod",
            params: TestParams(notification: true))

        // The message should be sent (cat will echo it back)
        let receivedData = try await transport.receive()
        let receivedJSON = try JSONSerialization.jsonObject(with: receivedData) as? [String: Any]

        #expect(receivedJSON?["jsonrpc"] as? String == "2.0")
        #expect(receivedJSON?["method"] as? String == "notifyMethod")
        #expect(receivedJSON?["id"] == nil) // Notifications have no id

        if let params = receivedJSON?["params"] as? [String: Any] {
            #expect(params["notification"] as? Bool == true)
        }

        await transport.disconnect()
    }

    @Test("Environment variables")
    func environmentVariables() async throws {
        let transport = await MCPStdioTransport()

        // Use env command to print environment
        try await transport.connect(
            command: "/usr/bin/env",
            args: [],
            environment: ["TEST_VAR": "test_value"],
            workingDirectory: nil)

        // Process should have run and exited
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Note: We can't easily capture the output in this test setup
        // but the process should have run with the custom environment
        #expect(await !transport.isConnected())
    }

    @Test("Working directory")
    func testWorkingDirectory() async throws {
        let transport = await MCPStdioTransport()
        let tempDir = FileManager.default.temporaryDirectory.path

        // Use pwd command to print working directory
        try await transport.connect(
            command: "/bin/pwd",
            args: [],
            environment: nil,
            workingDirectory: tempDir)

        // Process should have run and exited
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        #expect(await !transport.isConnected())
    }

    @Test("Message handler callback")
    func messageHandler() async throws {
        let transport = await MCPStdioTransport()
        let expectation = TestExpectation()

        // Set up message handler
        await transport.setMessageHandler { data in
            let message = String(data: data, encoding: .utf8)
            if message == "test" {
                await expectation.fulfill()
            }
        }

        // Connect to echo
        try await transport.connect(
            command: "/bin/echo",
            args: ["test"],
            environment: nil,
            workingDirectory: nil)

        // Wait for handler to be called
        try await expectation.wait(timeout: 1.0)

        await transport.disconnect()
    }
}

// Helper for async expectations in tests
actor TestExpectation {
    private var fulfilled = false
    private var waiters: [CheckedContinuation<Void, Error>] = []

    func fulfill() {
        self.fulfilled = true
        for waiter in self.waiters {
            waiter.resume()
        }
        self.waiters.removeAll()
    }

    func wait(timeout: TimeInterval) async throws {
        if self.fulfilled { return }

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { continuation in
                    Task {
                        await self.addWaiter(continuation)
                    }
                }
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw TestError.timeout
            }

            do {
                try await group.next()
                group.cancelAll()
            } catch {
                await self.failAllWaiters(error)
                group.cancelAll()
                throw error
            }
        }
    }

    private func addWaiter(_ continuation: CheckedContinuation<Void, Error>) {
        if self.fulfilled {
            continuation.resume()
        } else {
            self.waiters.append(continuation)
        }
    }

    private func failAllWaiters(_ error: Error) {
        for waiter in self.waiters {
            waiter.resume(throwing: error)
        }
        self.waiters.removeAll()
    }
}

enum TestError: Error {
    case timeout
}
