import SwiftUI

struct ControlsView: View {
    @EnvironmentObject var actionLogger: ActionLogger
    @State private var sliderValue: Double = 50
    @State private var discreteSliderValue: Double = 3
    @State private var checkboxStates = [false, false, false, false]
    @State private var radioSelection = 1
    @State private var segmentedSelection = 0
    @State private var stepperValue = 0
    @State private var dateValue = Date()
    @State private var colorValue = Color.blue
    @State private var progressValue: Double = 0.3
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                SectionHeader(title: "UI Controls Testing", icon: "slider.horizontal.3")
                
                // Sliders
                GroupBox("Sliders") {
                    VStack(spacing: 20) {
                        VStack(alignment: .leading) {
                            Text("Continuous Slider: \(Int(sliderValue))")
                                .font(.caption)
                            Slider(value: $sliderValue, in: 0...100) {
                                Text("Value")
                            }
                            .accessibilityIdentifier("continuous-slider")
                            .onChange(of: sliderValue) { oldValue, newValue in
                                actionLogger.log(.control, "Slider moved", 
                                               details: "Value: \(Int(oldValue)) → \(Int(newValue))")
                            }
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Discrete Slider: \(Int(discreteSliderValue))")
                                .font(.caption)
                            Slider(value: $discreteSliderValue, in: 1...5, step: 1) {
                                Text("Steps")
                            }
                            .accessibilityIdentifier("discrete-slider")
                            .onChange(of: discreteSliderValue) { oldValue, newValue in
                                actionLogger.log(.control, "Discrete slider changed", 
                                               details: "Step: \(Int(oldValue)) → \(Int(newValue))")
                            }
                        }
                    }
                }
                
                // Checkboxes
                GroupBox("Checkboxes") {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(0..<4) { index in
                            Toggle("Option \(index + 1)", isOn: $checkboxStates[index])
                                .toggleStyle(.checkbox)
                                .accessibilityIdentifier("checkbox-\(index + 1)")
                                .onChange(of: checkboxStates[index]) { _, newValue in
                                    actionLogger.log(.control, "Checkbox \(index + 1) toggled", 
                                                   details: "State: \(newValue ? "checked" : "unchecked")")
                                }
                        }
                        
                        Divider()
                        
                        HStack {
                            Button("Check All") {
                                checkboxStates = [true, true, true, true]
                                actionLogger.log(.control, "All checkboxes checked")
                            }
                            .accessibilityIdentifier("check-all-button")
                            
                            Button("Uncheck All") {
                                checkboxStates = [false, false, false, false]
                                actionLogger.log(.control, "All checkboxes unchecked")
                            }
                            .accessibilityIdentifier("uncheck-all-button")
                            
                            Spacer()
                            
                            Text("Checked: \(checkboxStates.filter { $0 }.count)")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Radio buttons
                GroupBox("Radio Buttons") {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(1..<5) { value in
                            HStack {
                                Image(systemName: radioSelection == value ? "circle.inset.filled" : "circle")
                                    .foregroundColor(radioSelection == value ? .accentColor : .secondary)
                                    .onTapGesture {
                                        radioSelection = value
                                        actionLogger.log(.control, "Radio button selected", 
                                                       details: "Option \(value)")
                                    }
                                Text("Radio Option \(value)")
                            }
                            .accessibilityIdentifier("radio-\(value)")
                        }
                    }
                }
                
                // Segmented control
                GroupBox("Segmented Control") {
                    Picker("View", selection: $segmentedSelection) {
                        Text("List").tag(0)
                        Text("Grid").tag(1)
                        Text("Column").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("segmented-control")
                    .onChange(of: segmentedSelection) { _, newValue in
                        let options = ["List", "Grid", "Column"]
                        actionLogger.log(.control, "Segmented control changed", 
                                       details: "Selected: \(options[newValue])")
                    }
                }
                
                // Stepper
                GroupBox("Stepper") {
                    HStack {
                        Stepper("Value: \(stepperValue)", value: $stepperValue, in: -10...10)
                            .accessibilityIdentifier("stepper-control")
                            .onChange(of: stepperValue) { oldValue, newValue in
                                let direction = newValue > oldValue ? "incremented" : "decremented"
                                actionLogger.log(.control, "Stepper \(direction)", 
                                               details: "Value: \(oldValue) → \(newValue)")
                            }
                        
                        Spacer()
                        
                        Button("Reset") {
                            stepperValue = 0
                            actionLogger.log(.control, "Stepper reset to 0")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .accessibilityIdentifier("reset-stepper-button")
                    }
                }
                
                // Date picker
                GroupBox("Date Picker") {
                    DatePicker("Select Date:", selection: $dateValue, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                        .accessibilityIdentifier("date-picker")
                        .onChange(of: dateValue) { oldValue, newValue in
                            let formatter = DateFormatter()
                            formatter.dateStyle = .medium
                            formatter.timeStyle = .short
                            actionLogger.log(.control, "Date changed", 
                                           details: "From: \(formatter.string(from: oldValue)) To: \(formatter.string(from: newValue))")
                        }
                }
                
                // Progress indicators
                GroupBox("Progress Indicators") {
                    VStack(spacing: 15) {
                        HStack {
                            ProgressView(value: progressValue)
                                .accessibilityIdentifier("progress-bar")
                            Text("\(Int(progressValue * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(spacing: 20) {
                            Button("25%") {
                                progressValue = 0.25
                                actionLogger.log(.control, "Progress set to 25%")
                            }
                            .accessibilityIdentifier("progress-25-button")
                            
                            Button("50%") {
                                progressValue = 0.5
                                actionLogger.log(.control, "Progress set to 50%")
                            }
                            .accessibilityIdentifier("progress-50-button")
                            
                            Button("75%") {
                                progressValue = 0.75
                                actionLogger.log(.control, "Progress set to 75%")
                            }
                            .accessibilityIdentifier("progress-75-button")
                            
                            Button("100%") {
                                progressValue = 1.0
                                actionLogger.log(.control, "Progress set to 100%")
                            }
                            .accessibilityIdentifier("progress-100-button")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Divider()
                        
                        HStack {
                            Text("Indeterminate:")
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(0.8)
                                .accessibilityIdentifier("indeterminate-progress")
                            Spacer()
                        }
                    }
                }
                
                // Color picker
                GroupBox("Color Picker") {
                    HStack {
                        ColorPicker("Select Color:", selection: $colorValue)
                            .accessibilityIdentifier("color-picker")
                            .onChange(of: colorValue) { oldValue, newValue in
                                actionLogger.log(.control, "Color changed", 
                                               details: "New color selected")
                            }
                        
                        Spacer()
                        
                        RoundedRectangle(cornerRadius: 8)
                            .fill(colorValue)
                            .frame(width: 60, height: 30)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray, lineWidth: 1)
                            )
                    }
                }
            }
            .padding()
        }
    }
}