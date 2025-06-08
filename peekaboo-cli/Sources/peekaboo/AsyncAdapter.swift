import Foundation
import ArgumentParser

// MARK: - Adapter for AsyncParsableCommand to ParsableCommand bridge

protocol AsyncRunnable {
    func runAsync() async throws
}

extension PeekabooCommand {
    func run() throws {
        let box = ErrorBox()
        let sem = DispatchSemaphore(value: 0)
        Task {
            defer { sem.signal() }
            do {
                try await (self as AsyncRunnable).runAsync()
            } catch {
                box.error = error
            }
        }
        sem.wait()
        if let error = box.error {
            throw error
        }
    }
}

extension ImageCommand {
    func run() throws {
        let box = ErrorBox()
        let sem = DispatchSemaphore(value: 0)
        Task {
            defer { sem.signal() }
            do {
                try await (self as AsyncRunnable).runAsync()
            } catch {
                box.error = error
            }
        }
        sem.wait()
        if let error = box.error {
            throw error
        }
    }
}

extension ListCommand {
    func run() throws {
        let box = ErrorBox()
        let sem = DispatchSemaphore(value: 0)
        Task {
            defer { sem.signal() }
            do {
                try await (self as AsyncRunnable).runAsync()
            } catch {
                box.error = error
            }
        }
        sem.wait()
        if let error = box.error {
            throw error
        }
    }
}

extension AppsSubcommand {
    func run() throws {
        let box = ErrorBox()
        let sem = DispatchSemaphore(value: 0)
        Task {
            defer { sem.signal() }
            do {
                try await (self as AsyncRunnable).runAsync()
            } catch {
                box.error = error
            }
        }
        sem.wait()
        if let error = box.error {
            throw error
        }
    }
}

extension WindowsSubcommand {
    func run() throws {
        let box = ErrorBox()
        let sem = DispatchSemaphore(value: 0)
        Task {
            defer { sem.signal() }
            do {
                try await (self as AsyncRunnable).runAsync()
            } catch {
                box.error = error
            }
        }
        sem.wait()
        if let error = box.error {
            throw error
        }
    }
}

extension ServerStatusSubcommand {
    func run() throws {
        let box = ErrorBox()
        let sem = DispatchSemaphore(value: 0)
        Task {
            defer { sem.signal() }
            do {
                try await (self as AsyncRunnable).runAsync()
            } catch {
                box.error = error
            }
        }
        sem.wait()
        if let error = box.error {
            throw error
        }
    }
}

private final class ErrorBox: @unchecked Sendable {
    private var _error: Error? = nil
    private let lock = NSLock()
    
    var error: Error? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _error
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _error = newValue
        }
    }
}