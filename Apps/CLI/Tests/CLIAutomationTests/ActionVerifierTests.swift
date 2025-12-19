//
//  ActionVerifierTests.swift
//  CLIAutomationTests
//
//  Tests for ActionVerifier and related types.
//

import CoreGraphics
import Foundation
import Testing

@testable import PeekabooAgentRuntime

@Suite("Action Descriptor")
struct ActionDescriptorTests {
    @Test("Action descriptor stores all properties")
    func actionDescriptorProperties() {
        let point = CGPoint(x: 100, y: 200)
        let timestamp = Date()

        let descriptor = ActionDescriptor(
            toolName: "click",
            arguments: ["element": "Button"],
            targetElement: "Submit Button",
            targetPoint: point,
            timestamp: timestamp
        )

        #expect(descriptor.toolName == "click")
        #expect(descriptor.arguments == ["element": "Button"])
        #expect(descriptor.targetElement == "Submit Button")
        #expect(descriptor.targetPoint == point)
        #expect(descriptor.timestamp == timestamp)
    }

    @Test("Action descriptor with minimal properties")
    func actionDescriptorMinimal() {
        let descriptor = ActionDescriptor(
            toolName: "hotkey",
            arguments: ["keys": "cmd+c"]
        )

        #expect(descriptor.toolName == "hotkey")
        #expect(descriptor.arguments == ["keys": "cmd+c"])
        #expect(descriptor.targetElement == nil)
        #expect(descriptor.targetPoint == nil)
    }

    @Test("Action descriptor uses current date by default")
    func actionDescriptorDefaultTimestamp() {
        let before = Date()
        let descriptor = ActionDescriptor(
            toolName: "type",
            arguments: ["text": "Hello"]
        )
        let after = Date()

        #expect(descriptor.timestamp >= before)
        #expect(descriptor.timestamp <= after)
    }
}

@Suite("Verification Result")
struct VerificationResultTests {
    @Test("Successful verification result")
    func successfulVerification() {
        let result = VerificationResult(
            success: true,
            confidence: 0.95,
            observation: "Button clicked successfully",
            suggestion: nil
        )

        #expect(result.success == true)
        #expect(result.confidence == 0.95)
        #expect(result.observation == "Button clicked successfully")
        #expect(result.suggestion == nil)
        #expect(result.shouldRetry == false)
    }

    @Test("Failed verification with high confidence triggers retry")
    func failedHighConfidenceTriggersRetry() {
        let result = VerificationResult(
            success: false,
            confidence: 0.85,
            observation: "Button not found",
            suggestion: "Try clicking on coordinates instead"
        )

        #expect(result.success == false)
        #expect(result.shouldRetry == true)
    }

    @Test("Failed verification with low confidence does not trigger retry")
    func failedLowConfidenceNoRetry() {
        let result = VerificationResult(
            success: false,
            confidence: 0.4,
            observation: "Uncertain about result",
            suggestion: nil
        )

        #expect(result.success == false)
        #expect(result.shouldRetry == false)
    }

    @Test("Retry threshold is at 0.6 confidence")
    func retryThreshold() {
        let atThreshold = VerificationResult(
            success: false,
            confidence: 0.6,
            observation: "At threshold",
            suggestion: nil
        )
        #expect(atThreshold.shouldRetry == false)

        let aboveThreshold = VerificationResult(
            success: false,
            confidence: 0.61,
            observation: "Above threshold",
            suggestion: nil
        )
        #expect(aboveThreshold.shouldRetry == true)
    }
}

@Suite("Verification Error")
struct VerificationErrorTests {
    @Test("Image conversion error has correct description")
    func imageConversionErrorDescription() {
        let error = VerificationError.imageConversionFailed

        #expect(error.errorDescription?.contains("convert screenshot") == true)
    }

    @Test("AI call error includes underlying error")
    func aiCallErrorDescription() {
        struct TestError: Error, LocalizedError {
            var errorDescription: String? { "Test failure" }
        }

        let error = VerificationError.aiCallFailed(underlying: TestError())

        #expect(error.errorDescription?.contains("AI verification") == true)
        #expect(error.errorDescription?.contains("Test failure") == true)
    }

    @Test("Parse error includes response preview")
    func parseErrorDescription() {
        let error = VerificationError.parseError(response: "Invalid JSON response")

        #expect(error.errorDescription?.contains("parse") == true)
        #expect(error.errorDescription?.contains("Invalid JSON") == true)
    }
}
