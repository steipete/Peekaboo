import Foundation
import PeekabooFoundation

@_spi(Testing) public enum ElementDetectionTimeoutRunner {
    public static func run<T: Sendable>(
        seconds: TimeInterval,
        operation: @escaping @MainActor @Sendable () async throws -> T) async throws -> T
    {
        guard seconds.isFinite, seconds > 0 else {
            throw CaptureError.detectionTimedOut(seconds)
        }

        let state = ElementDetectionTimeoutState<T>()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                state.install(continuation)

                let workTask = Task { @MainActor in
                    do {
                        let value = try await operation()
                        state.resume(with: .success(value))
                    } catch {
                        state.resume(with: .failure(error))
                    }
                }

                let timeoutTask = Task {
                    do {
                        try await Task.sleep(nanoseconds: self.nanoseconds(for: seconds))
                        workTask.cancel()
                        state.resume(with: .failure(CaptureError.detectionTimedOut(seconds)))
                    } catch {
                        // Cancellation means work finished or the parent task was cancelled.
                    }
                }

                state.setTasks(work: workTask, timeout: timeoutTask)
            }
        } onCancel: {
            state.resume(with: .failure(CancellationError()))
        }
    }

    private static func nanoseconds(for seconds: TimeInterval) -> UInt64 {
        UInt64(min(seconds, TimeInterval(UInt64.max) / 1_000_000_000) * 1_000_000_000)
    }
}

private final class ElementDetectionTimeoutState<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T, any Error>?
    private var workTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?
    private var finished = false

    func install(_ continuation: CheckedContinuation<T, any Error>) {
        self.lock.lock()
        let shouldResumeCancellation = self.finished
        if !shouldResumeCancellation {
            self.continuation = continuation
        }
        self.lock.unlock()

        if shouldResumeCancellation {
            continuation.resume(throwing: CancellationError())
        }
    }

    func setTasks(work: Task<Void, Never>, timeout: Task<Void, Never>) {
        self.lock.lock()
        defer { self.lock.unlock() }

        if self.finished {
            work.cancel()
            timeout.cancel()
        } else {
            self.workTask = work
            self.timeoutTask = timeout
        }
    }

    func resume(with result: Result<T, any Error>) {
        let continuation: CheckedContinuation<T, any Error>?
        let workTask: Task<Void, Never>?
        let timeoutTask: Task<Void, Never>?

        self.lock.lock()
        if self.finished {
            self.lock.unlock()
            return
        }
        self.finished = true
        continuation = self.continuation
        workTask = self.workTask
        timeoutTask = self.timeoutTask
        self.continuation = nil
        self.workTask = nil
        self.timeoutTask = nil
        self.lock.unlock()

        workTask?.cancel()
        timeoutTask?.cancel()
        continuation?.resume(with: result)
    }
}
