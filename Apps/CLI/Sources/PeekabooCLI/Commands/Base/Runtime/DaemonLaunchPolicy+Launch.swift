import Darwin
import Foundation
import PeekabooBridge

extension DaemonLaunchPolicy {
    /// Retains the Foundation process until its termination source has reaped the child.
    private final nonisolated class ProcessExitObserver: @unchecked Sendable {
        private let lock = NSLock()
        private var retainedProcess: Process?
        private var didExit = false
        private var nextWaiterID = 0
        private var waiters: [Int: CheckedContinuation<Bool, Never>] = [:]

        init(process: Process) {
            self.retainedProcess = process
        }

        func processDidExit() {
            self.lock.lock()
            guard !self.didExit else {
                self.lock.unlock()
                return
            }
            self.didExit = true
            self.retainedProcess = nil
            let continuations = Array(self.waiters.values)
            self.waiters.removeAll()
            self.lock.unlock()

            for continuation in continuations {
                continuation.resume(returning: true)
            }
        }

        func wait(timeout: TimeInterval) async -> Bool {
            await withCheckedContinuation { continuation in
                self.lock.lock()
                guard !self.didExit else {
                    self.lock.unlock()
                    continuation.resume(returning: true)
                    return
                }
                self.nextWaiterID += 1
                let waiterID = self.nextWaiterID
                self.waiters[waiterID] = continuation
                self.lock.unlock()

                DispatchQueue.global(qos: .utility).asyncAfter(
                    deadline: .now() + max(0, timeout)
                ) {
                    self.timeout(waiterID: waiterID)
                }
            }
        }

        private func timeout(waiterID: Int) {
            self.lock.lock()
            let continuation = self.waiters.removeValue(forKey: waiterID)
            self.lock.unlock()
            continuation?.resume(returning: false)
        }
    }

    enum DaemonLaunchError: LocalizedError {
        case executableNotFound(argument: String?)
        case launchFailed(executableURL: URL, underlyingError: any Error)
        case exited(executableURL: URL, status: Int32, logURL: URL)
        case timedOut(timeout: TimeInterval, elapsed: TimeInterval, lastProbeError: String?, logURL: URL)

        var errorDescription: String? {
            switch self {
            case let .executableNotFound(argument):
                let executable = argument.map { "'\($0)'" } ?? "the current executable"
                return "Could not resolve \(executable) to launch the Peekaboo daemon"
            case let .launchFailed(executableURL, underlyingError):
                return "Could not launch the Peekaboo daemon at \(executableURL.path): " +
                    underlyingError.localizedDescription
            case let .exited(executableURL, status, logURL):
                return "Peekaboo daemon at \(executableURL.path) exited before becoming ready " +
                    "(status \(status)); see \(logURL.path)"
            case let .timedOut(timeout, elapsed, lastProbeError, logURL):
                let seconds = timeout.rounded() == timeout
                    ? String(Int(timeout))
                    : String(format: "%.1f", timeout)
                let probe = lastProbeError ?? "no reusable daemon responded"
                return "Peekaboo daemon did not become ready within \(seconds)s " +
                    "(elapsed \(String(format: "%.2f", elapsed))s); last probe: \(probe); see \(logURL.path)"
            }
        }
    }

    static func launchDaemon(
        socketPath: String,
        arguments: [String],
        timeout: TimeInterval = Self.defaultLaunchTimeoutSeconds,
        executableURL: URL? = nil,
        logHandle: FileHandle? = nil,
        environment: [String: String]? = nil,
        probe: @escaping @MainActor (DaemonControlClient) async throws -> PeekabooDaemonStatus? = {
            try await $0.fetchReusableDaemonStatus()
        }
    ) async throws -> LaunchResult {
        try Task.checkCancellation()
        guard let executableURL = executableURL ?? self.daemonExecutableURL() else {
            throw DaemonLaunchError.executableNotFound(argument: CommandLine.arguments.first)
        }

        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        if let environment {
            process.environment = environment
        }
        let daemonLogURL = DaemonPaths.daemonLogURL()
        let outputHandle = logHandle ?? DaemonPaths.openDaemonLogForAppend() ?? FileHandle.nullDevice
        process.standardOutput = outputHandle
        process.standardError = outputHandle
        process.standardInput = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            throw DaemonLaunchError.launchFailed(executableURL: executableURL, underlyingError: error)
        }
        let exitObserver = ProcessExitObserver(process: process)
        process.terminationHandler = { _ in
            exitObserver.processDidExit()
        }

        let clock = ContinuousClock()
        let startedAt = clock.now
        let deadline = startedAt.advanced(by: .seconds(timeout))
        var lastProbeError: (any Error)?
        while clock.now < deadline {
            let remaining = (clock.now.duration(to: deadline)).components
            let requestTimeout = Double(remaining.seconds) + Double(remaining.attoseconds) / 1e18
            guard requestTimeout > 0 else { break }
            let client = DaemonControlClient(
                socketPath: socketPath,
                requestTimeoutSec: min(PeekabooBridgeConstants.defaultRequestTimeoutSeconds, max(0, requestTimeout))
            )
            // Readiness retries observe only this owned child; a failed probe cannot authorize another launch.
            let status: PeekabooDaemonStatus?
            do {
                status = try await withMainActorCommandTimeout(
                    seconds: requestTimeout,
                    operationName: "Daemon readiness probe",
                    timeoutError: {
                        PeekabooBridgeErrorEnvelope(
                            code: .timeout,
                            message: "Daemon readiness probe exceeded the remaining startup budget"
                        )
                    },
                    operation: {
                        try await probe(client)
                    }
                )
            } catch {
                lastProbeError = error
                if !Self.isRetryableReadinessError(error) {
                    await self.terminateLaunchedProcess(process, exitObserver: exitObserver)
                    throw error
                }
                status = nil
            }
            if Task.isCancelled {
                await self.terminateLaunchedProcess(process, exitObserver: exitObserver)
                throw CancellationError()
            }
            guard clock.now < deadline else { break }
            if let status {
                let processID = process.processIdentifier
                if status.pid != processID {
                    await self.terminateLaunchedProcess(process, exitObserver: exitObserver)
                }
                let result = LaunchResult(status: status, processID: processID)
                if result.ownsObservedDaemon {
                    ManagedAutoDaemonRegistry.store(status: status, socketPath: socketPath)
                }
                return result
            }
            if !process.isRunning {
                throw DaemonLaunchError.exited(
                    executableURL: executableURL,
                    status: process.terminationStatus,
                    logURL: daemonLogURL
                )
            }
            do {
                try await Task.sleep(nanoseconds: 100_000_000)
            } catch {
                await self.terminateLaunchedProcess(process, exitObserver: exitObserver)
                throw error
            }
        }
        if !process.isRunning {
            throw DaemonLaunchError.exited(
                executableURL: executableURL,
                status: process.terminationStatus,
                logURL: daemonLogURL
            )
        }
        await self.terminateLaunchedProcess(process, exitObserver: exitObserver)
        let elapsed = startedAt.duration(to: clock.now).components
        throw DaemonLaunchError.timedOut(
            timeout: timeout,
            elapsed: Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18,
            lastProbeError: lastProbeError?.localizedDescription,
            logURL: daemonLogURL
        )
    }

    static func isRetryableReadinessError(_ error: any Error) -> Bool {
        if let error = error as? POSIXError {
            return [.ENOENT, .ECONNREFUSED, .ECONNRESET, .ETIMEDOUT, .EAGAIN, .EINTR, .EPIPE].contains(error.code)
        }
        if let error = error as? PeekabooBridgeErrorEnvelope {
            return !error.isLocalHostAuthenticationFailure && error.code == .timeout
        }
        return false
    }

    private static func terminateLaunchedProcess(
        _ process: Process,
        exitObserver: ProcessExitObserver
    ) async {
        guard process.isRunning else { return }

        process.terminate()
        let exitedAfterTermination = await exitObserver.wait(timeout: 0.5)
        guard !exitedAfterTermination else { return }
        guard process.isRunning else { return }

        _ = kill(process.processIdentifier, SIGKILL)
        // `Process.waitUntilExit()` can itself block indefinitely on a wedged Foundation
        // process source. The termination handler retains and eventually reaps the child,
        // while this caller waits for only a bounded SIGKILL grace period.
        _ = await exitObserver.wait(timeout: 1)
    }
}
