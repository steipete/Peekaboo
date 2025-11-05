//
//  ExternalDependencies.swift
//  PeekabooExternalDependencies
//

// Re-export all external dependencies for easy access
// This centralizes version management and provides a single import point

@_exported import ArgumentParser
@_exported import AsyncAlgorithms
@_exported import AXorcist
@_exported import Logging
@_exported import SystemPackage

// MARK: - Dependency Version Info

public enum DependencyInfo {
    public static let axorcistVersion = "main"
    public static let asyncAlgorithmsVersion = "1.0.0"
    public static let argumentParserVersion = "1.3.0"
    public static let swiftLogVersion = "1.5.3"
    public static let swiftSystemVersion = "1.3.0"

    public static var allDependencies: [String: String] {
        [
            "AXorcist": axorcistVersion,
            "AsyncAlgorithms": asyncAlgorithmsVersion,
            "ArgumentParser": argumentParserVersion,
            "SwiftLog": swiftLogVersion,
            "SwiftSystem": swiftSystemVersion,
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
