import CoreGraphics
import Testing
@testable import PeekabooUICore

struct OverlayHitTestingTests {
    @Test
    func `a control inside a window wins over the window`() {
        let window = CGRect(x: 0, y: 0, width: 400, height: 300)
        let button = CGRect(x: 20, y: 20, width: 40, height: 40)
        let index = OverlayHitTesting.smallestIndex(
            containing: CGPoint(x: 30, y: 30),
            in: [window, button])
        #expect(index == 1)
    }

    @Test
    func `a point on the window but outside the control keeps the window`() {
        let window = CGRect(x: 0, y: 0, width: 400, height: 300)
        let button = CGRect(x: 20, y: 20, width: 40, height: 40)
        let index = OverlayHitTesting.smallestIndex(
            containing: CGPoint(x: 10, y: 10),
            in: [window, button])
        #expect(index == 0)
    }

    @Test
    func `a zero area frame does not hide the control`() {
        let empty = CGRect(x: 30, y: 30, width: 0, height: 0)
        let button = CGRect(x: 20, y: 20, width: 40, height: 40)
        let index = OverlayHitTesting.smallestIndex(
            containing: CGPoint(x: 30, y: 30),
            in: [empty, button])
        #expect(index == 1)
    }

    @Test
    func `a covered control does not beat the front window`() {
        let frontWindow = CGRect(x: 0, y: 0, width: 400, height: 300)
        let frontButton = CGRect(x: 20, y: 20, width: 80, height: 40)
        let backWindow = CGRect(x: 0, y: 0, width: 400, height: 300)
        let backButton = CGRect(x: 20, y: 20, width: 10, height: 10)
        let hit = OverlayHitTesting.frontmostElementIndex(
            containing: CGPoint(x: 25, y: 25),
            windowsFrontToBack: [
                [frontWindow, frontButton],
                [backWindow, backButton],
            ])
        #expect(hit?.window == 0)
        #expect(hit?.element == 1)
    }

    @Test
    func `a point outside the front window can hit the window behind it`() {
        let frontWindow = CGRect(x: 0, y: 0, width: 100, height: 100)
        let backWindow = CGRect(x: 300, y: 300, width: 80, height: 40)
        let hit = OverlayHitTesting.frontmostElementIndex(
            containing: CGPoint(x: 310, y: 310),
            windowsFrontToBack: [
                [frontWindow],
                [backWindow],
            ])
        #expect(hit?.window == 1)
        #expect(hit?.element == 0)
    }

    @Test
    func `on-screen order puts the front window ahead of the frontmost app`() {
        let back = (ownerPID: 1, frames: [CGRect(x: 0, y: 0, width: 200, height: 100)])
        let front = (ownerPID: 2, frames: [CGRect(x: 10, y: 10, width: 180, height: 90)])
        let order = OverlayHitTesting.windowOrder(
            elementGroups: [back, front],
            onScreenFrontToBack: [
                (ownerPID: 2, bounds: CGRect(x: 10, y: 10, width: 180, height: 90)),
                (ownerPID: 1, bounds: CGRect(x: 0, y: 0, width: 200, height: 100)),
            ],
            frontmostPID: 1)
        #expect(order == [1, 0])
    }

    @Test
    func `cascaded windows of the same size stay in catalog order`() {
        let back = (ownerPID: 1, frames: [CGRect(x: 0, y: 0, width: 100, height: 100)])
        let front = (ownerPID: 2, frames: [CGRect(x: 30, y: 30, width: 100, height: 100)])
        let order = OverlayHitTesting.windowOrder(
            elementGroups: [back, front],
            onScreenFrontToBack: [
                (ownerPID: 2, bounds: CGRect(x: 30, y: 30, width: 100, height: 100)),
                (ownerPID: 1, bounds: CGRect(x: 0, y: 0, width: 100, height: 100)),
            ],
            frontmostPID: 1)
        #expect(order == [1, 0])
    }

    @Test
    func `a window missing from the layer zero catalog stays hoverable`() {
        let matched = (ownerPID: 1, frames: [CGRect(x: 0, y: 0, width: 200, height: 100)])
        let palette = (ownerPID: 2, frames: [CGRect(x: 400, y: 40, width: 80, height: 40)])
        let order = OverlayHitTesting.windowOrder(
            elementGroups: [matched, palette],
            onScreenFrontToBack: [
                (ownerPID: 1, bounds: CGRect(x: 0, y: 0, width: 200, height: 100)),
            ],
            frontmostPID: 1)
        #expect(order == [0, 1])
    }

    @Test
    func `an appkit pointer at the top of the primary display stays near accessibility y zero`() {
        let primary = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let point = OverlayHitTesting.accessibilityPoint(
            fromAppKit: CGPoint(x: 20, y: 790),
            primaryScreen: primary)
        #expect(point.x == 20)
        #expect(point.y == 10)
    }

    @Test
    func `a point outside every frame has no match`() {
        let window = CGRect(x: 0, y: 0, width: 40, height: 40)
        let index = OverlayHitTesting.smallestIndex(
            containing: CGPoint(x: 80, y: 80),
            in: [window])
        #expect(index == nil)
    }
}
