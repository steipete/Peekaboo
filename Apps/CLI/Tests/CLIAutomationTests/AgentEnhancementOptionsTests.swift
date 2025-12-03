//
//  AgentEnhancementOptionsTests.swift
//  CLIAutomationTests
//
//  Tests for AgentEnhancementOptions configuration presets.
//

import Testing

@testable import PeekabooAgentRuntime

@Suite("Agent Enhancement Options")
struct AgentEnhancementOptionsTests {
    // MARK: - Default Preset Tests

    @Test("Default preset enables context awareness only")
    func defaultPresetConfiguration() {
        let options = AgentEnhancementOptions.default

        #expect(options.contextAware == true)
        #expect(options.verifyActions == false)
        #expect(options.smartCapture == false)
        #expect(options.regionFocusAfterAction == false)
    }

    @Test("Default preset has sensible threshold values")
    func defaultPresetThresholds() {
        let options = AgentEnhancementOptions.default

        #expect(options.changeThreshold == 0.05)
        #expect(options.regionCaptureRadius == 300)
        #expect(options.maxVerificationRetries == 1)
    }

    // MARK: - Minimal Preset Tests

    @Test("Minimal preset disables all enhancements")
    func minimalPresetConfiguration() {
        let options = AgentEnhancementOptions.minimal

        #expect(options.contextAware == false)
        #expect(options.verifyActions == false)
        #expect(options.smartCapture == false)
        #expect(options.regionFocusAfterAction == false)
    }

    // MARK: - Full Preset Tests

    @Test("Full preset enables all enhancements")
    func fullPresetConfiguration() {
        let options = AgentEnhancementOptions.full

        #expect(options.contextAware == true)
        #expect(options.verifyActions == true)
        #expect(options.smartCapture == true)
        #expect(options.regionFocusAfterAction == true)
    }

    @Test("Full preset has increased retry count")
    func fullPresetRetryCount() {
        let options = AgentEnhancementOptions.full

        #expect(options.maxVerificationRetries == 2)
    }

    // MARK: - Verified Preset Tests

    @Test("Verified preset enables context and verification only")
    func verifiedPresetConfiguration() {
        let options = AgentEnhancementOptions.verified

        #expect(options.contextAware == true)
        #expect(options.verifyActions == true)
        #expect(options.smartCapture == false)
        #expect(options.regionFocusAfterAction == false)
    }

    // MARK: - Custom Configuration Tests

    @Test("Custom configuration preserves all values")
    func customConfiguration() {
        let options = AgentEnhancementOptions(
            contextAware: true,
            verifyActions: true,
            maxVerificationRetries: 5,
            verifyActionTypes: [.click, .type],
            smartCapture: true,
            changeThreshold: 0.1,
            regionFocusAfterAction: true,
            regionCaptureRadius: 500
        )

        #expect(options.contextAware == true)
        #expect(options.verifyActions == true)
        #expect(options.maxVerificationRetries == 5)
        #expect(options.verifyActionTypes == [.click, .type])
        #expect(options.smartCapture == true)
        #expect(options.changeThreshold == 0.1)
        #expect(options.regionFocusAfterAction == true)
        #expect(options.regionCaptureRadius == 500)
    }
}

// MARK: - VerifiableActionType Tests

@Suite("Verifiable Action Types")
struct VerifiableActionTypeTests {
    @Test("All action types are mutating")
    func allActionTypesAreMutating() {
        for actionType in VerifiableActionType.allCases {
            #expect(actionType.isMutating == true, "Expected \(actionType.rawValue) to be mutating")
        }
    }

    @Test("Action types have correct raw values")
    func actionTypeRawValues() {
        #expect(VerifiableActionType.click.rawValue == "click")
        #expect(VerifiableActionType.type.rawValue == "type")
        #expect(VerifiableActionType.scroll.rawValue == "scroll")
        #expect(VerifiableActionType.hotkey.rawValue == "hotkey")
        #expect(VerifiableActionType.drag.rawValue == "drag")
        #expect(VerifiableActionType.launchApp.rawValue == "launch_app")
        #expect(VerifiableActionType.menu.rawValue == "menu")
        #expect(VerifiableActionType.dialog.rawValue == "dialog")
    }

    @Test("Action types can be initialized from raw values")
    func actionTypeFromRawValue() {
        #expect(VerifiableActionType(rawValue: "click") == .click)
        #expect(VerifiableActionType(rawValue: "launch_app") == .launchApp)
        #expect(VerifiableActionType(rawValue: "invalid") == nil)
    }
}
