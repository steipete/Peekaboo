import SwiftUI

struct TextInputView: View {
    @EnvironmentObject var actionLogger: ActionLogger
    @State private var basicText = ""
    @State private var multilineText = ""
    @State private var numberText = ""
    @State private var secureText = ""
    @State private var prefilledText = "This text is pre-filled"
    @State private var searchText = ""
    @State private var formattedText = ""
    @FocusState private var focusedField: Field?
    
    enum Field: String {
        case basic, multiline, number, secure, prefilled, search, formatted
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                SectionHeader(title: "Text Input Testing", icon: "textformat")
                
                // Basic text fields
                GroupBox("Text Fields") {
                    VStack(alignment: .leading, spacing: 15) {
                        LabeledTextField(
                            label: "Basic Text Field",
                            text: $basicText,
                            placeholder: "Type here...",
                            identifier: "basic-text-field"
                        )
                        .focused($focusedField, equals: .basic)
                        .onSubmit {
                            actionLogger.log(.text, "Submitted basic text field", 
                                           details: "Value: '\(basicText)'")
                        }
                        .onChange(of: basicText) { oldValue, newValue in
                            if !oldValue.isEmpty || !newValue.isEmpty {
                                actionLogger.log(.text, "Basic text changed", 
                                               details: "From: '\(oldValue)' To: '\(newValue)'")
                            }
                        }
                        
                        LabeledTextField(
                            label: "Number Field",
                            text: $numberText,
                            placeholder: "Numbers only...",
                            identifier: "number-text-field"
                        )
                        .focused($focusedField, equals: .number)
                        .onChange(of: numberText) { oldValue, newValue in
                            // Filter non-numeric characters
                            let filtered = newValue.filter { $0.isNumber }
                            if filtered != newValue {
                                numberText = filtered
                                actionLogger.log(.text, "Non-numeric input filtered", 
                                               details: "Attempted: '\(newValue)'")
                            } else if !oldValue.isEmpty || !newValue.isEmpty {
                                actionLogger.log(.text, "Number text changed", 
                                               details: "Value: '\(newValue)'")
                            }
                        }
                        
                        HStack {
                            Text("Secure Field:")
                                .frame(width: 120, alignment: .trailing)
                            SecureField("Password", text: $secureText)
                                .textFieldStyle(.roundedBorder)
                                .accessibilityIdentifier("secure-text-field")
                                .focused($focusedField, equals: .secure)
                                .onSubmit {
                                    actionLogger.log(.text, "Submitted secure field", 
                                                   details: "Length: \(secureText.count) characters")
                                }
                        }
                        
                        LabeledTextField(
                            label: "Pre-filled Field",
                            text: $prefilledText,
                            placeholder: "",
                            identifier: "prefilled-text-field"
                        )
                        .focused($focusedField, equals: .prefilled)
                        .onChange(of: prefilledText) { oldValue, newValue in
                            actionLogger.log(.text, "Pre-filled text modified", 
                                           details: "From: '\(oldValue)' To: '\(newValue)'")
                        }
                    }
                }
                
                // Search field
                GroupBox("Search Field") {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search...", text: $searchText)
                            .textFieldStyle(.plain)
                            .accessibilityIdentifier("search-field")
                            .focused($focusedField, equals: .search)
                            .onSubmit {
                                actionLogger.log(.text, "Search submitted", 
                                               details: "Query: '\(searchText)'")
                            }
                        
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                                actionLogger.log(.text, "Search cleared")
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("clear-search-button")
                        }
                    }
                    .padding(8)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
                
                // Multiline text
                GroupBox("Multiline Text") {
                    VStack(alignment: .leading) {
                        Text("Text Editor:")
                        TextEditor(text: $multilineText)
                            .frame(height: 100)
                            .border(Color.gray.opacity(0.3))
                            .accessibilityIdentifier("multiline-text-editor")
                            .focused($focusedField, equals: .multiline)
                            .onChange(of: multilineText) { oldValue, newValue in
                                let oldLines = oldValue.components(separatedBy: .newlines).count
                                let newLines = newValue.components(separatedBy: .newlines).count
                                if oldLines != newLines {
                                    actionLogger.log(.text, "Multiline text changed", 
                                                   details: "Lines: \(oldLines) → \(newLines), Characters: \(newValue.count)")
                                }
                            }
                        
                        HStack {
                            Text("\(multilineText.count) characters")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("Clear") {
                                multilineText = ""
                                actionLogger.log(.text, "Multiline text cleared")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .accessibilityIdentifier("clear-multiline-button")
                        }
                    }
                }
                
                // Special characters
                GroupBox("Special Characters") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Test special character input:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("Type special characters...", text: $formattedText)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier("special-char-field")
                            .focused($focusedField, equals: .formatted)
                            .onChange(of: formattedText) { _, newValue in
                                if newValue.contains(where: { !$0.isASCII }) {
                                    actionLogger.log(.text, "Special characters entered", 
                                                   details: "Text: '\(newValue)'")
                                }
                            }
                        
                        HStack(spacing: 10) {
                            ForEach(["@", "#", "$", "€", "™", "©", "®", "😀"], id: \.self) { char in
                                Button(char) {
                                    formattedText.append(char)
                                    actionLogger.log(.text, "Special character button pressed", 
                                                   details: "Character: '\(char)'")
                                }
                                .buttonStyle(.bordered)
                                .accessibilityIdentifier("special-char-\(char)")
                            }
                        }
                    }
                }
                
                // Focus control
                GroupBox("Focus Control") {
                    HStack(spacing: 20) {
                        Button("Focus Basic Field") {
                            focusedField = .basic
                            actionLogger.log(.focus, "Programmatically focused basic field")
                        }
                        .accessibilityIdentifier("focus-basic-button")
                        
                        Button("Focus Search") {
                            focusedField = .search
                            actionLogger.log(.focus, "Programmatically focused search field")
                        }
                        .accessibilityIdentifier("focus-search-button")
                        
                        Button("Clear Focus") {
                            focusedField = nil
                            actionLogger.log(.focus, "Cleared field focus")
                        }
                        .accessibilityIdentifier("clear-focus-button")
                        
                        Spacer()
                        
                        if let focused = focusedField {
                            Label("Focused: \(focused.rawValue)", systemImage: "scope")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding()
        }
        .onAppear {
            actionLogger.log(.focus, "Text input view appeared")
        }
    }
}

struct LabeledTextField: View {
    let label: String
    @Binding var text: String
    let placeholder: String
    let identifier: String
    
    var body: some View {
        HStack {
            Text("\(label):")
                .frame(width: 120, alignment: .trailing)
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier(identifier)
        }
    }
}