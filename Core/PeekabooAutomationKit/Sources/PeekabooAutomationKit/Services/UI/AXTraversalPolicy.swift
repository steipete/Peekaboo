import Foundation

@_spi(Testing) public enum AXTraversalPolicy {
    static let maxTraversalDepth = 12
    static let maxElementCount = 400
    static let maxChildrenPerNode = 50

    private static let maxWebFocusAttempts = 2
    private static let maxElementsBeforeWebFocusFallback = 20

    public static func shouldAttemptWebFocusFallback(
        attempt: Int,
        allowWebFocus: Bool,
        detectedElementCount: Int,
        hasTextField: Bool) -> Bool
    {
        guard !hasTextField else { return false }

        return attempt < self.maxWebFocusAttempts
            && allowWebFocus
            && detectedElementCount <= self.maxElementsBeforeWebFocusFallback
    }
}
