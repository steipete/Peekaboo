// Models.swift - Contains core data models and type aliases

import Foundation

// Type alias for element attributes dictionary
public typealias ElementAttributes = [String: AnyCodable]

public struct AXElement: Codable {
    public var attributes: ElementAttributes?
    public var path: [String]?

    public init(attributes: ElementAttributes?, path: [String]? = nil) {
        self.attributes = attributes
        self.path = path
    }
}

// MARK: - Search Log Entry Model (for stderr JSON logging)
public struct SearchLogEntry: Codable {
    public let d: Int // depth
    public let eR: String? // elementRole
    public let eT: String? // elementTitle
    public let eI: String? // elementIdentifier
    public let mD: Int // maxDepth
    public let c: [String: String]? // criteria (abbreviated)
    public let s: String // status (e.g., "vis", "found", "noMatch", "maxD")
    public let iM: Bool? // isMatch (true, false, or nil if not applicable for this status)

    // Public initializer
    public init(d: Int, eR: String?, eT: String?, eI: String?, mD: Int, c: [String: String]?, s: String, iM: Bool?) {
        self.d = d
        self.eR = eR
        self.eT = eT
        self.eI = eI
        self.mD = mD
        self.c = c
        self.s = s
        self.iM = iM
    }
}
