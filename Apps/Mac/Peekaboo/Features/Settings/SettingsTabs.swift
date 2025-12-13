import Foundation

enum PeekabooSettingsTab: Hashable, CaseIterable {
    case general
    case ai
    case visualizer
    case shortcuts
    case permissions

    var title: String {
        switch self {
        case .general: "General"
        case .ai: "AI"
        case .visualizer: "Visualizer"
        case .shortcuts: "Shortcuts"
        case .permissions: "Permissions"
        }
    }
}

@MainActor
enum SettingsTabRouter {
    private static var pending: PeekabooSettingsTab?

    static func request(_ tab: PeekabooSettingsTab) {
        self.pending = tab
    }

    static func consumePending() -> PeekabooSettingsTab? {
        defer { self.pending = nil }
        return self.pending
    }
}

extension Notification.Name {
    static let peekabooSelectSettingsTab = Notification.Name("peekabooSelectSettingsTab")
}
