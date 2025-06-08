import Foundation

extension Task where Success == Void, Failure == Never {
    /// Runs an async operation synchronously by blocking the current thread.
    /// This is a safer alternative to using DispatchSemaphore with Swift concurrency.
    static func runBlocking<T>(operation: @escaping () async throws -> T) throws -> T {
        var result: Result<T, Error>?
        let condition = NSCondition()
        
        Task {
            do {
                let value = try await operation()
                condition.lock()
                result = .success(value)
                condition.signal()
                condition.unlock()
            } catch {
                condition.lock()
                result = .failure(error)
                condition.signal()
                condition.unlock()
            }
        }
        
        condition.lock()
        while result == nil {
            condition.wait()
        }
        condition.unlock()
        
        return try result!.get()
    }
}