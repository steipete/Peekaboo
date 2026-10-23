import CoreGraphics
import Testing
@testable import PeekabooUICore

struct OverlayScreenGeometryTests {
    @Test
    func `primary display keeps an accessibility frame that is already top-left`() {
        let primary = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let element = CGRect(x: 10, y: 0, width: 20, height: 20)
        let point = OverlayScreenGeometry.swiftUICenter(
            for: element,
            on: primary,
            primaryScreen: primary)
        #expect(point.x == 20)
        #expect(point.y == 10)
    }

    @Test
    func `primary display keeps a bottom control at the bottom`() {
        let primary = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let element = CGRect(x: 10, y: 780, width: 20, height: 20)
        let point = OverlayScreenGeometry.swiftUICenter(
            for: element,
            on: primary,
            primaryScreen: primary)
        #expect(point.x == 20)
        #expect(point.y == 790)
    }

    @Test
    func `same height secondary display shifts x and keeps accessibility y`() {
        let primary = CGRect(x: 0, y: 0, width: 1728, height: 900)
        let screen = CGRect(x: 1920, y: 0, width: 1440, height: 900)
        let element = CGRect(x: 2000, y: 100, width: 40, height: 20)
        let point = OverlayScreenGeometry.swiftUICenter(
            for: element,
            on: screen,
            primaryScreen: primary)
        #expect(point.x == 100)
        #expect(point.y == 110)
        #expect(point.x >= 0 && point.x <= screen.width)
        #expect(point.y >= 0 && point.y <= screen.height)
    }

    @Test
    func `taller secondary display accounts for the primary top`() {
        let primary = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let screen = CGRect(x: 1920, y: 0, width: 1440, height: 900)
        let element = CGRect(x: 2000, y: 100, width: 40, height: 20)
        let point = OverlayScreenGeometry.swiftUICenter(
            for: element,
            on: screen,
            primaryScreen: primary)
        #expect(point.x == 100)
        #expect(point.y == 210)
    }
}
