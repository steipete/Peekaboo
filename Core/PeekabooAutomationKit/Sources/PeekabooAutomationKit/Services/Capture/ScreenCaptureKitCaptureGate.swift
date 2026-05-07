import CoreGraphics
import Darwin
import Foundation
import PeekabooFoundation
@preconcurrency import ScreenCaptureKit

enum ScreenCaptureKitCaptureGate {
    /// Protects concurrent SCK calls within one process. ScreenCaptureKit can leak
    /// continuations instead of returning an error when re-entered under load.
    @MainActor private static var isCaptureActive = false

    @MainActor
    static func captureImage(
        contentFilter: SCContentFilter,
        configuration: SCStreamConfiguration) async throws -> CGImage
    {
        try await self.withExclusiveCapture {
            try await self
                .withScreenCaptureKitTimeout(seconds: 3.0, operationName: "SCScreenshotManager.captureImage") {
                    try await SCScreenshotManager.captureImage(
                        contentFilter: contentFilter,
                        configuration: configuration)
                }
        }
    }

    @MainActor
    static func currentShareableContent() async throws -> SCShareableContent {
        try await self.withExclusiveCapture {
            try await self.withScreenCaptureKitTimeout(seconds: 5.0, operationName: "SCShareableContent.current") {
                try await SCShareableContent.current
            }
        }
    }

    @MainActor
    static func shareableContent(
        excludingDesktopWindows: Bool,
        onScreenWindowsOnly: Bool) async throws -> SCShareableContent
    {
        try await self.withExclusiveCapture {
            try await self.withScreenCaptureKitTimeout(
                seconds: 5.0,
                operationName: "SCShareableContent.excludingDesktopWindows")
            {
                try await SCShareableContent.excludingDesktopWindows(
                    excludingDesktopWindows,
                    onScreenWindowsOnly: onScreenWindowsOnly)
            }
        }
    }

    @MainActor
    private static func withExclusiveCapture<T: Sendable>(
        _ operation: () async throws -> T) async throws -> T
    {
        while self.isCaptureActive {
            try Task.checkCancellation()
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        self.isCaptureActive = true
        defer { self.isCaptureActive = false }

        // Also serialize across separate `peekaboo` CLI invocations; the underlying
        // replayd/ScreenCaptureKit service is shared system-wide.
        let path = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("boo.peekaboo.sckit-capture.lock")
        let fd = open(path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard fd >= 0 else {
            return try await operation()
        }
        defer { close(fd) }

        while flock(fd, LOCK_EX | LOCK_NB) != 0 {
            guard errno == EWOULDBLOCK || errno == EAGAIN || errno == EINTR else {
                // Locking is defensive. If it fails unexpectedly, keep capture functional.
                return try await operation()
            }

            try Task.checkCancellation()
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        defer { flock(fd, LOCK_UN) }

        return try await operation()
    }

    @MainActor
    private static func withScreenCaptureKitTimeout<T: Sendable>(
        seconds: TimeInterval,
        operationName: String,
        operation: @escaping @MainActor @Sendable () async throws -> T) async throws -> T
    {
        let race = ScreenCaptureKitTimeoutRace<T>()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                race.setContinuation(continuation)

                let operationTask = Task { @MainActor in
                    do {
                        let value = try await operation()
                        race.resume(.success(value))
                    } catch {
                        race.resume(.failure(error))
                    }
                }
                let timeoutTask = Task {
                    do {
                        try await Task.sleep(nanoseconds: Self.timeoutNanoseconds(for: seconds))
                    } catch {
                        return
                    }
                    operationTask.cancel()
                    race.resume(.failure(OperationError.timeout(operation: operationName, duration: seconds)))
                }

                race.setTasks(operationTask: operationTask, timeoutTask: timeoutTask)
            }
        } onCancel: {
            race.cancel()
        }
    }

    private nonisolated static func timeoutNanoseconds(for seconds: TimeInterval) -> UInt64 {
        UInt64(max(seconds, 0) * 1_000_000_000)
    }
}

private final class ScreenCaptureKitTimeoutRace<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T, any Error>?
    private var operationTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?
    private var didFinish = false

    func setContinuation(_ continuation: CheckedContinuation<T, any Error>) {
        self.lock.withLock {
            self.continuation = continuation
        }
    }

    func setTasks(operationTask: Task<Void, Never>, timeoutTask: Task<Void, Never>) {
        var shouldCancel = false
        self.lock.withLock {
            shouldCancel = self.didFinish
            if !self.didFinish {
                self.operationTask = operationTask
                self.timeoutTask = timeoutTask
            }
        }

        if shouldCancel {
            operationTask.cancel()
            timeoutTask.cancel()
        }
    }

    func resume(_ result: Result<T, any Error>) {
        let continuation: CheckedContinuation<T, any Error>?
        let operationTask: Task<Void, Never>?
        let timeoutTask: Task<Void, Never>?

        self.lock.lock()
        guard !self.didFinish else {
            self.lock.unlock()
            return
        }

        self.didFinish = true
        continuation = self.continuation
        operationTask = self.operationTask
        timeoutTask = self.timeoutTask
        self.continuation = nil
        self.operationTask = nil
        self.timeoutTask = nil
        self.lock.unlock()

        // SCK sometimes leaks its own continuation after cancellation; this wrapper intentionally
        // returns to the caller without waiting for that child task to unwind.
        operationTask?.cancel()
        timeoutTask?.cancel()

        switch result {
        case let .success(value):
            continuation?.resume(returning: value)
        case let .failure(error):
            continuation?.resume(throwing: error)
        }
    }

    func cancel() {
        self.resume(.failure(CancellationError()))
    }
}
