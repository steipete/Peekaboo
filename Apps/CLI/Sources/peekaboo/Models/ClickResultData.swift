import Foundation

/// Data structure for click command results
public struct ClickResultData: Codable {
    public let action: String
    public let clicked_element: String?
    public let click_type: String
    public let click_location: [String: Int]
    public let wait_time: Double
    public let execution_time: Double
    
    public init(
        action: String,
        clicked_element: String? = nil,
        click_type: String,
        click_location: [String: Int],
        wait_time: Double,
        execution_time: Double
    ) {
        self.action = action
        self.clicked_element = clicked_element
        self.click_type = click_type
        self.click_location = click_location
        self.wait_time = wait_time
        self.execution_time = execution_time
    }
}