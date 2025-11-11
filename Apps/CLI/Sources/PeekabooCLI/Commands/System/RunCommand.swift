@preconcurrency import ArgumentParser
import Foundation
import PeekabooCore

@available(macOS 14.0, *)
struct RunCommand: OutputFormattable {
    nonisolated(unsafe) static var configuration: CommandConfiguration {
        MainActorCommandConfiguration.describe {
            CommandConfiguration(
                commandName: "run",
                abstract: "Execute a Peekaboo automation script"
            )
        }
    }

    @Argument(help: "Path to the script file (.peekaboo.json)")
    var scriptPath: String

    @Option(help: "Save results to file instead of stdout")
    var output: String?

    @Flag(help: "Continue execution even if a step fails")
    var noFailFast = false

    @OptionGroup var runtimeOptions: CommandRuntimeOptions
    @RuntimeStorage private var runtime: CommandRuntime?

    private var resolvedRuntime: CommandRuntime {
        guard let runtime else {
            preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
        }
        return runtime
    }

    private var services: PeekabooServices { self.resolvedRuntime.services }
    private var logger: Logger { self.resolvedRuntime.logger }
    var outputLogger: Logger { self.logger }
    private var configuration: CommandRuntime.Configuration { self.resolvedRuntime.configuration }
    var jsonOutput: Bool { self.configuration.jsonOutput }
    private var isVerbose: Bool { self.configuration.verbose }

    @MainActor
    mutating func run(using runtime: CommandRuntime) async throws {
        self.runtime = runtime
        let startTime = Date()

        do {
            let script = try await ProcessServiceBridge.loadScript(services: self.services, path: self.scriptPath)
            let results = try await ProcessServiceBridge.executeScript(
                services: self.services,
                script,
                failFast: !self.noFailFast,
                verbose: self.isVerbose
            )

            let output = ScriptExecutionResult(
                success: results.allSatisfy(\.success),
                scriptPath: self.scriptPath,
                description: script.description,
                totalSteps: script.steps.count,
                completedSteps: results.count { $0.success },
                failedSteps: results.count { !$0.success },
                executionTime: Date().timeIntervalSince(startTime),
                steps: results
            )

            if let outputPath = self.output {
                let data = try JSONEncoder().encode(output)
                try data.write(to: URL(fileURLWithPath: outputPath))
                if !self.jsonOutput {
                    print("✅ Script completed. Results saved to: \(outputPath)")
                }
            } else if self.jsonOutput {
                outputSuccessCodable(data: output, logger: self.outputLogger)
            } else {
                self.printSummary(output)
            }

            if !output.success {
                throw ExitCode.failure
            }
        } catch {
            if self.jsonOutput {
                outputError(message: error.localizedDescription, code: .INVALID_ARGUMENT, logger: self.outputLogger)
            } else {
                print("❌ Error: \(error.localizedDescription)")
            }
            throw ExitCode.failure
        }
    }

    @MainActor
    private func printSummary(_ result: ScriptExecutionResult) {
        if result.success {
            print("✅ Script completed successfully")
        } else {
            print("❌ Script failed")
        }
        print("   Total steps: \(result.totalSteps)")
        print("   Completed: \(result.completedSteps)")
        print("   Failed: \(result.failedSteps)")
        print("   Execution time: \(String(format: "%.2f", result.executionTime))s")

        if !result.success {
            let failedSteps = result.steps.filter { !$0.success }
            if !failedSteps.isEmpty {
                print("\nFailed steps:")
                for step in failedSteps {
                    print("   - Step \(step.stepNumber) (\(step.command)): \(step.error ?? "Unknown error")")
                }
            }
        }
    }
}

struct ScriptExecutionResult: Codable {
    let success: Bool
    let scriptPath: String
    let description: String?
    let totalSteps: Int
    let completedSteps: Int
    let failedSteps: Int
    let executionTime: TimeInterval
    let steps: [PeekabooCore.StepResult]
}

private enum ProcessServiceBridge {
    static func loadScript(services: PeekabooServices, path: String) async throws -> PeekabooScript {
        try await Task { @MainActor in
            try await services.process.loadScript(from: path)
        }.value
    }

    static func executeScript(
        services: PeekabooServices,
        _ script: PeekabooScript,
        failFast: Bool,
        verbose: Bool
    ) async throws -> [StepResult] {
        try await Task { @MainActor in
            try await services.process.executeScript(script, failFast: failFast, verbose: verbose)
        }.value
    }
}

extension RunCommand: ParsableCommand {}

extension RunCommand: AsyncRuntimeCommand {}
