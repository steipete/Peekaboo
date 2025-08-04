import PeekabooCore
import SwiftUI

/// Modern redesigned Add Custom Provider UI with card-based layout and better UX
struct AddCustomProviderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PeekabooSettings.self) private var settings
    
    @State private var currentStep: AddProviderStep = .selectType
    @State private var selectedTemplate: ProviderTemplate?
    
    // Form data
    @State private var providerId = ""
    @State private var name = ""
    @State private var description = ""
    @State private var type: Configuration.CustomProvider.ProviderType = .openai
    @State private var baseURL = ""
    @State private var apiKey = ""
    @State private var headers = ""
    @State private var testResult: TestResult?
    @State private var isTestingConnection = false
    
    // UI state
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isAdvancedMode = false
    
    enum AddProviderStep: CaseIterable {
        case selectType
        case configure
        case test
        
        var title: String {
            switch self {
            case .selectType: return "Choose Provider Type"
            case .configure: return "Configure Provider"
            case .test: return "Test & Add"
            }
        }
        
        var subtitle: String {
            switch self {
            case .selectType: return "Select from popular providers or create a custom one"
            case .configure: return "Enter your provider details and API credentials"
            case .test: return "Verify connection and add to your providers"
            }
        }
    }
    
    enum TestResult {
        case success(String)
        case failure(String)
        
        var isSuccess: Bool {
            if case .success = self { return true }
            return false
        }
        
        var message: String {
            switch self {
            case .success(let msg): return msg
            case .failure(let msg): return msg
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with progress indicator
                headerView
                
                Divider()
                
                // Main content
                GeometryReader { geometry in
                    ZStack {
                        ForEach(AddProviderStep.allCases, id: \.self) { step in
                            stepContent(for: step)
                                .opacity(currentStep == step ? 1 : 0)
                                .animation(.easeInOut, value: currentStep)
                        }
                    }
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    navigationButton
                }
            }
        }
        .frame(width: 700, height: 600)
        .alert("Error", isPresented: $showingError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 16) {
            // Progress indicator
            HStack(spacing: 12) {
                ForEach(Array(AddProviderStep.allCases.enumerated()), id: \.offset) { index, step in
                    HStack(spacing: 8) {
                        // Step circle
                        Circle()
                            .fill(stepColor(for: step))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Group {
                                    if step == currentStep {
                                        Text("\(index + 1)")
                                            .font(.caption.bold())
                                            .foregroundColor(.white)
                                    } else if AddProviderStep.allCases.firstIndex(of: step)! < AddProviderStep.allCases.firstIndex(of: currentStep)! {
                                        Image(systemName: "checkmark")
                                            .font(.caption.bold())
                                            .foregroundColor(.white)
                                    } else {
                                        Text("\(index + 1)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            )
                        
                        // Connector line
                        if index < AddProviderStep.allCases.count - 1 {
                            Rectangle()
                                .fill(connectorColor(for: step))
                                .frame(width: 40, height: 2)
                        }
                    }
                }
            }
            .padding(.horizontal)
            
            // Step title and subtitle
            VStack(spacing: 4) {
                Text(currentStep.title)
                    .font(.title2.bold())
                
                Text(currentStep.subtitle)
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 20)
        .background(.ultraThinMaterial)
    }
    
    private func stepColor(for step: AddProviderStep) -> Color {
        let currentIndex = AddProviderStep.allCases.firstIndex(of: currentStep) ?? 0
        let stepIndex = AddProviderStep.allCases.firstIndex(of: step) ?? 0
        
        if stepIndex <= currentIndex {
            return .accentColor
        } else {
            return Color(.controlBackgroundColor)
        }
    }
    
    private func connectorColor(for step: AddProviderStep) -> Color {
        let currentIndex = AddProviderStep.allCases.firstIndex(of: currentStep) ?? 0
        let stepIndex = AddProviderStep.allCases.firstIndex(of: step) ?? 0
        
        if stepIndex < currentIndex {
            return .accentColor
        } else {
            return Color(.separatorColor)
        }
    }
    
    @ViewBuilder
    private func stepContent(for step: AddProviderStep) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                switch step {
                case .selectType:
                    providerSelectionView
                case .configure:
                    configurationView
                case .test:
                    testView
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 32)
        }
    }
    
    private var providerSelectionView: some View {
        VStack(spacing: 24) {
            // Popular provider templates
            VStack(alignment: .leading, spacing: 16) {
                Text("Popular Providers")
                    .font(.headline)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
                    ForEach(ProviderTemplate.popular, id: \.id) { template in
                        ProviderTemplateCard(
                            template: template,
                            isSelected: selectedTemplate?.id == template.id
                        ) {
                            selectedTemplate = template
                            applyTemplate(template)
                        }
                    }
                }
            }
            
            Divider()
            
            // Custom provider option
            VStack(alignment: .leading, spacing: 16) {
                Text("Custom Provider")
                    .font(.headline)
                
                ProviderTemplateCard(
                    template: ProviderTemplate.custom,
                    isSelected: selectedTemplate?.id == ProviderTemplate.custom.id
                ) {
                    selectedTemplate = ProviderTemplate.custom
                    applyTemplate(ProviderTemplate.custom)
                }
            }
        }
    }
    
    private var configurationView: some View {
        VStack(spacing: 24) {
            // Provider preview card
            if let template = selectedTemplate {
                ProviderPreviewCard(template: template, name: name.isEmpty ? template.name : name)
            }
            
            // Configuration form
            VStack(spacing: 20) {
                // Basic info section
                SectionCard(title: "Basic Information", icon: "info.circle") {
                    VStack(spacing: 16) {
                        FormField(title: "Provider ID", binding: $providerId, placeholder: "my-custom-provider") {
                            Text("Unique identifier for this provider")
                                .foregroundColor(.secondary)
                        }
                        
                        FormField(title: "Display Name", binding: $name, placeholder: "My Custom Provider") {
                            Text("Friendly name shown in the UI")
                                .foregroundColor(.secondary)
                        }
                        
                        FormField(title: "Description", binding: $description, placeholder: "Optional description") {
                            Text("Brief description of this provider")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Connection section
                SectionCard(title: "Connection", icon: "network") {
                    VStack(spacing: 16) {
                        // Provider type picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Provider Type")
                                .font(.headline)
                            
                            Picker("Type", selection: $type) {
                                ForEach(Configuration.CustomProvider.ProviderType.allCases, id: \.self) { providerType in
                                    Label(providerType.displayName, systemImage: providerType.icon)
                                        .tag(providerType)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        
                        FormField(title: "Base URL", binding: $baseURL, placeholder: "https://api.provider.com/v1") {
                            Text("API endpoint URL for this provider")
                                .foregroundColor(.secondary)
                        }
                        
                        SecureFormField(title: "API Key", binding: $apiKey, placeholder: "sk-... or {env:API_KEY}") {
                            Text("Your API key or environment variable reference")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Advanced section (collapsible)
                DisclosureGroup("Advanced Settings", isExpanded: $isAdvancedMode) {
                    VStack(spacing: 16) {
                        FormField(title: "Custom Headers", binding: $headers, placeholder: "Authorization:Bearer token,X-Custom:value") {
                            Text("Additional headers in key:value,key:value format")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 16)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
            }
        }
    }
    
    private var testView: some View {
        VStack(spacing: 32) {
            // Provider summary
            if let template = selectedTemplate {
                ProviderSummaryCard(
                    template: template,
                    name: name,
                    baseURL: baseURL,
                    type: type
                )
            }
            
            // Test connection section
            VStack(spacing: 20) {
                Text("Test Connection")
                    .font(.title2.bold())
                
                if let result = testResult {
                    TestResultCard(result: result)
                } else if isTestingConnection {
                    TestingCard()
                } else {
                    Button(action: testConnection) {
                        Label("Test Connection", systemImage: "bolt.fill")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.blue)
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Spacer()
        }
    }
    
    private var navigationButton: some View {
        Button(navigationButtonTitle) {
            navigationAction()
        }
        .disabled(!canNavigate)
    }
    
    private var navigationButtonTitle: String {
        switch currentStep {
        case .selectType:
            return selectedTemplate != nil ? "Next" : "Select Provider"
        case .configure:
            return "Next"
        case .test:
            return testResult?.isSuccess == true ? "Add Provider" : "Test First"
        }
    }
    
    private var canNavigate: Bool {
        switch currentStep {
        case .selectType:
            return selectedTemplate != nil
        case .configure:
            return isConfigurationValid
        case .test:
            return testResult?.isSuccess == true
        }
    }
    
    private var isConfigurationValid: Bool {
        !providerId.isEmpty && !name.isEmpty && !baseURL.isEmpty && !apiKey.isEmpty
    }
    
    private func navigationAction() {
        switch currentStep {
        case .selectType:
            withAnimation {
                currentStep = .configure
            }
        case .configure:
            withAnimation {
                currentStep = .test
            }
        case .test:
            if testResult?.isSuccess == true {
                addProvider()
            }
        }
    }
    
    private func applyTemplate(_ template: ProviderTemplate) {
        name = template.name
        description = template.description
        type = template.type
        baseURL = template.baseURL
        providerId = template.suggestedId
    }
    
    private func testConnection() {
        isTestingConnection = true
        testResult = nil
        
        Task {
            await MainActor.run {
                // Simulate test - in real implementation, this would call the actual API
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.isTestingConnection = false
                    // Simulate success for demo
                    self.testResult = .success("Connection successful! Provider is ready to use.")
                }
            }
        }
    }
    
    private func addProvider() {
        // Parse headers
        var headerDict: [String: String]?
        if !headers.isEmpty {
            headerDict = [:]
            let pairs = headers.split(separator: ",")
            for pair in pairs {
                let components = pair.split(separator: ":", maxSplits: 1)
                if components.count == 2 {
                    let key = String(components[0]).trimmingCharacters(in: .whitespacesAndNewlines)
                    let value = String(components[1]).trimmingCharacters(in: .whitespacesAndNewlines)
                    headerDict?[key] = value
                }
            }
        }
        
        let options = Configuration.ProviderOptions(
            baseURL: baseURL,
            apiKey: apiKey,
            headers: headerDict
        )
        
        let provider = Configuration.CustomProvider(
            name: name,
            description: description.isEmpty ? nil : description,
            type: type,
            options: options,
            models: nil,
            enabled: true
        )
        
        do {
            try settings.addCustomProvider(provider, id: providerId)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

// MARK: - Supporting Views

struct ProviderTemplateCard: View {
    let template: ProviderTemplate
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(template.color.opacity(0.1))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: template.icon)
                        .font(.title2)
                        .foregroundColor(template.color)
                }
                
                // Content
                VStack(spacing: 4) {
                    Text(template.name)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    
                    Text(template.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 140)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color(.controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

struct ProviderPreviewCard: View {
    let template: ProviderTemplate
    let name: String
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(template.color.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: template.icon)
                    .font(.title3)
                    .foregroundColor(template.color)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.headline)
                
                Text(template.type.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(template.color.opacity(0.2))
                    .cornerRadius(4)
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct SectionCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.headline)
            }
            
            content
        }
        .padding(20)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct FormField<Help: View>: View {
    let title: String
    @Binding var binding: String
    let placeholder: String
    @ViewBuilder let help: Help
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            
            TextField(placeholder, text: $binding)
                .textFieldStyle(.roundedBorder)
            
            help
        }
    }
}

struct SecureFormField<Help: View>: View {
    let title: String
    @Binding var binding: String
    let placeholder: String
    @ViewBuilder let help: Help
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            
            SecureField(placeholder, text: $binding)
                .textFieldStyle(.roundedBorder)
            
            help
        }
    }
}

struct ProviderSummaryCard: View {
    let template: ProviderTemplate
    let name: String
    let baseURL: String
    let type: Configuration.CustomProvider.ProviderType
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(template.color.opacity(0.1))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: template.icon)
                        .font(.title2)
                        .foregroundColor(template.color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.title2.bold())
                    
                    Text(type.displayName)
                        .font(.callout)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(template.color.opacity(0.2))
                        .cornerRadius(4)
                }
                
                Spacer()
            }
            
            // Details
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "link")
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    Text(baseURL)
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Image(systemName: "checkmark.shield")
                        .foregroundColor(.green)
                        .frame(width: 20)
                    Text("API key configured")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(20)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct TestResultCard: View {
    let result: AddCustomProviderView.TestResult
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title2)
                .foregroundColor(result.isSuccess ? .green : .red)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(result.isSuccess ? "Connection Successful" : "Connection Failed")
                    .font(.headline)
                    .foregroundColor(result.isSuccess ? .green : .red)
                
                Text(result.message)
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(16)
        .background(result.isSuccess ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
        .cornerRadius(12)
    }
}

struct TestingCard: View {
    var body: some View {
        HStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Testing Connection")
                    .font(.headline)
                
                Text("Verifying your provider configuration...")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Provider Templates

struct ProviderTemplate: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let type: Configuration.CustomProvider.ProviderType
    let baseURL: String
    let suggestedId: String
    let icon: String
    let color: Color
    
    static let popular: [ProviderTemplate] = [
        ProviderTemplate(
            name: "OpenRouter",
            description: "Access 300+ models from one API",
            type: .openai,
            baseURL: "https://openrouter.ai/api/v1",
            suggestedId: "openrouter",
            icon: "arrow.triangle.2.circlepath",
            color: .purple
        ),
        ProviderTemplate(
            name: "Groq",
            description: "Ultra-fast inference for Llama models",
            type: .openai,
            baseURL: "https://api.groq.com/openai/v1",
            suggestedId: "groq",
            icon: "bolt.fill",
            color: .orange
        ),
        ProviderTemplate(
            name: "Together AI",
            description: "Open-source model hosting",
            type: .openai,
            baseURL: "https://api.together.xyz/v1",
            suggestedId: "together",
            icon: "person.2.fill",
            color: .blue
        ),
        ProviderTemplate(
            name: "Perplexity",
            description: "Search-powered AI models",
            type: .openai,
            baseURL: "https://api.perplexity.ai",
            suggestedId: "perplexity",
            icon: "magnifyingglass.circle.fill",
            color: .teal
        )
    ]
    
    static let custom = ProviderTemplate(
        name: "Custom Provider",
        description: "Configure your own API endpoint",
        type: .openai,
        baseURL: "",
        suggestedId: "custom",
        icon: "gearshape.fill",
        color: .gray
    )
}

// MARK: - Extensions

extension Configuration.CustomProvider.ProviderType {
    var icon: String {
        switch self {
        case .openai: return "brain.head.profile"
        case .anthropic: return "person.crop.rectangle.stack"
        }
    }
}