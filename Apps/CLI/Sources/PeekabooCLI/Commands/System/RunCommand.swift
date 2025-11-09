@preconcurrency import ArgumentParser
import Foundation
import PeekabooCore

/// Executes a batch script of Peekaboo commands using the ProcessService.
/// Supports .peekaboo.json files with sequential command execution.
@available(macOS 14.0, *)
struct RunCommand: @MainActor MainActorAsyncParsableCommand, OutputFormattable {
    static let configuration = CommandConfiguration(
        commandName: "run",
        abstract: "Execute a Peekaboo automation script",
        discussion: """
            The 'run' command executes a batch script containing multiple
            Peekaboo commands in sequence.
            Scripts are JSON files that define a series of UI automation steps.

            EXAMPLES:
              peekaboo run login-flow.peekaboo.json
              peekaboo run test-suite.json --output results.json
              peekaboo run automation.json --no-fail-fast

            SCRIPT FORMAT:
              Scripts use the .peekaboo.json extension and contain:
              - A description of the automation
              - An array of steps with commands and parameters
              - Optional step IDs and comments

            Each step in the script corresponds to a Peekaboo command
            (see, click, type, scroll, etc.) with its parameters.
        """
    )

    @Argument(help: "Path to the script file (.peekaboo.json)")
    var scriptPath: String

    @Option(help: "Save results to file instead of stdout")
    var output: String?

    @Flag(help: "Continue execution even if a step fails")
    var noFailFast = false

    @OptionGroup var runtimeOptions: CommandRuntimeOptions

    @RuntimeStorage private var runtime: CommandRuntime?

    private var services: PeekabooServices {
        self.runtime?.services ?? PeekabooServices.shared
    }

    private var logger: Logger {
        self.runtime?.logger ?? Logger.shared
    }

    var outputLogger: Logger { self.logger }

    private var configuration: CommandRuntime.Configuration? { self.runtime?.configuration }

    var jsonOutput: Bool {
        self.configuration?.jsonOutput ?? self.runtimeOptions.jsonOutput
    }

    private var isVerbose: Bool {
        self.configuration?.verbose ?? self.runtimeOptions.verbose
    }

    mutating func run(using runtime: CommandRuntime) async throws {
        self.runtime = runtime
        let startTime = Date()

        do {
            // Load and validate script
            let script = try await self.services.process.loadScript(from: self.scriptPath)

            // Execute script
            let results = try await self.services.process.executeScript(
                script,
                failFast: !self.noFailFast,
                verbose: self.isVerbose
            )

            // Prepare output
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

            // Write output
            if let outputPath = self.output {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(output)
                try data.write(to: URL(fileURLWithPath: outputPath))

                if !self.isVerbose, !self.jsonOutput {
                    print("✅ Script completed. Results saved to: \(outputPath)")
                }
            } else if self.jsonOutput {
                outputSuccessCodable(data: output, logger: self.outputLogger)
            } else {
                // Human-readable output
                if output.success {
                    print("✅ Script completed successfully")
                    print("   Total steps: \(output.totalSteps)")
                    print("   Completed: \(output.completedSteps)")
                    print("   Failed: \(output.failedSteps)")
                    print("   Execution time: \(String(format: "%.2f", output.executionTime))s")
                } else {
                    print("❌ Script failed")
                    print("   Total steps: \(output.totalSteps)")
                    print("   Completed: \(output.completedSteps)")
                    print("   Failed: \(output.failedSteps)")
                    print("   Execution time: \(String(format: "%.2f", output.executionTime))s")

                    // Show failed steps
                    let failedSteps = output.steps.filter { !$0.success }
                    if !failedSteps.isEmpty {
                        print("\nFailed steps:")
                        for step in failedSteps {
                            print("   - Step \(step.stepNumber) (\(step.command)): \(step.error ?? "Unknown error")")
                        }
                    }
                }
            }

            // Exit with failure if any steps failed
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
}

// MARK: - Output Model

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

@MainActor
extension RunCommand: AsyncRuntimeCommand {}
