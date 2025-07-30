//
//  Element+Search.swift
//  AXorcist
//
//  Provides search functionality for accessibility elements
//

import ApplicationServices
import Foundation

// MARK: - Search Options

/// Options for customizing element search behavior
public struct ElementSearchOptions {
    /// Maximum depth to search (0 = unlimited)
    public var maxDepth: Int = 0

    /// Whether to search case-insensitively (default: true)
    public var caseInsensitive: Bool = true

    /// Whether to search only visible elements
    public var visibleOnly: Bool = false

    /// Whether to search only enabled elements
    public var enabledOnly: Bool = false

    /// Roles to include in search (empty = all roles)
    public var includeRoles: Set<String> = []

    /// Roles to exclude from search
    public var excludeRoles: Set<String> = []

    public init() {}
}

// MARK: - Element Search Extensions

public extension Element {

    /// Search for elements matching a query string
    /// - Parameters:
    ///   - query: The search query to match against element properties
    ///   - options: Search options to customize behavior
    /// - Returns: Array of matching elements
    @MainActor
    func searchElements(matching query: String, options: ElementSearchOptions = ElementSearchOptions()) -> [Element] {
        var results: [Element] = []
        searchElementsRecursively(matching: query, options: options, currentDepth: 0, results: &results)
        return results
    }

    /// Find the first element matching a query string
    /// - Parameters:
    ///   - query: The search query to match against element properties
    ///   - options: Search options to customize behavior
    /// - Returns: First matching element, or nil if none found
    @MainActor
    func findElement(matching query: String, options: ElementSearchOptions = ElementSearchOptions()) -> Element? {
        return findElementRecursively(matching: query, options: options, currentDepth: 0)
    }

    /// Search for elements by role
    /// - Parameters:
    ///   - role: The role to search for (e.g., "AXButton", "AXTextField")
    ///   - options: Search options to customize behavior
    /// - Returns: Array of elements with the specified role
    @MainActor
    func searchElements(byRole role: String, options: ElementSearchOptions = ElementSearchOptions()) -> [Element] {
        var results: [Element] = []
        searchElementsByRoleRecursively(role: role, options: options, currentDepth: 0, results: &results)
        return results
    }

    /// Check if element matches a search query
    /// - Parameters:
    ///   - query: The search query to match against
    ///   - options: Search options to customize matching
    /// - Returns: True if element matches the query
    @MainActor
    func matches(query: String, options: ElementSearchOptions = ElementSearchOptions()) -> Bool {
        // Check visibility and enabled state if required
        if options.visibleOnly && (isHidden() == true) {
            return false
        }
        if options.enabledOnly && (isEnabled() == false) {
            return false
        }

        // Check role filters
        if let role = role() {
            if !options.includeRoles.isEmpty && !options.includeRoles.contains(role) {
                return false
            }
            if options.excludeRoles.contains(role) {
                return false
            }
        }

        // Prepare query for comparison
        let searchQuery = options.caseInsensitive ? query.lowercased() : query

        // Check various text properties
        let properties = [
            title(),
            label(),
            stringValue(),
            placeholderValue(),
            descriptionText(),
            roleDescription(),
            help(),
            identifier()
        ]

        for property in properties {
            if let text = property {
                let compareText = options.caseInsensitive ? text.lowercased() : text
                if compareText.contains(searchQuery) {
                    return true
                }
            }
        }

        return false
    }

    // MARK: - Private Search Methods

    @MainActor
    private func searchElementsRecursively(
        matching query: String,
        options: ElementSearchOptions,
        currentDepth: Int,
        results: inout [Element]
    ) {
        // Check depth limit
        if options.maxDepth > 0 && currentDepth > options.maxDepth {
            return
        }

        // Check if current element matches
        if matches(query: query, options: options) {
            results.append(self)
        }

        // Search children
        if let children = children() {
            for child in children {
                child.searchElementsRecursively(
                    matching: query,
                    options: options,
                    currentDepth: currentDepth + 1,
                    results: &results
                )
            }
        }
    }

    @MainActor
    private func findElementRecursively(
        matching query: String,
        options: ElementSearchOptions,
        currentDepth: Int
    ) -> Element? {
        // Check depth limit
        if options.maxDepth > 0 && currentDepth > options.maxDepth {
            return nil
        }

        // Check if current element matches
        if matches(query: query, options: options) {
            return self
        }

        // Search children
        if let children = children() {
            for child in children {
                if let found = child.findElementRecursively(
                    matching: query,
                    options: options,
                    currentDepth: currentDepth + 1
                ) {
                    return found
                }
            }
        }

        return nil
    }

    @MainActor
    private func searchElementsByRoleRecursively(
        role: String,
        options: ElementSearchOptions,
        currentDepth: Int,
        results: inout [Element]
    ) {
        // Check depth limit
        if options.maxDepth > 0 && currentDepth > options.maxDepth {
            return
        }

        // Check visibility and enabled state if required
        if options.visibleOnly && (isHidden() == true) {
            return
        }
        if options.enabledOnly && (isEnabled() == false) {
            return
        }

        // Check if current element has the specified role
        if self.role() == role {
            results.append(self)
        }

        // Search children
        if let children = children() {
            for child in children {
                child.searchElementsByRoleRecursively(
                    role: role,
                    options: options,
                    currentDepth: currentDepth + 1,
                    results: &results
                )
            }
        }
    }
}

// MARK: - Convenience Methods

public extension Element {

    /// Find all buttons in the element hierarchy
    @MainActor
    func findAllButtons() -> [Element] {
        return searchElements(byRole: "AXButton")
    }

    /// Find all text fields in the element hierarchy
    @MainActor
    func findAllTextFields() -> [Element] {
        return searchElements(byRole: "AXTextField")
    }

    /// Find all links in the element hierarchy
    @MainActor
    func findAllLinks() -> [Element] {
        return searchElements(byRole: "AXLink")
    }

    /// Find element by identifier
    @MainActor
    func findElement(byIdentifier identifier: String) -> Element? {
        if self.identifier() == identifier {
            return self
        }

        if let children = children() {
            for child in children {
                if let found = child.findElement(byIdentifier: identifier) {
                    return found
                }
            }
        }

        return nil
    }
}
