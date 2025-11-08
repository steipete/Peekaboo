//
//  VisualizerEndpointStore.swift
//  PeekabooCore
//

import Foundation

public enum VisualizerEndpointStoreError: Error {
    case applicationSupportUnavailable
    case endpointNotFound
    case decodingFailed
}

public enum VisualizerEndpointStore {
    private static let directoryName = "Peekaboo/Visualizer"
    private static let fileName = "visualizer.endpoint"
    private static let knownBundleIdentifiers = ["boo.peekaboo.mac", "boo.peekaboo.mac.debug"]

    private static func primaryDirectory(createIfNeeded: Bool) throws -> URL {
        guard let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw VisualizerEndpointStoreError.applicationSupportUnavailable
        }

        let directory = root.appendingPathComponent(Self.directoryName, isDirectory: true)
        if createIfNeeded {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    private static func userApplicationSupportDirectory() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)
            .appendingPathComponent(Self.directoryName, isDirectory: true)
    }

    private static func containerDirectory(for bundleIdentifier: String) -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers/\(bundleIdentifier)/Data/Library/Application Support", isDirectory: true)
            .appendingPathComponent(Self.directoryName, isDirectory: true)
    }

    private static func uniqueDirectories(_ directories: [URL]) -> [URL] {
        var seen = Set<URL>()
        var result: [URL] = []
        for directory in directories {
            if seen.insert(directory).inserted {
                result.append(directory)
            }
        }
        return result
    }

    private static func directoriesForReading() -> [URL] {
        var candidates: [URL] = []
        if let primary = try? primaryDirectory(createIfNeeded: false) {
            candidates.append(primary)
        }
        candidates.append(contentsOf: Self.knownBundleIdentifiers.map(containerDirectory(for:)))
        candidates.append(userApplicationSupportDirectory())
        return uniqueDirectories(candidates)
    }

    private static func directoriesForWriting() -> [URL] {
        var directories: [URL] = []
        if let primary = try? primaryDirectory(createIfNeeded: true) {
            directories.append(primary)
        }

        // Best-effort mirrors so non-sandboxed clients can find the endpoint
        directories.append(contentsOf: Self.knownBundleIdentifiers.map(containerDirectory(for:)))
        directories.append(userApplicationSupportDirectory())
        return uniqueDirectories(directories)
    }

    private static func endpointURL(in directory: URL) -> URL {
        directory.appendingPathComponent(Self.fileName, isDirectory: false)
    }

    public static func write(endpoint: NSXPCListenerEndpoint) throws {
        let data = try NSKeyedArchiver.archivedData(withRootObject: endpoint, requiringSecureCoding: true)
        var writeSucceeded = false
        var lastError: (any Error)?

        for directory in directoriesForWriting() {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try data.write(to: endpointURL(in: directory), options: [.atomic])
                writeSucceeded = true
            } catch {
                lastError = error
            }
        }

        if !writeSucceeded {
            throw lastError ?? VisualizerEndpointStoreError.applicationSupportUnavailable
        }
    }

    public static func readEndpoint() throws -> NSXPCListenerEndpoint {
        for directory in directoriesForReading() {
            let url = endpointURL(in: directory)
            if FileManager.default.fileExists(atPath: url.path) {
                let data = try Data(contentsOf: url)
                guard let endpoint = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSXPCListenerEndpoint.self, from: data) else {
                    throw VisualizerEndpointStoreError.decodingFailed
                }
                return endpoint
            }
        }
        throw VisualizerEndpointStoreError.endpointNotFound
    }

    public static func removeEndpoint() {
        for directory in directoriesForReading() {
            let url = endpointURL(in: directory)
            try? FileManager.default.removeItem(at: url)
        }
    }
}
