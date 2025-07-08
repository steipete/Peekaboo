import ArgumentParser
import Foundation
import PeekabooCore

/// Executes a batch script of Peekaboo commands using the ProcessService.
/// Supports .peekaboo.json files with sequential command execution.
@available(macOS 14.0, *)
struct RunCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "run",
        abstract: "Execute a Peekaboo automation script ( - uses services)",
        discussion: """
            The 'run' command executes a batch script containing multiple
            Peekaboo commands in sequence using the new service architecture.
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
        """)

    @Argument(help: "Path to the script file (.peekaboo.json)")
    var scriptPath: String

    @Option(help: "Save results to file instead of stdout")
    var output: String?

    @Flag(help: "Continue execution even if a step fails")
    var noFailFast = false

    @Flag(help: "Show detailed step execution")
    var verbose = false

    @Flag(help: "Output in JSON format")
    var jsonOutput = false

    mutating func run() async throws {
        let startTime = Date()

        do {
            // Initialize services
            let services = try ServiceContainer.shared

            // Load and validate script
            let script = try await services.processService.loadScript(from: scriptPath)

            // Execute script
            let results = try await services.processService.executeScript(
                script,
                failFast: !self.noFailFast,
                verbose: self.verbose)

            // Prepare output
            let output = ScriptExecutionResult(
                success: results.allSatisfy(\.success),
                scriptPath: self.scriptPath,
                description: script.description,
                totalSteps: script.steps.count,
                completedSteps: results.count { $0.success },
                failedSteps: results.count { !$0.success },
                executionTime: Date().timeIntervalSince(startTime),
                steps: results)

            // Write output
            if let outputPath = self.output {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(output)
                try data.write(to: URL(fileURLWithPath: outputPath))

                if !self.verbose, !self.jsonOutput {
                    print("✅ Script completed. Results saved to: \(outputPath)")
                }
            } else if self.jsonOutput {
                outputSuccessCodable(data: output)
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
                outputError(message: error.localizedDescription, code: .INVALID_ARGUMENT)
            } else {
                print("❌ Error: \(error.localizedDescription)")
            }
            throw ExitCode.failure
        }
    }
}

// MARK: -  Output Model

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