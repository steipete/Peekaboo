import Foundation

/// Helper for generating element IDs in tests
enum ElementIDGenerator {
    /// Get the prefix for a given role
    static func prefix(for role: String) -> String {
        switch role {
        case "AXButton": return "B"
        case "AXTextField", "AXTextArea": return "T"
        case "AXStaticText": return "S"
        case "AXLink": return "L"
        case "AXImage": return "I"
        case "AXGroup": return "G"
        case "AXWindow": return "W"
        case "AXCheckBox": return "C"
        case "AXRadioButton": return "R"
        case "AXPopUpButton": return "P"
        case "AXComboBox": return "CB"
        case "AXSlider": return "SL"
        case "AXProgressIndicator": return "PI"
        case "AXTable": return "TB"
        case "AXOutline": return "OL"
        case "AXBrowser": return "BR"
        case "AXScrollArea": return "SA"
        case "AXMenu": return "M"
        case "AXMenuItem": return "MI"
        default: return "E" // Generic element
        }
    }
    
    /// Check if a role is actionable
    static func isActionableRole(_ role: String) -> Bool {
        switch role {
        case "AXButton", "AXCheckBox", "AXRadioButton", "AXLink",
             "AXMenuItem", "AXPopUpButton", "AXComboBox", "AXTextField",
             "AXTextArea", "AXSlider":
            return true
        default:
            return false
        }
    }
}