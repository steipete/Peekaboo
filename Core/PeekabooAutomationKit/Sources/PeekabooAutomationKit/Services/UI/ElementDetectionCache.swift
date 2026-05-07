import Foundation
import PeekabooFoundation

/// Short-lived cache for immutable element detection results.
///
/// AX trees are expensive to rebuild, but UI can mutate immediately after automation actions.
/// Keep this cache intentionally small and TTL-based; interaction commands should invalidate it
/// explicitly once they start sharing observation state.
@_spi(Testing) public final class ElementDetectionCache {
    public struct Key: Hashable, Sendable {
        public let windowID: Int
        public let processID: pid_t
        public let allowWebFocus: Bool

        public init(windowID: Int, processID: pid_t, allowWebFocus: Bool) {
            self.windowID = windowID
            self.processID = processID
            self.allowWebFocus = allowWebFocus
        }
    }

    private struct Entry {
        let cachedAt: Date
        let elements: [DetectedElement]
    }

    private let ttl: TimeInterval
    private let now: () -> Date
    private var entries: [Key: Entry] = [:]

    public init(ttl: TimeInterval = 1.5, now: @escaping () -> Date = Date.init) {
        self.ttl = ttl
        self.now = now
    }

    public func key(windowID: Int?, processID: pid_t, allowWebFocus: Bool) -> Key? {
        guard let windowID else { return nil }
        return Key(windowID: windowID, processID: processID, allowWebFocus: allowWebFocus)
    }

    public func elements(for key: Key) -> [DetectedElement]? {
        guard let entry = self.entries[key] else { return nil }

        if self.now().timeIntervalSince(entry.cachedAt) <= self.ttl {
            return entry.elements
        }

        self.entries.removeValue(forKey: key)
        return nil
    }

    public func store(_ elements: [DetectedElement], for key: Key) {
        self.entries[key] = Entry(cachedAt: self.now(), elements: elements)
    }

    public func removeAll() {
        self.entries.removeAll()
    }
}
