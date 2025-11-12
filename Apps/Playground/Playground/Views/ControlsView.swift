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
                            Text("Continuous Slider: \(Int(self.sliderValue))")
                                .font(.caption)
                            Slider(value: self.$sliderValue, in: 0...100) {
                                Text("Value")
                            }
                            .accessibilityIdentifier("continuous-slider")
                            .onChange(of: self.sliderValue) { oldValue, newValue in
                                self.actionLogger.log(
                                    .control,
                                    "Slider moved",
                                    details: "Value: \(Int(oldValue)) → \(Int(newValue))")
                            }
                        }

                        VStack(alignment: .leading) {
                            Text("Discrete Slider: \(Int(self.discreteSliderValue))")
                                .font(.caption)
                            Slider(value: self.$discreteSliderValue, in: 1...5, step: 1) {
                                Text("Steps")
                            }
                            .accessibilityIdentifier("discrete-slider")
                            .onChange(of: self.discreteSliderValue) { oldValue, newValue in
                                self.actionLogger.log(
                                    .control,
                                    "Discrete slider changed",
                                    details: "Step: \(Int(oldValue)) → \(Int(newValue))")
                            }
                        }
                    }
                }

                // Checkboxes
                GroupBox("Checkboxes") {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(0..<4) { index in
                            Toggle("Option \(index + 1)", isOn: self.$checkboxStates[index])
                                .toggleStyle(.checkbox)
                                .accessibilityIdentifier("checkbox-\(index + 1)")
                                .onChange(of: self.checkboxStates[index]) { _, newValue in
                                    self.actionLogger.log(
                                        .control,
                                        "Checkbox \(index + 1) toggled",
                                        details: "State: \(newValue ? "checked" : "unchecked")")
                                }
                        }

                        Divider()

                        HStack {
                            Button("Check All") {
                                self.checkboxStates = [true, true, true, true]
                                self.actionLogger.log(.control, "All checkboxes checked")
                            }
                            .accessibilityIdentifier("check-all-button")

                            Button("Uncheck All") {
                                self.checkboxStates = [false, false, false, false]
                                self.actionLogger.log(.control, "All checkboxes unchecked")
                            }
                            .accessibilityIdentifier("uncheck-all-button")

                            Spacer()

                            Text("Checked: \(self.checkboxStates.count(where: { $0 }))")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Radio buttons
                GroupBox("Radio Buttons") {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(1..<5) { value in
                            HStack {
                                Image(systemName: self.radioSelection == value ? "circle.inset.filled" : "circle")
                                    .foregroundColor(self.radioSelection == value ? .accentColor : .secondary)
                                    .onTapGesture {
                                        self.radioSelection = value
                                        self.actionLogger.log(
                                            .control,
                                            "Radio button selected",
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
                    Picker("View", selection: self.$segmentedSelection) {
                        Text("List").tag(0)
                        Text("Grid").tag(1)
                        Text("Column").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("segmented-control")
                    .onChange(of: self.segmentedSelection) { _, newValue in
                        let options = ["List", "Grid", "Column"]
                        self.actionLogger.log(
                            .control,
                            "Segmented control changed",
                            details: "Selected: \(options[newValue])")
                    }
                }

                // Stepper
                GroupBox("Stepper") {
                    HStack {
                        Stepper("Value: \(self.stepperValue)", value: self.$stepperValue, in: -10...10)
                            .accessibilityIdentifier("stepper-control")
                            .onChange(of: self.stepperValue) { oldValue, newValue in
                                let direction = newValue > oldValue ? "incremented" : "decremented"
                                self.actionLogger.log(
                                    .control,
                                    "Stepper \(direction)",
                                    details: "Value: \(oldValue) → \(newValue)")
                            }

                        Spacer()

                        Button("Reset") {
                            self.stepperValue = 0
                            self.actionLogger.log(.control, "Stepper reset to 0")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .accessibilityIdentifier("reset-stepper-button")
                    }
                }

                // Date picker
                GroupBox("Date Picker") {
                    DatePicker("Select Date:", selection: self.$dateValue, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                        .accessibilityIdentifier("date-picker")
                        .onChange(of: self.dateValue) { oldValue, newValue in
                            let formatter = DateFormatter()
                            formatter.dateStyle = .medium
                            formatter.timeStyle = .short
                            let oldString = formatter.string(from: oldValue)
                            let newString = formatter.string(from: newValue)
                            self.actionLogger.log(
                                .control,
                                "Date changed",
                                details: "From: \(oldString) To: \(newString)")
                        }
                }

                // Progress indicators
                GroupBox("Progress Indicators") {
                    VStack(spacing: 15) {
                        HStack {
                            ProgressView(value: self.progressValue)
                                .accessibilityIdentifier("progress-bar")
                            Text("\(Int(self.progressValue * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        HStack(spacing: 20) {
                            Button("25%") {
                                self.progressValue = 0.25
                                self.actionLogger.log(.control, "Progress set to 25%")
                            }
                            .accessibilityIdentifier("progress-25-button")

                            Button("50%") {
                                self.progressValue = 0.5
                                self.actionLogger.log(.control, "Progress set to 50%")
                            }
                            .accessibilityIdentifier("progress-50-button")

                            Button("75%") {
                                self.progressValue = 0.75
                                self.actionLogger.log(.control, "Progress set to 75%")
                            }
                            .accessibilityIdentifier("progress-75-button")

                            Button("100%") {
                                self.progressValue = 1.0
                                self.actionLogger.log(.control, "Progress set to 100%")
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
                        ColorPicker("Select Color:", selection: self.$colorValue)
                            .accessibilityIdentifier("color-picker")
                            .onChange(of: self.colorValue) { _, _ in
                                self.actionLogger.log(
                                    .control,
                                    "Color changed",
                                    details: "New color selected")
                            }

                        Spacer()

                        RoundedRectangle(cornerRadius: 8)
                            .fill(self.colorValue)
                            .frame(width: 60, height: 30)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray, lineWidth: 1))
                    }
                }
            }
            .padding()
        }
    }
}
