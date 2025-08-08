//
//  RealtimeSettingsView.swift
//  Peekaboo
//

import SwiftUI
import Tachikoma

/// Settings popover for realtime voice configuration
struct RealtimeSettingsView: View {
    let service: RealtimeVoiceService
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedVoice: RealtimeVoice
    @State private var customInstructions: String
    
    init(service: RealtimeVoiceService) {
        self.service = service
        self._selectedVoice = State(initialValue: service.selectedVoice)
        self._customInstructions = State(initialValue: service.customInstructions ?? "")
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Label("Realtime Settings", systemImage: "waveform.circle")
                    .font(.headline)
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.bottom, 8)
            
            // Voice selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Voice")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Picker("Voice", selection: $selectedVoice) {
                    ForEach([RealtimeVoice.alloy, .echo, .fable, .onyx, .nova, .shimmer], id: \.self) { voice in
                        Text(voice.displayName)
                            .tag(voice)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedVoice) { _, newVoice in
                    service.updateVoice(newVoice)
                }
            }
            
            Divider()
            
            // Custom instructions
            VStack(alignment: .leading, spacing: 8) {
                Text("Custom Instructions (Optional)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ScrollView {
                    TextEditor(text: $customInstructions)
                        .font(.caption)
                        .scrollContentBackground(.hidden)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(4)
                        .frame(minHeight: 60)
                }
                .frame(height: 80)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
                .onChange(of: customInstructions) { _, newValue in
                    service.customInstructions = newValue.isEmpty ? nil : newValue
                }
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 300, height: 250)
    }
}