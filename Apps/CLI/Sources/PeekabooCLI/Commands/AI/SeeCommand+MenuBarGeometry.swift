import AppKit
import CoreGraphics
import Foundation
import PeekabooCore
import PeekabooFoundation

@MainActor
extension SeeCommand {
    func menuBarRect() throws -> CGRect {
        guard let mainScreen = NSScreen.main ?? NSScreen.screens.first else {
            throw PeekabooError.captureFailed("No main screen found")
        }

        let menuBarHeight = self.menuBarHeight(for: mainScreen)
        return CGRect(
            x: mainScreen.frame.origin.x,
            y: mainScreen.frame.origin.y + mainScreen.frame.height - menuBarHeight,
            width: mainScreen.frame.width,
            height: menuBarHeight
        )
    }

    func menuBarHeight(for screen: NSScreen?) -> CGFloat {
        guard let screen else { return 24.0 }
        let height = max(0, screen.frame.maxY - screen.visibleFrame.maxY)
        return height > 0 ? height : 24.0
    }

    func menuBarHeight(for screen: MenuBarPopoverDetector.ScreenBounds) -> CGFloat {
        let height = max(0, screen.frame.maxY - screen.visibleFrame.maxY)
        return height > 0 ? height : 24.0
    }

    func clampRectToScreens(_ rect: CGRect) -> CGRect? {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return nil }
        for screen in screens where screen.frame.intersects(rect) {
            return rect.intersection(screen.frame)
        }
        return rect
    }

    func screenForMenuBarX(_ x: CGFloat) -> NSScreen? {
        if let screen = NSScreen.screens.first(where: { $0.frame.minX <= x && x <= $0.frame.maxX }) {
            return screen
        }
        return NSScreen.main ?? NSScreen.screens.first
    }
}
