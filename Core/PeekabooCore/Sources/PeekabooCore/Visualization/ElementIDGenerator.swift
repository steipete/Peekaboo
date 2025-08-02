//
//  ElementIDGenerator.swift
//  PeekabooCore
//
//  Consistent ID generation for UI elements
//

import Foundation

/// Generates consistent IDs for UI elements
@MainActor
public final class ElementIDGenerator {
    /// Shared instance for global ID generation
    public static let shared = ElementIDGenerator()

    /// Counter for each element category
    private var counters: [ElementCategory: Int] = [:]

    /// Lock for thread-safe counter access
    private let lock = NSLock()

    public init() {}

    /// Generate a unique ID for an element
    /// - Parameters:
    ///   - category: The element category
    ///   - index: Optional specific index (if nil, uses auto-increment)
    /// - Returns: Generated ID string (e.g., "B1", "T2")
    public func generateID(for category: ElementCategory, index: Int? = nil) -> String {
        self.lock.lock()
        defer { lock.unlock() }

        let prefix = category.idPrefix

        if let specificIndex = index {
            return "\(prefix)\(specificIndex)"
        }

        // Auto-increment counter for this category
        let currentCount = self.counters[category] ?? 0
        let nextIndex = currentCount + 1
        self.counters[category] = nextIndex

        return "\(prefix)\(nextIndex)"
    }

    /// Parse an ID to extract category and index
    /// - Parameter id: The ID string to parse
    /// - Returns: Tuple of category and index, or nil if invalid
    public func parseID(_ id: String) -> (category: ElementCategory, index: Int)? {
        guard !id.isEmpty else { return nil }

        // Extract prefix (usually 1-2 characters)
        let prefix = String(id.prefix(while: { $0.isLetter }))
        let indexString = String(id.dropFirst(prefix.count))

        guard !prefix.isEmpty,
              let index = Int(indexString) else { return nil }

        // Find matching category
        let category = self.findCategory(for: prefix)
        return (category, index)
    }

    /// Reset counters for a specific category or all categories
    public func resetCounters(for category: ElementCategory? = nil) {
        self.lock.lock()
        defer { lock.unlock() }

        if let category {
            self.counters[category] = 0
        } else {
            self.counters.removeAll()
        }
    }

    /// Get current counter value for a category
    public func currentCount(for category: ElementCategory) -> Int {
        self.lock.lock()
        defer { lock.unlock() }

        return self.counters[category] ?? 0
    }

    // MARK: - Private Methods

    private func findCategory(for prefix: String) -> ElementCategory {
        switch prefix {
        case "B":
            .button
        case "T":
            .textInput
        case "L":
            .link
        case "C":
            .checkbox
        case "R":
            .radioButton
        case "S":
            .slider
        case "M":
            .menu
        case "I":
            .image
        case "G":
            .container
        case "X":
            .text
        default:
            .custom(prefix)
        }
    }
}

// MARK: - Batch ID Generation

extension ElementIDGenerator {
    /// Generate IDs for a batch of elements
    /// - Parameter elements: Array of tuples containing category and optional label
    /// - Returns: Array of generated IDs
    public func generateBatchIDs(for elements: [(category: ElementCategory, label: String?)]) -> [String] {
        self.lock.lock()
        defer { lock.unlock() }

        // Group by category to maintain sequential numbering
        var categoryGroups: [ElementCategory: [(Int, String?)]] = [:]

        for (index, element) in elements.enumerated() {
            var group = categoryGroups[element.category] ?? []
            group.append((index, element.label))
            categoryGroups[element.category] = group
        }

        // Generate IDs maintaining order
        var results = Array(repeating: "", count: elements.count)

        for (category, group) in categoryGroups {
            let startIndex = self.counters[category] ?? 0

            for (offset, (originalIndex, _)) in group.enumerated() {
                let id = "\(category.idPrefix)\(startIndex + offset + 1)"
                results[originalIndex] = id
            }

            self.counters[category] = startIndex + group.count
        }

        return results
    }
}

// MARK: - DetectedElement Extension

extension ElementIDGenerator {
    /// Generate IDs for detected elements
    public func generateIDsForDetectedElements(_ elements: [DetectedElement]) -> [String: String] {
        // Create mapping of original IDs to new consistent IDs
        var idMapping: [String: String] = [:]

        // Process each element type
        let allElements: [(DetectedElement, ElementCategory)] =
            elements.map { element in
                let category = ElementCategory(elementType: element.type)
                return (element, category)
            }

        // Sort by position (top-left to bottom-right) for consistent numbering
        let sortedElements = allElements.sorted { lhs, rhs in
            let lhsBounds = lhs.0.bounds
            let rhsBounds = rhs.0.bounds

            // Sort by Y first, then X
            if abs(lhsBounds.minY - rhsBounds.minY) > 10 {
                return lhsBounds.minY < rhsBounds.minY
            }
            return lhsBounds.minX < rhsBounds.minX
        }

        // Group by category and generate IDs
        self.resetCounters()

        for (element, category) in sortedElements {
            let newID = self.generateID(for: category)
            idMapping[element.id] = newID
        }

        return idMapping
    }
}
