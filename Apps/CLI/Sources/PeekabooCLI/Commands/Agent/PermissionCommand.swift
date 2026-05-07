import Commander

/// Manage and request system permissions
struct PermissionCommand: ParsableCommand {
    static let commandDescription = CommandDescription(
        commandName: "permission",
        abstract: "Manage system permissions for Peekaboo",
        discussion: """
        Request and check system permissions required by Peekaboo.

        EXAMPLES:
          # Check current permission status
          peekaboo agent permission status

          # Request screen recording permission
          peekaboo agent permission request-screen-recording

          # Request accessibility permission
          peekaboo agent permission request-accessibility

          # Request event-synthesizing permission for background hotkeys
          peekaboo agent permission request-event-synthesizing
        """,
        subcommands: [
            StatusSubcommand.self,
            RequestScreenRecordingSubcommand.self,
            RequestAccessibilitySubcommand.self,
            RequestEventSynthesizingSubcommand.self
        ],
        defaultSubcommand: StatusSubcommand.self
    )
}
