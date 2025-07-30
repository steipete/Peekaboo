import Foundation

/// Helper for generating element IDs in tests
enum ElementIDGenerator {
    /// Get the prefix for a given role
    static func prefix(for role: String) -> String {
        switch role {
        case "AXButton": "B"
        case "AXTextField", "AXTextArea": "T"
        case "AXStaticText": "S"
        case "AXLink": "L"
        case "AXImage": "I"
        case "AXGroup": "G"
        case "AXWindow": "W"
        case "AXCheckBox": "C"
        case "AXRadioButton": "R"
        case "AXPopUpButton": "P"
        case "AXComboBox": "CB"
        case "AXSlider": "SL"
        case "AXProgressIndicator": "PI"
        case "AXTable": "TB"
        case "AXOutline": "OL"
        case "AXBrowser": "BR"
        case "AXScrollArea": "SA"
        case "AXMenu": "M"
        case "AXMenuItem": "MI"
        default: "E" // Generic element
        }
    }

    /// Check if a role is actionable
    static func isActionableRole(_ role: String) -> Bool {
        switch role {
        case "AXButton", "AXCheckBox", "AXRadioButton", "AXLink",
             "AXMenuItem", "AXPopUpButton", "AXComboBox", "AXTextField",
             "AXTextArea", "AXSlider":
            true
        default:
            false
        }
    }
}
