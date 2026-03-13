//
//  DesktopContextTypesTests.swift
//  CLIAutomationTests
//
//  Tests for DesktopContext and FocusedWindowInfo types.
//

import CoreGraphics
import Foundation
import Testing
@testable import PeekabooAgentRuntime

struct DesktopContextTests {
    @Test
    func `Desktop context stores all properties`() {
        let windowInfo = FocusedWindowInfo(
            appName: "Safari",
            title: "Apple",
            bounds: CGRect(x: 0, y: 0, width: 1200, height: 800),
            processId: 12345
        )
        let cursor = CGPoint(x: 500, y: 300)
        let timestamp = Date()

        let context = DesktopContext(
            focusedWindow: windowInfo,
            cursorPosition: cursor,
            clipboardPreview: "Some text",
            recentApps: ["Safari", "Terminal", "Xcode"],
            timestamp: timestamp
        )

        #expect(context.focusedWindow?.appName == "Safari")
        #expect(context.cursorPosition == cursor)
        #expect(context.clipboardPreview == "Some text")
        #expect(context.recentApps.count == 3)
        #expect(context.timestamp == timestamp)
    }

    @Test
    func `Desktop context with nil values`() {
        let context = DesktopContext(
            focusedWindow: nil,
            cursorPosition: nil,
            clipboardPreview: nil,
            recentApps: [],
            timestamp: Date()
        )

        #expect(context.focusedWindow == nil)
        #expect(context.cursorPosition == nil)
        #expect(context.clipboardPreview == nil)
        #expect(context.recentApps.isEmpty)
    }
}

struct FocusedWindowInfoTests {
    @Test
    func `Focused window info stores all properties`() {
        let bounds = CGRect(x: 100, y: 50, width: 800, height: 600)
        let info = FocusedWindowInfo(
            appName: "Terminal",
            title: "bash — 80×24",
            bounds: bounds,
            processId: 54321
        )

        #expect(info.appName == "Terminal")
        #expect(info.title == "bash — 80×24")
        #expect(info.bounds == bounds)
        #expect(info.processId == 54321)
    }

    @Test
    func `Focused window info with nil bounds`() {
        let info = FocusedWindowInfo(
            appName: "Finder",
            title: "",
            bounds: nil,
            processId: 1
        )

        #expect(info.appName == "Finder")
        #expect(info.title.isEmpty)
        #expect(info.bounds == nil)
    }

    @Test
    func `Focused window info with empty title`() {
        let info = FocusedWindowInfo(
            appName: "Activity Monitor",
            title: "",
            bounds: CGRect(x: 0, y: 0, width: 500, height: 400),
            processId: 999
        )

        #expect(info.title.isEmpty)
    }
}
