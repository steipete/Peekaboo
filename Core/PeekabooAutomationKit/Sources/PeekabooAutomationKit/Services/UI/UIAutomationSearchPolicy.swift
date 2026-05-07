import Foundation

public enum SearchPolicy {
    case balanced
    case debug
}

struct UIAutomationSearchLimits {
    let maxDepth: Int
    let maxChildren: Int
    let timeBudget: TimeInterval

    static func from(policy: SearchPolicy) -> UIAutomationSearchLimits {
        switch policy {
        case .balanced:
            UIAutomationSearchLimits(maxDepth: 8, maxChildren: 200, timeBudget: 0.15)
        case .debug:
            UIAutomationSearchLimits(maxDepth: 32, maxChildren: 2000, timeBudget: 1.0)
        }
    }
}
