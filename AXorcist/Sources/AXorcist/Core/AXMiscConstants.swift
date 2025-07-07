// AXMiscConstants.swift - Miscellaneous accessibility constants

import Foundation

public enum AXMiscConstants {
    // Configuration Constants
    public static let maxCollectAllHits = 200 // Default max elements for collect_all if not specified in command
    public static let defaultMaxDepthSearch = 20 // Default max recursion depth for search
    public static let defaultMaxDepthCollectAll = 15 // Default max recursion depth for collect_all
    public static let axBinaryVersion = "1.1.7" // Updated version
    public static let binaryVersion = "1.1.7" // Updated version without AX prefix

    // String constant for "not available"
    public static let kAXNotAvailableString = "n/a"

    // MARK: - Custom Application/Computed Keys

    public static let focusedApplicationKey = "focused"
    public static let computedNameAttributeKey = "ComputedName"
    public static let isClickableAttributeKey = "IsClickable"
    public static let isIgnoredAttributeKey = "IsIgnored" // Used in AttributeMatcher
    public static let computedPathAttributeKey = "ComputedPath"
}
