import PeekabooCore
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
            GhostImageView(state: .idle, size: CGSize(width: 80, height: 80))

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

            // Make a test API call to validate the key
            Task {
                do {
                    // Test the API key with a simple models list request
                    let config = URLSessionConfiguration.default
                    config.httpAdditionalHeaders = ["Authorization": "Bearer \(self.apiKey)"]
                    let session = URLSession(configuration: config)

                    let url = URL(string: "https://api.openai.com/v1/models")!
                    let (_, response) = try await session.data(from: url)

                    if let httpResponse = response as? HTTPURLResponse {
                        if httpResponse.statusCode == 401 {
                            await MainActor.run {
                                self.validationError = "Invalid API key"
                            }
                            return
                        } else if httpResponse.statusCode != 200 {
                            await MainActor.run {
                                self.validationError = "Failed to validate API key"
                            }
                            return
                        }
                    }

                    // Save the key if validation succeeded
                    await MainActor.run {
                        self.settings.openAIAPIKey = self.apiKey
                    }
                } catch {
                    await MainActor.run {
                        self.validationError = "Network error: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
}

// MARK: - Permissions View

struct PermissionsView: View {
    @Environment(Permissions.self) private var permissions

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            GhostImageView(state: .peek2, size: CGSize(width: 80, height: 80))

            VStack(spacing: 8) {
                Text("Permissions")
                    .font(.title)
                    .fontWeight(.semibold)

                Text("Grant Screen Recording + Accessibility. Automation is optional for some workflows.")
                    .foregroundColor(.secondary)
            }

            PermissionChecklistView(showOptional: true)
                .padding(20)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)

            Spacer()

            VStack(spacing: 10) {
                Button("Check Permissions") {
                    Task {
                        await self.permissions.refresh()
                    }
                }
                .buttonStyle(.borderedProminent)

                HStack(spacing: 12) {
                    Button("Show onboarding") {
                        PermissionsOnboardingController.shared.show(permissions: self.permissions)
                    }
                    .buttonStyle(.bordered)

                    Button("Open Settings → Permissions") {
                        SettingsOpener.openSettings(tab: .permissions)
                    }
                    .buttonStyle(.bordered)
                }
            }
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
    }
}
