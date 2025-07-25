import SwiftUI

struct ClickTestingView: View {
    @EnvironmentObject var actionLogger: ActionLogger
    @State private var toggleState = false
    @State private var clickCount = 0
    @State private var lastClickType = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                SectionHeader(title: "Click Testing", icon: "cursorarrow.click")
                
                // Basic buttons
                GroupBox("Basic Buttons") {
                    HStack(spacing: 20) {
                        Button("Single Click") {
                            clickCount += 1
                            lastClickType = "Single"
                            actionLogger.log(.click, "Single click on 'Single Click' button", 
                                           details: "Click count: \(clickCount)")
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("single-click-button")
                        
                        Button("Secondary Button") {
                            actionLogger.log(.click, "Clicked 'Secondary Button'")
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("secondary-button")
                        
                        Button("Destructive") {
                            actionLogger.log(.click, "Clicked 'Destructive' button")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .accessibilityIdentifier("destructive-button")
                        
                        Button("Disabled Button") {
                            // This should never be logged
                            actionLogger.log(.click, "ERROR: Disabled button was clicked!")
                        }
                        .disabled(true)
                        .accessibilityIdentifier("disabled-button")
                    }
                }
                
                // Toggle and switch
                GroupBox("Toggle Controls") {
                    HStack(spacing: 30) {
                        Toggle("Toggle Switch", isOn: $toggleState)
                            .onChange(of: toggleState) { _, newValue in
                                actionLogger.log(.click, "Toggle switched to: \(newValue)")
                            }
                            .accessibilityIdentifier("toggle-switch")
                        
                        Button(toggleState ? "ON" : "OFF") {
                            toggleState.toggle()
                            actionLogger.log(.click, "Toggle button clicked - now: \(toggleState ? "ON" : "OFF")")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(toggleState ? .green : .gray)
                        .accessibilityIdentifier("toggle-button")
                    }
                }
                
                // Different sizes
                GroupBox("Button Sizes") {
                    VStack(spacing: 15) {
                        Button("Large Button") {
                            actionLogger.log(.click, "Clicked large button")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .accessibilityIdentifier("large-button")
                        
                        Button("Regular Button") {
                            actionLogger.log(.click, "Clicked regular button")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                        .accessibilityIdentifier("regular-button")
                        
                        Button("Small Button") {
                            actionLogger.log(.click, "Clicked small button")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .accessibilityIdentifier("small-button")
                        
                        Button("Mini Button") {
                            actionLogger.log(.click, "Clicked mini button")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.mini)
                        .accessibilityIdentifier("mini-button")
                    }
                }
                
                // Click areas
                GroupBox("Click Areas") {
                    HStack(spacing: 20) {
                        ClickableArea(
                            title: "Double Click Me",
                            color: .blue,
                            identifier: "double-click-area"
                        ) {
                            actionLogger.log(.click, "Double-clicked area")
                        }
                        .onTapGesture(count: 2) {
                            actionLogger.log(.click, "Double-click detected on area")
                        }
                        
                        ClickableArea(
                            title: "Right Click Me",
                            color: .purple,
                            identifier: "right-click-area"
                        ) {
                            actionLogger.log(.click, "Left-clicked right-click area")
                        }
                        .contextMenu {
                            Button("Context Action 1") {
                                actionLogger.log(.menu, "Context menu: Action 1")
                            }
                            Button("Context Action 2") {
                                actionLogger.log(.menu, "Context menu: Action 2")
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                actionLogger.log(.menu, "Context menu: Delete")
                            }
                        }
                        
                        ClickableArea(
                            title: "Nested Click Target",
                            color: .orange,
                            identifier: "nested-click-area"
                        ) {
                            actionLogger.log(.click, "Clicked outer area")
                        }
                        .overlay(
                            Button("Inner Button") {
                                actionLogger.log(.click, "Clicked inner button (nested)")
                            }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("nested-inner-button")
                        )
                    }
                }
                
                // Status display
                if clickCount > 0 {
                    GroupBox("Click Statistics") {
                        HStack {
                            Label("\(clickCount) total clicks", systemImage: "hand.tap")
                            Spacer()
                            if !lastClickType.isEmpty {
                                Text("Last: \(lastClickType)")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
}

struct ClickableArea: View {
    let title: String
    let color: Color
    let identifier: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                Image(systemName: "hand.tap.fill")
                    .font(.largeTitle)
                Text(title)
                    .font(.caption)
            }
            .frame(width: 120, height: 120)
            .background(color.opacity(0.2))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(color, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}

struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
            Spacer()
        }
        .padding(.bottom, 10)
    }
}