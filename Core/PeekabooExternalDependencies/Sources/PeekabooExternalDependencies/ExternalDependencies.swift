//
//  ExternalDependencies.swift
//  PeekabooExternalDependencies
//

// Re-export all external dependencies for easy access
// This centralizes version management and provides a single import point

@_exported import AsyncAlgorithms
@_exported import Algorithms
@_exported import AXorcist
@_exported import Commander
@_exported import Logging
@_exported import OrderedCollections
@_exported import SystemPackage

// MARK: - Dependency Version Info

public enum DependencyInfo {
    public static let axorcistVersion = "main"
    public static let asyncAlgorithmsVersion = "1.0.4"
    public static let algorithmsVersion = "1.2.1"
    public static let commanderVersion = "local"
    public static let swiftLogVersion = "1.5.3"
    public static let swiftSystemVersion = "1.6.3"
    public static let orderedCollectionsVersion = "1.3.0"

    public static var allDependencies: [String: String] {
        [
            "AXorcist": axorcistVersion,
            "AsyncAlgorithms": asyncAlgorithmsVersion,
            "Algorithms": algorithmsVersion,
            "Commander": commanderVersion,
            "SwiftLog": swiftLogVersion,
            "SwiftSystem": swiftSystemVersion,
            "OrderedCollections": orderedCollectionsVersion,
        ]
    }
}

// MARK: - Dependency Configuration

/// Configure external dependencies if needed
public enum DependencyConfiguration {
    /// Initialize any required configurations for external dependencies
    public static func configure() {
        // Add any necessary configuration for external dependencies here
        // For example, setting up default loggers, configuring HTTP clients, etc.
    }
}
