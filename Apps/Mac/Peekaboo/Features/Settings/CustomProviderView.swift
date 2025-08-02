import SwiftUI
import PeekabooCore

/// Custom provider management view for adding, editing, and removing AI providers
struct CustomProviderView: View {
    @Environment(PeekabooSettings.self) private var settings
    @State private var showingAddProvider = false
    @State private var providerToEdit: IdentifiableCustomProvider?
    @State private var selectedProviderId: String?
    @State private var showingDeleteConfirmation = false
    @State private var testResults: [String: (success: Bool, message: String)] = [:]
    @State private var isTestingConnection: Set<String> = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Custom Providers")
                    .font(.headline)
                
                Spacer()
                
                Button("Add Provider") {
                    showingAddProvider = true
                }
                .buttonStyle(.borderedProminent)
            }
            
            // Provider list
            if settings.customProviders.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    
                    Text("No Custom Providers")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Add custom AI providers to connect to additional endpoints like OpenRouter, Groq, or self-hosted models.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 300)
                }
                .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(settings.customProviders.sorted(by: { $0.key < $1.key })), id: \.key) { id, provider in
                            CustomProviderRowView(
                                id: id,
                                provider: provider,
                                isSelected: settings.selectedProvider == id,
                                testResult: testResults[id],
                                isTesting: isTestingConnection.contains(id),
                                onSelect: {
                                    settings.selectedProvider = id
                                },
                                onEdit: {
                                    providerToEdit = IdentifiableCustomProvider((id, provider))
                                },
                                onDelete: {
                                    selectedProviderId = id
                                    showingDeleteConfirmation = true
                                },
                                onTest: {
                                    testConnection(for: id)
                                }
                            )
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
        .sheet(isPresented: $showingAddProvider) {
            AddCustomProviderView()
        }
        .sheet(item: $providerToEdit) { editInfo in
            EditCustomProviderView(providerId: editInfo.id, provider: editInfo.provider)
        }
        .confirmationDialog(
            "Delete Provider",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let id = selectedProviderId {
                    deleteProvider(id: id)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let id = selectedProviderId,
               let provider = settings.customProviders[id] {
                Text("Are you sure you want to delete '\(provider.name)'? This action cannot be undone.")
            }
        }
    }
    
    private func testConnection(for id: String) {
        isTestingConnection.insert(id)
        testResults[id] = nil
        
        Task {
            let (success, error) = await settings.testCustomProvider(id: id)
            await MainActor.run {
                isTestingConnection.remove(id)
                testResults[id] = (success, error ?? (success ? "Connection successful" : "Connection failed"))
            }
        }
    }
    
    private func deleteProvider(id: String) {
        do {
            try settings.removeCustomProvider(id: id)
            testResults.removeValue(forKey: id)
        } catch {
            // Show error alert
            print("Failed to delete provider: \(error)")
        }
    }
}

/// Individual custom provider row
struct CustomProviderRowView: View {
    let id: String
    let provider: Configuration.CustomProvider
    let isSelected: Bool
    let testResult: (success: Bool, message: String)?
    let isTesting: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onTest: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(provider.name)
                        .font(.headline)
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.accentColor)
                    }
                    
                    Spacer()
                    
                    // Provider type badge
                    Text(provider.type.displayName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.2))
                        .cornerRadius(4)
                }
                
                Text(provider.options.baseURL)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let description = provider.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                // Test result
                if let result = testResult {
                    HStack {
                        Image(systemName: result.success ? "checkmark.circle" : "xmark.circle")
                            .foregroundColor(result.success ? .green : .red)
                        Text(result.message)
                            .font(.caption)
                            .foregroundColor(result.success ? .green : .red)
                    }
                } else if isTesting {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.5)
                        Text("Testing connection...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            VStack(spacing: 4) {
                Button("Select") {
                    onSelect()
                }
                .buttonStyle(.bordered)
                .disabled(isSelected)
                
                HStack(spacing: 4) {
                    Button("Test") {
                        onTest()
                    }
                    .buttonStyle(.bordered)
                    .disabled(isTesting)
                    
                    Button("Edit") {
                        onEdit()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Delete") {
                        onDelete()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
}

/// Add custom provider sheet
struct AddCustomProviderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PeekabooSettings.self) private var settings
    
    @State private var providerId = ""
    @State private var name = ""
    @State private var description = ""
    @State private var type: Configuration.CustomProvider.ProviderType = .openai
    @State private var baseURL = ""
    @State private var apiKey = ""
    @State private var headers = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Basic Information") {
                    HStack {
                        Text("Provider ID")
                            .frame(width: 100, alignment: .trailing)
                        TextField("openrouter", text: $providerId)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    HStack {
                        Text("Name")
                            .frame(width: 100, alignment: .trailing)
                        TextField("OpenRouter", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    HStack {
                        Text("Description")
                            .frame(width: 100, alignment: .trailing)
                        TextField("Access to 300+ models", text: $description)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                
                Section("Configuration") {
                    HStack {
                        Text("Type")
                            .frame(width: 100, alignment: .trailing)
                        Picker("Type", selection: $type) {
                            ForEach(Configuration.CustomProvider.ProviderType.allCases, id: \.self) { providerType in
                                Text(providerType.displayName).tag(providerType)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    HStack {
                        Text("Base URL")
                            .frame(width: 100, alignment: .trailing)
                        TextField("https://openrouter.ai/api/v1", text: $baseURL)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    HStack {
                        Text("API Key")
                            .frame(width: 100, alignment: .trailing)
                        TextField("{env:OPENROUTER_API_KEY}", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    HStack {
                        Text("Headers")
                            .frame(width: 100, alignment: .trailing)
                        TextField("key:value,key:value", text: $headers)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                
                Section {
                    Text("Use environment variable references like {env:API_KEY} for secure credential management.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Add Custom Provider")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addProvider()
                    }
                    .disabled(!isValid)
                }
            }
        }
        .frame(width: 500, height: 500)
        .alert("Error", isPresented: $showingError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private var isValid: Bool {
        !providerId.isEmpty && !name.isEmpty && !baseURL.isEmpty && !apiKey.isEmpty
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

/// Edit custom provider sheet
struct EditCustomProviderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PeekabooSettings.self) private var settings
    
    let providerId: String
    @State private var name: String
    @State private var description: String
    @State private var type: Configuration.CustomProvider.ProviderType
    @State private var baseURL: String
    @State private var apiKey: String
    @State private var headers: String
    @State private var showingError = false
    @State private var errorMessage = ""
    
    init(providerId: String, provider: Configuration.CustomProvider) {
        self.providerId = providerId
        self._name = State(initialValue: provider.name)
        self._description = State(initialValue: provider.description ?? "")
        self._type = State(initialValue: provider.type)
        self._baseURL = State(initialValue: provider.options.baseURL)
        self._apiKey = State(initialValue: provider.options.apiKey)
        
        // Convert headers back to string
        let headersString = provider.options.headers?.map { "\($0.key):\($0.value)" }.joined(separator: ",") ?? ""
        self._headers = State(initialValue: headersString)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Basic Information") {
                    HStack {
                        Text("Provider ID")
                            .frame(width: 100, alignment: .trailing)
                        Text(providerId)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Name")
                            .frame(width: 100, alignment: .trailing)
                        TextField("OpenRouter", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    HStack {
                        Text("Description")
                            .frame(width: 100, alignment: .trailing)
                        TextField("Access to 300+ models", text: $description)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                
                Section("Configuration") {
                    HStack {
                        Text("Type")
                            .frame(width: 100, alignment: .trailing)
                        Picker("Type", selection: $type) {
                            ForEach(Configuration.CustomProvider.ProviderType.allCases, id: \.self) { providerType in
                                Text(providerType.displayName).tag(providerType)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    HStack {
                        Text("Base URL")
                            .frame(width: 100, alignment: .trailing)
                        TextField("https://openrouter.ai/api/v1", text: $baseURL)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    HStack {
                        Text("API Key")
                            .frame(width: 100, alignment: .trailing)
                        TextField("{env:OPENROUTER_API_KEY}", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    HStack {
                        Text("Headers")
                            .frame(width: 100, alignment: .trailing)
                        TextField("key:value,key:value", text: $headers)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Edit Custom Provider")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveProvider()
                    }
                    .disabled(!isValid)
                }
            }
        }
        .frame(width: 500, height: 500)
        .alert("Error", isPresented: $showingError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private var isValid: Bool {
        !name.isEmpty && !baseURL.isEmpty && !apiKey.isEmpty
    }
    
    private func saveProvider() {
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
            // Remove old provider and add updated one
            try settings.removeCustomProvider(id: providerId)
            try settings.addCustomProvider(provider, id: providerId)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

// Helper struct to make tuple identifiable for sheet presentation
struct IdentifiableCustomProvider: Identifiable {
    let id: String
    let provider: Configuration.CustomProvider
    
    init(_ tuple: (String, Configuration.CustomProvider)) {
        self.id = tuple.0
        self.provider = tuple.1
    }
}