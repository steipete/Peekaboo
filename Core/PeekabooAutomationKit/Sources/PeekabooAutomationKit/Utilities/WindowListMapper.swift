import AppKit
import CoreGraphics
import Foundation
import ScreenCaptureKit

public struct CGWindowDescriptor: Sendable, Equatable {
    public let windowID: CGWindowID
    public let ownerPID: pid_t
    public let title: String?

    public init(windowID: CGWindowID, ownerPID: pid_t, title: String?) {
        self.windowID = windowID
        self.ownerPID = ownerPID
        self.title = title
    }
}

public struct SCWindowDescriptor: Sendable, Equatable {
    public let windowID: CGWindowID
    public let ownerPID: pid_t?
    public let title: String?

    public init(windowID: CGWindowID, ownerPID: pid_t?, title: String?) {
        self.windowID = windowID
        self.ownerPID = ownerPID
        self.title = title
    }
}

public struct WindowListSnapshot: Sendable, Equatable {
    public let cgWindows: [CGWindowDescriptor]
    public let scWindows: [SCWindowDescriptor]

    public init(cgWindows: [CGWindowDescriptor], scWindows: [SCWindowDescriptor]) {
        self.cgWindows = cgWindows
        self.scWindows = scWindows
    }
}

@MainActor
public final class WindowListMapper {
    public static let shared = WindowListMapper()

    private struct CacheEntry<T> {
        let value: T
        let timestamp: Date
    }

    private let cacheTTL: TimeInterval
    private var cachedCGWindows: CacheEntry<[CGWindowDescriptor]>?
    private var cachedSCWindows: CacheEntry<[SCWindowDescriptor]>?

    public init(cacheTTL: TimeInterval = 1.5) {
        self.cacheTTL = cacheTTL
    }

    public func snapshot(forceRefresh: Bool = false) async throws -> WindowListSnapshot {
        let cgWindows = self.cgWindows(forceRefresh: forceRefresh)
        let scWindows = try await self.scWindows(forceRefresh: forceRefresh)
        return WindowListSnapshot(cgWindows: cgWindows, scWindows: scWindows)
    }

    public func cgWindows(forceRefresh: Bool = false) -> [CGWindowDescriptor] {
        if !forceRefresh, let cached = self.cachedCGWindows, self.isFresh(cached.timestamp) {
            return cached.value
        }

        let windowList = CGWindowListCopyWindowInfo(
            [.optionAll, .excludeDesktopElements],
            kCGNullWindowID) as? [[String: Any]] ?? []

        let descriptors = windowList.compactMap(Self.cgDescriptor(from:))
        self.cachedCGWindows = CacheEntry(value: descriptors, timestamp: Date())
        return descriptors
    }

    public func scWindows(forceRefresh: Bool = false) async throws -> [SCWindowDescriptor] {
        if !forceRefresh, let cached = self.cachedSCWindows, self.isFresh(cached.timestamp) {
            return cached.value
        }

        let content = try await withTimeout(seconds: 5.0) {
            try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        }
        let descriptors = content.windows.map {
            SCWindowDescriptor(
                windowID: $0.windowID,
                ownerPID: $0.owningApplication?.processID,
                title: $0.title)
        }

        self.cachedSCWindows = CacheEntry(value: descriptors, timestamp: Date())
        return descriptors
    }

    public static func scWindows(
        for ownerPID: pid_t,
        in scWindows: [SCWindowDescriptor]) -> [SCWindowDescriptor]
    {
        scWindows.filter { $0.ownerPID == ownerPID }
    }

    public static func scWindowIndex(
        for windowID: CGWindowID,
        in scWindows: [SCWindowDescriptor]) -> Int?
    {
        scWindows.firstIndex(where: { $0.windowID == windowID })
    }

    public static func scWindowIndex(
        for titleFragment: String,
        in scWindows: [SCWindowDescriptor]) -> Int?
    {
        let normalized = titleFragment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        return scWindows.firstIndex(where: { window in
            (window.title ?? "").localizedCaseInsensitiveContains(normalized)
        })
    }

    public static func cgWindowID(
        for ownerPID: pid_t,
        titleFragment: String,
        in cgWindows: [CGWindowDescriptor]) -> CGWindowID?
    {
        let normalized = titleFragment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }

        return cgWindows.first(where: { window in
            window.ownerPID == ownerPID &&
                (window.title ?? "").localizedCaseInsensitiveContains(normalized)
        })?.windowID
    }

    public static func scWindowIndex(
        for ownerPID: pid_t,
        titleFragment: String,
        in snapshot: WindowListSnapshot) -> Int?
    {
        guard let windowID = self.cgWindowID(
            for: ownerPID,
            titleFragment: titleFragment,
            in: snapshot.cgWindows)
        else {
            return nil
        }

        let appWindows = self.scWindows(for: ownerPID, in: snapshot.scWindows)
        return self.scWindowIndex(for: windowID, in: appWindows)
    }

    public static func axWindowIndex(
        for windowID: CGWindowID,
        in windows: [ServiceWindowInfo]) -> Int?
    {
        windows.firstIndex(where: { $0.windowID == Int(windowID) })
    }

    private func isFresh(_ timestamp: Date) -> Bool {
        Date().timeIntervalSince(timestamp) < self.cacheTTL
    }

    private static func cgDescriptor(from info: [String: Any]) -> CGWindowDescriptor? {
        guard let windowID = info[kCGWindowNumber as String] as? CGWindowID,
              let ownerPID = ownerPID(from: info)
        else {
            return nil
        }

        return CGWindowDescriptor(
            windowID: windowID,
            ownerPID: ownerPID,
            title: info[kCGWindowName as String] as? String)
    }

    private static func ownerPID(from info: [String: Any]) -> pid_t? {
        if let number = info[kCGWindowOwnerPID as String] as? NSNumber {
            return pid_t(number.intValue)
        }
        if let intValue = info[kCGWindowOwnerPID as String] as? Int {
            return pid_t(intValue)
        }
        if let pidValue = info[kCGWindowOwnerPID as String] as? pid_t {
            return pidValue
        }
        return nil
    }
}
