import AppKit
import ArgumentParser
import Foundation
import PeekabooCore

/// Manage macOS Spaces (virtual desktops)
struct SpaceCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "space",
        abstract: "Manage macOS Spaces (virtual desktops)",
        discussion: """
        SYNOPSIS:
          peekaboo space SUBCOMMAND [OPTIONS]

        DESCRIPTION:
          Provides Space (virtual desktop) management capabilities including
          listing Spaces, switching between them, and moving windows.

        EXAMPLES:
          # List all Spaces
          peekaboo space list

          # Switch to Space 2
          peekaboo space switch --to 2

          # Move window to Space 3
          peekaboo space move-window --app Safari --to 3

          # Move window to current Space
          peekaboo space move-window --app Terminal --to-current

        SUBCOMMANDS:
          list          List all Spaces and their windows
          switch        Switch to a different Space
          move-window   Move a window to a different Space

        NOTE:
          Space management uses private macOS APIs that may change between
          macOS versions. Some features may not work on all systems.
        """,
        subcommands: [
            ListSubcommand.self,
            SwitchSubcommand.self,
            MoveWindowSubcommand.self,
        ])
}

// MARK: - List Spaces

struct ListSubcommand: AsyncParsableCommand, ErrorHandlingCommand, OutputFormattable {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List all Spaces and their windows")
    
    @Flag(name: .long, help: "Include detailed window information")
    var detailed = false
    
    @Flag(name: .long, help: "Output results in JSON format")
    var jsonOutput = false
    
    func run() async throws {
        Logger.shared.setJsonOutputMode(self.jsonOutput)
        
        await MainActor.run {
            let spaceService = SpaceManagementService()
            let spaces = spaceService.getAllSpaces()
            
            if self.jsonOutput {
                let data = SpaceListData(
                    spaces: spaces.map { space in
                        SpaceData(
                            id: space.id,
                            type: space.type.rawValue,
                            is_active: space.isActive,
                            display_id: space.displayID
                        )
                    }
                )
                outputSuccessCodable(data: data)
            } else {
                print("Spaces:")
                for (index, space) in spaces.enumerated() {
                    let marker = space.isActive ? "→" : " "
                    let displayInfo = space.displayID.map { " (Display \($0))" } ?? ""
                    print("\(marker) Space \(index + 1) [ID: \(space.id), Type: \(space.type.rawValue)\(displayInfo)]")
                    
                    if self.detailed {
                        // TODO: Add window listing for each Space
                        // This would require iterating through all windows and checking their Space
                    }
                }
                
                if spaces.isEmpty {
                    print("No Spaces found (this may indicate an API issue)")
                }
            }
        }
    }
}

// MARK: - Switch Space

struct SwitchSubcommand: AsyncParsableCommand, ErrorHandlingCommand, OutputFormattable {
    static let configuration = CommandConfiguration(
        commandName: "switch",
        abstract: "Switch to a different Space")
    
    @Option(name: .long, help: "Space number to switch to (1-based)")
    var to: Int
    
    @Flag(name: .long, help: "Output results in JSON format")
    var jsonOutput = false
    
    func run() async throws {
        Logger.shared.setJsonOutputMode(self.jsonOutput)
        
        do {
            let spaceService = await MainActor.run { SpaceManagementService() }
            let spaces = await MainActor.run { spaceService.getAllSpaces() }
            
            // Convert 1-based index to actual Space
            guard self.to > 0 && self.to <= spaces.count else {
                throw ValidationError("Invalid Space number. Available: 1-\(spaces.count)")
            }
            
            let targetSpace = spaces[self.to - 1]
            
            try await spaceService.switchToSpace(targetSpace.id)
            
            if self.jsonOutput {
                let data = SpaceActionResult(
                    action: "switch",
                    success: true,
                    space_id: targetSpace.id,
                    space_number: self.to
                )
                outputSuccessCodable(data: data)
            } else {
                print("✓ Switched to Space \(self.to)")
            }
            
        } catch {
            handleError(error)
            throw ExitCode(1)
        }
    }
}

// MARK: - Move Window to Space

struct MoveWindowSubcommand: AsyncParsableCommand, ErrorHandlingCommand, OutputFormattable, ApplicationResolvable {
    static let configuration = CommandConfiguration(
        commandName: "move-window",
        abstract: "Move a window to a different Space")
    
    @Option(name: .long, help: "Target application name, bundle ID, or 'PID:12345'")
    var app: String?
    
    @Option(name: .long, help: "Target application by process ID")
    var pid: Int32?
    
    @Option(name: .long, help: "Target window by title (partial match supported)")
    var windowTitle: String?
    
    @Option(name: .long, help: "Target window by index (0-based, frontmost is 0)")
    var windowIndex: Int?
    
    @Option(name: .long, help: "Space number to move window to (1-based)")
    var to: Int?
    
    @Flag(name: .long, help: "Move window to current Space")
    var toCurrent = false
    
    @Flag(name: .long, help: "Switch to the target Space after moving")
    var follow = false
    
    @Flag(name: .long, help: "Output results in JSON format")
    var jsonOutput = false
    
    func run() async throws {
        Logger.shared.setJsonOutputMode(self.jsonOutput)
        
        do {
            // Validate inputs
            let appIdentifier = try self.resolveApplicationIdentifier()
            
            guard self.to != nil || self.toCurrent else {
                throw ValidationError("Must specify either --to or --to-current")
            }
            
            guard !(self.to != nil && self.toCurrent) else {
                throw ValidationError("Cannot specify both --to and --to-current")
            }
            
            // Create window identification options
            var windowOptions = WindowIdentificationOptions()
            windowOptions.app = appIdentifier
            windowOptions.windowTitle = self.windowTitle
            windowOptions.windowIndex = self.windowIndex
            
            // Get window info
            let target = try windowOptions.toWindowTarget()
            let windows = try await PeekabooServices.shared.windows.listWindows(target: target)
            let windowInfo = windowOptions.selectWindow(from: windows)
            
            guard let info = windowInfo else {
                throw NotFoundError.window(app: appIdentifier)
            }
            
            let windowID = CGWindowID(info.windowID)
            
            let spaceService = await MainActor.run { SpaceManagementService() }
            
            if self.toCurrent {
                // Move to current Space
                try await MainActor.run {
                    try spaceService.moveWindowToCurrentSpace(windowID: windowID)
                }
                
                if self.jsonOutput {
                    let data = WindowSpaceActionResult(
                        action: "move-window",
                        success: true,
                        window_id: windowID,
                        window_title: info.title,
                        space_id: nil,
                        space_number: nil,
                        moved_to_current: true,
                        followed: nil
                    )
                    outputSuccessCodable(data: data)
                } else {
                    print("✓ Moved window '\(info.title)' to current Space")
                }
                
            } else if let spaceNum = self.to {
                // Move to specific Space
                let spaces = await MainActor.run { spaceService.getAllSpaces() }
                
                guard spaceNum > 0 && spaceNum <= spaces.count else {
                    throw ValidationError("Invalid Space number. Available: 1-\(spaces.count)")
                }
                
                let targetSpace = spaces[spaceNum - 1]
                try await MainActor.run {
                    try spaceService.moveWindowToSpace(windowID: windowID, spaceID: targetSpace.id)
                }
                
                if self.follow {
                    try await spaceService.switchToSpace(targetSpace.id)
                }
                
                if self.jsonOutput {
                    let data = WindowSpaceActionResult(
                        action: "move-window",
                        success: true,
                        window_id: windowID,
                        window_title: info.title,
                        space_id: targetSpace.id,
                        space_number: spaceNum,
                        moved_to_current: false,
                        followed: self.follow
                    )
                    outputSuccessCodable(data: data)
                } else {
                    var message = "✓ Moved window '\(info.title)' to Space \(spaceNum)"
                    if self.follow {
                        message += " (and switched to it)"
                    }
                    print(message)
                }
            }
            
        } catch {
            handleError(error)
            throw ExitCode(1)
        }
    }
}

// MARK: - Response Types

struct SpaceListData: Codable {
    let spaces: [SpaceData]
}

struct SpaceData: Codable {
    let id: UInt64
    let type: String
    let is_active: Bool
    let display_id: CGDirectDisplayID?
}

struct SpaceActionResult: Codable {
    let action: String
    let success: Bool
    let space_id: UInt64
    let space_number: Int
}

struct WindowSpaceActionResult: Codable {
    let action: String
    let success: Bool
    let window_id: CGWindowID
    let window_title: String
    let space_id: UInt64?
    let space_number: Int?
    let moved_to_current: Bool?
    let followed: Bool?
}