// GeometryHelpers.swift - Helper functions for geometry type conversions

import CoreGraphics
import Foundation

// Helper functions to convert CoreGraphics types to dictionaries for JSON serialization
// These are needed because AnyCodable might not handle them directly as dictionaries.
func NSPointToDictionary(_ point: CGPoint) -> [String: CGFloat] {
    ["x": point.x, "y": point.y]
}

func NSSizeToDictionary(_ size: CGSize) -> [String: CGFloat] {
    ["width": size.width, "height": size.height]
}

func NSRectToDictionary(_ rect: CGRect) -> [String: Any] { // Changed to Any for origin/size
    [
        "x": rect.origin.x,
        "y": rect.origin.y,
        "width": rect.size.width,
        "height": rect.size.height,
    ]
}
