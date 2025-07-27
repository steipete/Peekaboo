// Version information for Peekaboo CLI
// This file is updated by the build script with actual values
enum Version {
    static let current = "Peekaboo 0.0.1"
    static let gitCommit = "dev"
    static let gitCommitDate = "development"
    static let gitBranch = "development"
    static let buildDate = "development"
    
    static var fullVersion: String {
        return "\(current) (\(gitBranch)/\(gitCommit), \(gitCommitDate))"
    }
}