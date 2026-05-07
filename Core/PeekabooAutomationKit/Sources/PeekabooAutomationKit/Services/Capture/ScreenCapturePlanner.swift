import CoreGraphics
import Foundation

@_spi(Testing) public enum ScreenCapturePlanner {
    public enum FrameSourcePolicy: Sendable {
        case fastStream
        case singleShot
    }

    /// Convert a global desktop-space rectangle to a display-local `sourceRect`.
    ///
    /// ScreenCaptureKit expects `SCStreamConfiguration.sourceRect` in display-local logical coordinates.
    ///
    /// `SCWindow.frame` and `SCDisplay.frame` returned from `SCShareableContent` are in global desktop
    /// coordinates, matching `NSScreen.frame`, including non-zero / negative origins for secondary displays.
    ///
    /// When using a display-bound filter (`SCContentFilter(display:...)`), passing a global rect directly can
    /// crop the wrong region or fail with an invalid parameter error on non-primary displays.
    public static func displayLocalSourceRect(globalRect: CGRect, displayFrame: CGRect) -> CGRect {
        globalRect.offsetBy(dx: -displayFrame.origin.x, dy: -displayFrame.origin.y)
    }

    public static func frameSourcePolicy(
        for mode: CaptureMode,
        windowID: CGWindowID?) -> FrameSourcePolicy
    {
        if windowID != nil {
            return .singleShot
        }

        switch mode {
        case .screen, .area, .multi:
            return .fastStream
        case .window, .frontmost:
            return .singleShot
        }
    }
}
