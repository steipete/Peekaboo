//
//  APIKeyField.swift
//  Peekaboo
//

import SwiftUI

/// Provider information for API key fields
struct ProviderInfo {
    let name: String
    let displayName: String
    let environmentVariable: String
    let requiresAPIKey: Bool
    
    static let openai = ProviderInfo(
        name: "openai",
        displayName: "OpenAI", 
        environmentVariable: "OPENAI_API_KEY",
        requiresAPIKey: true
    )
    
    static let anthropic = ProviderInfo(
        name: "anthropic",
        displayName: "Anthropic",
        environmentVariable: "ANTHROPIC_API_KEY", 
        requiresAPIKey: true
    )
    
    static let ollama = ProviderInfo(
        name: "ollama",
        displayName: "Ollama",
        environmentVariable: "OLLAMA_API_KEY",
        requiresAPIKey: false
    )
}

/// Reusable API key field that shows environment variable status and allows override
struct APIKeyField: View {
    let provider: ProviderInfo
    @Binding var apiKey: String
    @State private var hasEnvironmentKey: Bool = false
    @State private var showEnvironmentStatus: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(provider.displayName) API Key")
                    .font(.headline)
                
                if hasEnvironmentKey {
                    Label("Found in environment", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            
            if hasEnvironmentKey && apiKey.isEmpty {
                // Show environment variable status when no override is set
                HStack {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(.green)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Using key from \(provider.environmentVariable)")
                            .font(.callout)
                            .foregroundColor(.secondary)
                        
                        Text("Leave empty to continue using environment variable")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .opacity(0.7)
                    }
                    
                    Spacer()
                    
                    Button("Override") {
                        // Focus on the text field by setting a placeholder
                        showEnvironmentStatus = true
                    }
                    .buttonStyle(.link)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
                
                if showEnvironmentStatus {
                    SecureField("Enter API key to override environment variable", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                }
            } else {
                // Normal text field for manual API key entry
                SecureField(environmentPlaceholder, text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                
                if hasEnvironmentKey && !apiKey.isEmpty {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        
                        Text("Overriding environment variable \(provider.environmentVariable)")
                            .font(.caption)
                            .foregroundColor(.orange)
                        
                        Spacer()
                        
                        Button("Use Environment") {
                            apiKey = ""
                            showEnvironmentStatus = false
                        }
                        .buttonStyle(.link)
                    }
                }
            }
        }
        .onAppear {
            checkEnvironmentVariable()
        }
        .onChange(of: apiKey) { _, _ in
            checkEnvironmentVariable()
        }
    }
    
    private var environmentPlaceholder: String {
        if hasEnvironmentKey {
            return "Override \(provider.environmentVariable) or leave empty"
        } else if provider.requiresAPIKey {
            return "Enter your \(provider.displayName) API key"
        } else {
            return "Optional API key for \(provider.displayName)"
        }
    }
    
    private func checkEnvironmentVariable() {
        let environment = ProcessInfo.processInfo.environment
        hasEnvironmentKey = environment[provider.environmentVariable]?.isEmpty == false
    }
}