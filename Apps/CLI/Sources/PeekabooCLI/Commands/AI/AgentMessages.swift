//
//  AgentMessages.swift
//  PeekabooCLI
//

enum AgentMessages {
    enum Chat {
        static let jsonDisabled = "Interactive chat is not available while --json output is enabled."
        static let quietDisabled = "Interactive chat requires visible output. Remove --quiet to continue."
        static let dryRunDisabled = "Interactive chat cannot run in --dry-run mode."
        static let noCacheDisabled = "Interactive chat needs session caching. Remove --no-cache."
        static let typedOnly = "Interactive chat currently accepts typed input only."

        static let nonInteractiveHelp = """
        Provide a task or run with --chat in an interactive terminal to start the agent chat loop.
        """
    }

    enum Audio {
        static func processingError(_ error: any Error) -> String {
            "Audio processing failed: \(error.localizedDescription)"
        }

        static let genericProcessingError = "Audio processing failed"
    }
}
