import SwiftUI

struct OnboardingView: View {
    @Environment(PeekabooSettings.self) private var settings
    @State private var apiKey = ""
    @State private var isValidating = false
    @State private var validationError: String?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Ghost mascot
            Image("ghost.idle")
                .resizable()
                .frame(width: 80, height: 80)

            // Welcome text
            VStack(spacing: 8) {
                Text("Welcome to Peekaboo!")
                    .font(.title)
                    .fontWeight(.semibold)

                Text("Your AI-powered Mac automation assistant")
                    .foregroundColor(.secondary)
            }

            // Setup instructions
            VStack(alignment: .leading, spacing: 16) {
                Label("Get your OpenAI API key", systemImage: "key.fill")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    self.step(1, "Visit platform.openai.com")
                    self.step(2, "Sign in or create an account")
                    self.step(3, "Go to API Keys section")
                    self.step(4, "Create a new secret key")
                }

                // API key input
                VStack(alignment: .leading, spacing: 4) {
                    Text("API Key")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack {
                        SecureField("sk-...", text: self.$apiKey)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                self.validateAndSave()
                            }

                        if self.isValidating {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }

                    if let error = validationError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                // Actions
                HStack {
                    Button("Open OpenAI Platform") {
                        NSWorkspace.shared.open(URL(string: "https://platform.openai.com/api-keys")!)
                    }

                    Spacer()

                    Button("Continue") {
                        self.validateAndSave()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(self.apiKey.isEmpty || self.isValidating)
                }
            }
            .padding(20)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)

            Spacer()

            // Privacy note
            Text("Your API key is stored securely in the macOS Keychain")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number).")
                .font(.callout)
                .foregroundColor(.secondary)
                .frame(width: 20, alignment: .trailing)

            Text(text)
                .font(.callout)
        }
    }

    private func validateAndSave() {
        guard !self.apiKey.isEmpty else { return }

        Task { @MainActor in
            self.isValidating = true
            self.validationError = nil
            defer { isValidating = false }

            // Basic validation
            if !self.apiKey.hasPrefix("sk-") {
                self.validationError = "API key should start with 'sk-'"
                return
            }

            // TODO: Make a test API call to validate the key

            // Save the key
            self.settings.openAIAPIKey = self.apiKey
        }
    }
}

// MARK: - Permissions View

struct PermissionsView: View {
    @Environment(Permissions.self) private var permissions
    @State private var permissionUpdateTrigger = 0

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image("ghost.peek2")
                .resizable()
                .frame(width: 80, height: 80)

            VStack(spacing: 8) {
                Text("Permissions Required")
                    .font(.title)
                    .fontWeight(.semibold)

                Text("Peekaboo needs access to automate your Mac")
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 16) {
                PermissionRow(
                    title: "Screen Recording",
                    description: "Required to capture screenshots and see your screen",
                    status: self.permissions.screenRecordingStatus,
                    action: {
                        self.permissions.requestScreenRecording()
                    })

                PermissionRow(
                    title: "Accessibility",
                    description: "Required to control mouse and keyboard",
                    status: self.permissions.accessibilityStatus,
                    action: {
                        self.permissions.requestAccessibility()
                    })
                
                PermissionRow(
                    title: "Automation",
                    description: "Required to control applications and execute commands",
                    status: self.permissions.appleScriptStatus,
                    action: {
                        self.permissions.requestAppleScript()
                    })
            }
            .padding(20)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)

            Spacer()

            Button("Check Permissions") {
                Task {
                    await self.permissions.check()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            // Check permissions before first render
            await self.permissions.check()
            
            // Start monitoring
            self.permissions.startMonitoring()
        }
        .onDisappear {
            self.permissions.stopMonitoring()
        }
        .onReceive(NotificationCenter.default.publisher(for: .permissionsUpdated)) { _ in
            // Force UI update when permissions change
            self.permissionUpdateTrigger += 1
        }
    }
}

// MARK: - Permission Row

struct PermissionRow: View {
    let title: String
    let description: String
    let status: PermissionStatus
    let action: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Status icon
            Image(systemName: self.statusIcon)
                .font(.title2)
                .foregroundColor(self.statusColor)
                .frame(width: 30)

            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(self.title)
                    .font(.headline)

                Text(self.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Action button
            if self.status != .authorized {
                Button(self.status == .denied ? "Open Settings" : "Enable") {
                    self.action()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 8)
    }

    private var statusIcon: String {
        switch self.status {
        case .notDetermined:
            "questionmark.circle"
        case .denied:
            "xmark.circle"
        case .authorized:
            "checkmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch self.status {
        case .notDetermined:
            .secondary
        case .denied:
            .red
        case .authorized:
            .green
        }
    }
}