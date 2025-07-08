import Foundation

/// Default implementation of file system operations for session management
public final class FileService: FileServiceProtocol {
    
    public init() {}
    
    public func cleanAllSessions(dryRun: Bool) async throws -> CleanResult {
        let cacheDir = getSessionCacheDirectory()
        var sessionDetails: [SessionDetail] = []
        var totalBytesFreed: Int64 = 0
        
        guard FileManager.default.fileExists(atPath: cacheDir.path) else {
            return CleanResult(
                sessionsRemoved: 0,
                bytesFreed: 0,
                sessionDetails: [],
                dryRun: dryRun
            )
        }
        
        let sessionDirs = try FileManager.default.contentsOfDirectory(
            at: cacheDir,
            includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey],
            options: .skipsHiddenFiles
        )
        
        for sessionDir in sessionDirs {
            guard sessionDir.hasDirectoryPath else { continue }
            
            let sessionSize = try await calculateDirectorySize(sessionDir)
            let sessionId = sessionDir.lastPathComponent
            let resourceValues = try sessionDir.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
            
            let detail = SessionDetail(
                sessionId: sessionId,
                path: sessionDir.path,
                size: sessionSize,
                creationDate: resourceValues.creationDate,
                modificationDate: resourceValues.contentModificationDate
            )
            
            sessionDetails.append(detail)
            totalBytesFreed += sessionSize
            
            if !dryRun {
                try FileManager.default.removeItem(at: sessionDir)
            }
        }
        
        return CleanResult(
            sessionsRemoved: sessionDetails.count,
            bytesFreed: totalBytesFreed,
            sessionDetails: sessionDetails,
            dryRun: dryRun
        )
    }
    
    public func cleanOldSessions(hours: Int, dryRun: Bool) async throws -> CleanResult {
        let cacheDir = getSessionCacheDirectory()
        var sessionDetails: [SessionDetail] = []
        var totalBytesFreed: Int64 = 0
        
        guard FileManager.default.fileExists(atPath: cacheDir.path) else {
            return CleanResult(
                sessionsRemoved: 0,
                bytesFreed: 0,
                sessionDetails: [],
                dryRun: dryRun
            )
        }
        
        let cutoffDate = Date().addingTimeInterval(-Double(hours) * 3600)
        
        let sessionDirs = try FileManager.default.contentsOfDirectory(
            at: cacheDir,
            includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey],
            options: .skipsHiddenFiles
        )
        
        for sessionDir in sessionDirs {
            guard sessionDir.hasDirectoryPath else { continue }
            
            let resourceValues = try sessionDir.resourceValues(forKeys: [.contentModificationDateKey])
            let modificationDate = resourceValues.contentModificationDate
            
            if let modDate = modificationDate, modDate < cutoffDate {
                let sessionSize = try await calculateDirectorySize(sessionDir)
                let sessionId = sessionDir.lastPathComponent
                
                let detail = SessionDetail(
                    sessionId: sessionId,
                    path: sessionDir.path,
                    size: sessionSize,
                    creationDate: nil,
                    modificationDate: modDate
                )
                
                sessionDetails.append(detail)
                totalBytesFreed += sessionSize
                
                if !dryRun {
                    try FileManager.default.removeItem(at: sessionDir)
                }
            }
        }
        
        return CleanResult(
            sessionsRemoved: sessionDetails.count,
            bytesFreed: totalBytesFreed,
            sessionDetails: sessionDetails,
            dryRun: dryRun
        )
    }
    
    public func cleanSpecificSession(sessionId: String, dryRun: Bool) async throws -> CleanResult {
        let cacheDir = getSessionCacheDirectory()
        let sessionDir = cacheDir.appendingPathComponent(sessionId)
        
        guard FileManager.default.fileExists(atPath: sessionDir.path) else {
            // Return empty result instead of throwing error for consistency with original behavior
            return CleanResult(
                sessionsRemoved: 0,
                bytesFreed: 0,
                sessionDetails: [],
                dryRun: dryRun
            )
        }
        
        let sessionSize = try await calculateDirectorySize(sessionDir)
        let resourceValues = try sessionDir.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
        
        let detail = SessionDetail(
            sessionId: sessionId,
            path: sessionDir.path,
            size: sessionSize,
            creationDate: resourceValues.creationDate,
            modificationDate: resourceValues.contentModificationDate
        )
        
        if !dryRun {
            try FileManager.default.removeItem(at: sessionDir)
        }
        
        return CleanResult(
            sessionsRemoved: 1,
            bytesFreed: sessionSize,
            sessionDetails: [detail],
            dryRun: dryRun
        )
    }
    
    public func getSessionCacheDirectory() -> URL {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        return homeDir.appendingPathComponent(".peekaboo/session")
    }
    
    public func calculateDirectorySize(_ directory: URL) async throws -> Int64 {
        var totalSize: Int64 = 0
        
        let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        )
        
        while let fileURL = enumerator?.nextObject() as? URL {
            let fileSize = try fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            totalSize += Int64(fileSize)
        }
        
        return totalSize
    }
    
    public func listSessions() async throws -> [FileSessionInfo] {
        let cacheDir = getSessionCacheDirectory()
        var sessions: [FileSessionInfo] = []
        
        guard FileManager.default.fileExists(atPath: cacheDir.path) else {
            return sessions
        }
        
        let sessionDirs = try FileManager.default.contentsOfDirectory(
            at: cacheDir,
            includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey],
            options: .skipsHiddenFiles
        )
        
        for sessionDir in sessionDirs {
            guard sessionDir.hasDirectoryPath else { continue }
            
            let sessionId = sessionDir.lastPathComponent
            let sessionSize = try await calculateDirectorySize(sessionDir)
            let resourceValues = try sessionDir.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
            
            // Get files in the session directory
            let files = try FileManager.default.contentsOfDirectory(atPath: sessionDir.path)
                .filter { !$0.hasPrefix(".") } // Skip hidden files
            
            let sessionInfo = FileSessionInfo(
                sessionId: sessionId,
                path: sessionDir,
                size: sessionSize,
                creationDate: resourceValues.creationDate ?? Date(),
                modificationDate: resourceValues.contentModificationDate ?? Date(),
                files: files
            )
            
            sessions.append(sessionInfo)
        }
        
        // Sort by modification date, newest first
        sessions.sort { $0.modificationDate > $1.modificationDate }
        
        return sessions
    }
}