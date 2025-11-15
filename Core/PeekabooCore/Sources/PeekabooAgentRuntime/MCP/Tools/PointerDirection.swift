import CoreGraphics

/// Utility to convert delta between two points into a compass-style label.
func pointerDirection(from start: CGPoint, to end: CGPoint) -> String? {
    let dx = end.x - start.x
    let dy = end.y - start.y
    let distance = hypot(dx, dy)
    guard distance >= 1 else { return nil }

    let angle = atan2(dy, dx)
    // Map angle to 8 compass directions (E, NE, N, NW, W, SW, S, SE)
    let directions = ["E", "NE", "N", "NW", "W", "SW", "S", "SE"]
    let normalized = (angle + .pi) / (2 * .pi)
    var index = Int(round(normalized * 8)) % 8
    if index < 0 { index += 8 }
    return directions[index]
}
