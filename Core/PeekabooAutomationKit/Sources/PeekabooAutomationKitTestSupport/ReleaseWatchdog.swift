import Foundation
import Testing

/// Releases test-owned resources on failure without putting a delay on the success path.
public func withTestReleaseWatchdog<Result>(
    _ message: String,
    timeout: Duration = .seconds(5),
    isolation: isolated (any Actor)? = #isolation,
    sourceLocation: SourceLocation = #_sourceLocation,
    release: @escaping @Sendable () async -> Void,
    operation: () async throws -> Result) async rethrows -> Result
{
    let state = ReleaseWatchdogState()
    // Keep the test context while also running if MainActor is synchronously blocked.
    let watchdog = Task { @concurrent in
        do {
            try await Task.sleep(for: timeout)
        } catch {
            return
        }
        guard state.claimTimeout() else { return }
        Issue.record(Comment(rawValue: message), sourceLocation: sourceLocation)
        await release()
    }
    do {
        let result = try await operation()
        state.complete()
        watchdog.cancel()
        await watchdog.value
        return result
    } catch {
        state.complete()
        watchdog.cancel()
        await release()
        await watchdog.value
        throw error
    }
}

private final class ReleaseWatchdogState: @unchecked Sendable {
    private let lock = NSLock()
    private var pending = true

    func claimTimeout() -> Bool {
        self.lock.withLock {
            guard self.pending else { return false }
            self.pending = false
            return true
        }
    }

    func complete() {
        self.lock.withLock { self.pending = false }
    }
}
