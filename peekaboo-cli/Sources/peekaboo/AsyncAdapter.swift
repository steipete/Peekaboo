import Foundation
import ArgumentParser

// MARK: - Adapter for AsyncParsableCommand to ParsableCommand bridge

protocol AsyncRunnable {
    func runAsync() async throws
}

// Thread-safe result container
private final class ResultBox<T>: @unchecked Sendable {
    private var _result: Result<T, Error>?
    private let lock = NSLock()
    
    var result: Result<T, Error>? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _result
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _result = newValue
        }
    }
}

// Helper to run async code synchronously
private func runAsyncBlocking<T: Sendable>(_ asyncWork: @escaping @Sendable () async throws -> T) throws -> T {
    let resultBox = ResultBox<T>()
    let semaphore = DispatchSemaphore(value: 0)
    
    Task.detached {
        do {
            let value = try await asyncWork()
            resultBox.result = .success(value)
        } catch {
            resultBox.result = .failure(error)
        }
        semaphore.signal()
    }
    
    semaphore.wait()
    
    switch resultBox.result {
    case .success(let value):
        return value
    case .failure(let error):
        throw error
    case .none:
        fatalError("Async operation did not complete")
    }
}

extension PeekabooCommand {
    func run() throws {
        try runAsyncBlocking {
            try await (self as AsyncRunnable).runAsync()
            return ()
        }
    }
}

extension ImageCommand {
    func run() throws {
        try runAsyncBlocking {
            try await (self as AsyncRunnable).runAsync()
            return ()
        }
    }
}

extension ListCommand {
    func run() throws {
        try runAsyncBlocking {
            try await (self as AsyncRunnable).runAsync()
            return ()
        }
    }
}

extension AppsSubcommand {
    func run() throws {
        try runAsyncBlocking {
            try await (self as AsyncRunnable).runAsync()
            return ()
        }
    }
}

extension WindowsSubcommand {
    func run() throws {
        try runAsyncBlocking {
            try await (self as AsyncRunnable).runAsync()
            return ()
        }
    }
}

extension ServerStatusSubcommand {
    func run() throws {
        try runAsyncBlocking {
            try await (self as AsyncRunnable).runAsync()
            return ()
        }
    }
}