import AppKit
import Foundation

extension SpaceManagementService {
    func buildSpacesByDisplay(
        managedSpaces: NSArray,
        activeSpace: CGSSpaceID) -> [CGDirectDisplayID: [SpaceInfo]]
    {
        var spacesByDisplay: [CGDirectDisplayID: [SpaceInfo]] = [:]

        for case let displayDict as [String: Any] in managedSpaces {
            let displayID = self.resolveDisplayID(from: displayDict)
            guard displayID != 0,
                  let spaces = displayDict["Spaces"] as? [[String: Any]]
            else { continue }

            let displaySpaces = spaces.compactMap { spaceDict in
                self.makeSpaceInfo(
                    from: spaceDict,
                    displayID: displayID,
                    activeSpace: activeSpace)
            }

            if !displaySpaces.isEmpty {
                spacesByDisplay[displayID] = displaySpaces
            }
        }

        return spacesByDisplay
    }

    private func resolveDisplayID(from displayDict: [String: Any]) -> CGDirectDisplayID {
        guard displayDict["Display Identifier"] is String else { return 0 }

        let displays = NSScreen.screens.compactMap { screen -> CGDirectDisplayID? in
            if let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
                return screenNumber.uint32Value
            }
            return nil
        }
        return displays.first ?? 0
    }

    private func makeSpaceInfo(
        from spaceDict: [String: Any],
        displayID: CGDirectDisplayID,
        activeSpace: CGSSpaceID) -> SpaceInfo?
    {
        guard let spaceIDValue = spaceDict["ManagedSpaceID"] as? Int64 else { return nil }
        let spaceID = CGSSpaceID(spaceIDValue)
        let typeValue = spaceDict["type"] as? Int ?? 0
        let spaceName = spaceDict["name"] as? String ?? spaceDict["Name"] as? String
        let ownerPIDs = spaceDict["ownerPIDs"] as? [Int] ?? spaceDict["Owners"] as? [Int] ?? []

        return SpaceInfo(
            id: spaceID,
            type: self.mapSpaceType(typeValue),
            isActive: spaceID == activeSpace,
            displayID: displayID,
            name: spaceName,
            ownerPIDs: ownerPIDs)
    }

    private func mapSpaceType(_ rawValue: Int) -> SpaceInfo.SpaceType {
        switch rawValue {
        case kCGSSpaceUser: .user
        case kCGSSpaceFullscreen: .fullscreen
        case kCGSSpaceSystem: .system
        case kCGSSpaceTiled: .tiled
        default: .unknown
        }
    }
}
