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
    func `a window missing from the catalog stays hoverable`() {
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

    @Test
    func `a floating palette above a document window wins the hover`() {
        let document = (ownerPID: 1, frames: [
            CGRect(x: 0, y: 0, width: 400, height: 300),
            CGRect(x: 100, y: 100, width: 60, height: 20),
        ])
        let palette = (ownerPID: 1, frames: [
            CGRect(x: 80, y: 80, width: 120, height: 80),
            CGRect(x: 90, y: 90, width: 100, height: 40),
        ])
        // CGWindowList lists the higher-level palette before the document window.
        let order = OverlayHitTesting.windowOrder(
            elementGroups: [document, palette],
            onScreenFrontToBack: [
                (ownerPID: 1, bounds: CGRect(x: 80, y: 80, width: 120, height: 80)),
                (ownerPID: 1, bounds: CGRect(x: 0, y: 0, width: 400, height: 300)),
            ],
            frontmostPID: 1)
        #expect(order == [1, 0])
        let hit = OverlayHitTesting.frontmostElementIndex(
            containing: CGPoint(x: 120, y: 110),
            windowsFrontToBack: order.map { [document, palette][$0].frames })
        #expect(hit?.window == 0)
        #expect(hit?.element == 1)
    }

    @Test
    func `a covering window from another app hides the document under it`() {
        let document = (ownerPID: 1, frames: [
            CGRect(x: 0, y: 0, width: 400, height: 300),
            CGRect(x: 100, y: 100, width: 60, height: 20),
        ])
        let layers = OverlayHitTesting.hoverLayers(
            elementGroups: [document],
            onScreenFrontToBack: [
                (ownerPID: 9, bounds: CGRect(x: 80, y: 80, width: 200, height: 100)),
                (ownerPID: 1, bounds: CGRect(x: 0, y: 0, width: 400, height: 300)),
            ],
            frontmostPID: 1)
        #expect(layers == [.occluder(CGRect(x: 80, y: 80, width: 200, height: 100)), .window(0)])
        #expect(OverlayHitTesting.hoveredElement(
            containing: CGPoint(x: 120, y: 110),
            layers: layers,
            groupFrames: [document.frames]) == nil)
        let outside = OverlayHitTesting.hoveredElement(
            containing: CGPoint(x: 20, y: 20),
            layers: layers,
            groupFrames: [document.frames])
        #expect(outside?.group == 0)
        #expect(outside?.element == 0)
    }

    @Test
    func `an unmatched window of a tracked app does not hide anything`() {
        let document = (ownerPID: 1, frames: [CGRect(x: 0, y: 0, width: 400, height: 300)])
        let drifted = (ownerPID: 2, frames: [CGRect(x: 500, y: 0, width: 100, height: 100)])
        let layers = OverlayHitTesting.hoverLayers(
            elementGroups: [document, drifted],
            onScreenFrontToBack: [
                (ownerPID: 2, bounds: CGRect(x: 0, y: 0, width: 600, height: 300)),
                (ownerPID: 1, bounds: CGRect(x: 0, y: 0, width: 400, height: 300)),
            ],
            frontmostPID: 1)
        #expect(layers == [.window(0), .window(1)])
    }

    @Test
    func `nothing matching the catalog keeps the fallback order without occluders`() {
        let first = (ownerPID: 1, frames: [CGRect(x: 0, y: 0, width: 100, height: 100)])
        let layers = OverlayHitTesting.hoverLayers(
            elementGroups: [first],
            onScreenFrontToBack: [(ownerPID: 9, bounds: CGRect(x: 0, y: 0, width: 50, height: 50))],
            frontmostPID: 1)
        #expect(layers == [.window(0)])
    }

    @Test
    func `a popup menu of the hovered app does not hide its own items`() {
        let host = (ownerPID: 1, frames: [
            CGRect(x: 0, y: 0, width: 400, height: 300),
            CGRect(x: 100, y: 100, width: 80, height: 20),
        ])
        let layers = OverlayHitTesting.hoverLayers(
            elementGroups: [host],
            onScreenFrontToBack: [
                (ownerPID: 1, bounds: CGRect(x: 100, y: 120, width: 160, height: 200)),
                (ownerPID: 1, bounds: CGRect(x: 0, y: 0, width: 400, height: 300)),
            ],
            frontmostPID: 1)
        #expect(layers == [.window(0)])
    }

    @Test
    func `a popup item outside its host window stays hoverable ahead of windows behind`() {
        let host = (ownerPID: 1, frames: [
            CGRect(x: 0, y: 0, width: 400, height: 300),
            CGRect(x: 100, y: 280, width: 80, height: 20),
            CGRect(x: 100, y: 320, width: 120, height: 20),
        ])
        let behind = (ownerPID: 2, frames: [
            CGRect(x: 0, y: 300, width: 400, height: 300),
            CGRect(x: 90, y: 310, width: 200, height: 60),
        ])
        let layers = OverlayHitTesting.hoverLayers(
            elementGroups: [host, behind],
            onScreenFrontToBack: [
                (ownerPID: 1, bounds: CGRect(x: 0, y: 0, width: 400, height: 300)),
                (ownerPID: 2, bounds: CGRect(x: 0, y: 300, width: 400, height: 300)),
            ],
            frontmostPID: 1)
        let hit = OverlayHitTesting.hoveredElement(
            containing: CGPoint(x: 130, y: 330),
            layers: layers,
            groupFrames: [host.frames, behind.frames])
        #expect(hit?.group == 0)
        #expect(hit?.element == 2)
    }
}
