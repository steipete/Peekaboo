import Foundation

public enum AXAttributeValueType {
    case axElement
    case arrayOfAXElements
    case axElementArray // Alias for arrayOfAXElements
    case string
    case attributedString // CFAttributedString
    case number // CFNumber can be Int, Double, etc.
    case boolean // CFBoolean
    case url // CFURL
    case point // AXValue kAXValueCGPointType
    case size // AXValue kAXValueCGSizeType
    case rect // AXValue kAXValueCGRectType
    case range // AXValue kAXValueCFRangeType
    case array // Generic CFArray (if not arrayOfAXElements)
    case emptyArray // Empty CFArray
    case dictionary // Generic CFDictionary
    case data // CFData
    case date // CFDate
    case unknown // Type couldn't be determined or is not explicitly handled
    case error // Error fetching attribute
    case noValue // Attribute exists but has no value (e.g. kAXValueAttribute on a static text sometimes)
}
