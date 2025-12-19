//
//  SmartCaptureTypesTests.swift
//  CLIAutomationTests
//
//  Tests for SmartCaptureResult and related types.
//

import CoreGraphics
import Foundation
import Testing

@testable import PeekabooAutomation

@Suite("Smart Capture Result")
struct SmartCaptureResultTests {
    @Test("Fresh capture result indicates change")
    func freshCaptureResult() {
        let now = Date()
        let result = SmartCaptureResult(
            image: nil,
            changed: true,
            metadata: .fresh(capturedAt: now)
        )

        #expect(result.changed == true)
        if case let .fresh(capturedAt) = result.metadata {
            #expect(capturedAt == now)
        } else {
            Issue.record("Expected fresh metadata")
        }
    }

    @Test("Unchanged capture result indicates no change")
    func unchangedCaptureResult() {
        let since = Date()
        let result = SmartCaptureResult(
            image: nil,
            changed: false,
            metadata: .unchanged(since: since)
        )

        #expect(result.changed == false)
        #expect(result.image == nil)
        if case let .unchanged(sinceDate) = result.metadata {
            #expect(sinceDate == since)
        } else {
            Issue.record("Expected unchanged metadata")
        }
    }

    @Test("Region capture includes bounds")
    func regionCaptureResult() {
        let center = CGPoint(x: 500, y: 300)
        let radius: CGFloat = 200
        let bounds = CGRect(x: 300, y: 100, width: 400, height: 400)

        let result = SmartCaptureResult(
            image: nil,
            changed: true,
            metadata: .region(center: center, radius: radius, bounds: bounds, contextThumbnail: nil)
        )

        #expect(result.changed == true)
        if case let .region(c, r, b, _) = result.metadata {
            #expect(c == center)
            #expect(r == radius)
            #expect(b == bounds)
        } else {
            Issue.record("Expected region metadata")
        }
    }
}

@Suite("Change Area")
struct ChangeAreaTests {
    @Test("Change area stores all properties")
    func changeAreaProperties() {
        let rect = CGRect(x: 10, y: 20, width: 100, height: 50)
        let area = ChangeArea(rect: rect, changeType: .contentAdded, confidence: 0.8)

        #expect(area.rect == rect)
        #expect(area.changeType == .contentAdded)
        #expect(area.confidence == 0.8)
    }

    @Test("All change types are available")
    func changeTypeEnumeration() {
        let types: [ChangeType] = [
            .contentAdded,
            .contentRemoved,
            .contentModified,
            .windowMoved,
            .dialogAppeared
        ]

        #expect(types.count == 5)
    }
}

@Suite("Smart Capture Error")
struct SmartCaptureErrorTests {
    @Test("Image conversion error has description")
    func imageConversionErrorDescription() {
        let error = SmartCaptureError.imageConversionFailed

        #expect(error.errorDescription != nil)
        #expect(error.errorDescription!.contains("CGImage") == true)
    }
}
