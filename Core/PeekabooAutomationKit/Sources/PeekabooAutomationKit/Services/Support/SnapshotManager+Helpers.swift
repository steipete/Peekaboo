import CoreGraphics
import Foundation
import PeekabooFoundation

extension SnapshotManager {
    // MARK: - Helpers

    func getSnapshotStorageURL() -> URL {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".peekaboo/snapshots")

        // Ensure the directory exists
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)

        return url
    }

    func getSnapshotPath(for snapshotId: String) -> URL {
        self.getSnapshotStorageURL().appendingPathComponent(snapshotId)
    }

    func findLatestValidSnapshot() async -> String? {
        let snapshotDir = self.getSnapshotStorageURL()

        guard let snapshots = try? FileManager.default.contentsOfDirectory(
            at: snapshotDir,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles)
        else {
            return nil
        }

        let tenMinutesAgo = Date().addingTimeInterval(-self.snapshotValidityWindow)

        let validSnapshots = snapshots.compactMap { url -> (url: URL, date: Date)? in
            guard let resourceValues = try? url.resourceValues(forKeys: [.creationDateKey]),
                  let creationDate = resourceValues.creationDate,
                  creationDate > tenMinutesAgo
            else {
                return nil
            }
            return (url, creationDate)
        }.sorted { $0.date > $1.date }

        if let latest = validSnapshots.first {
            let age = Int(-latest.date.timeIntervalSinceNow)
            self.logger.debug(
                "Found valid snapshot: \(latest.url.lastPathComponent) created \(age) seconds ago")
            return latest.url.lastPathComponent
        } else {
            self.logger.debug("No valid snapshots found within \(Int(self.snapshotValidityWindow)) second window")
            return nil
        }
    }

    func findLatestValidSnapshot(applicationBundleId: String) async -> String? {
        let snapshotDir = self.getSnapshotStorageURL()

        guard let snapshots = try? FileManager.default.contentsOfDirectory(
            at: snapshotDir,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles)
        else {
            return nil
        }

        let cutoff = Date().addingTimeInterval(-self.snapshotValidityWindow)

        let recentSnapshots = snapshots.compactMap { url -> (url: URL, createdAt: Date)? in
            guard let values = try? url.resourceValues(forKeys: [.creationDateKey]),
                  let createdAt = values.creationDate,
                  createdAt > cutoff,
                  url.hasDirectoryPath
            else {
                return nil
            }
            return (url, createdAt)
        }.sorted { $0.createdAt > $1.createdAt }

        for entry in recentSnapshots {
            let snapshotId = entry.url.lastPathComponent
            guard let snapshotData = await self.snapshotActor.loadSnapshot(snapshotId: snapshotId, from: entry.url)
            else { continue }
            if snapshotData.applicationBundleId == applicationBundleId {
                return snapshotId
            }
        }

        return nil
    }

    func convertElementTypeToRole(_ type: ElementType) -> String {
        switch type {
        case .button: "AXButton"
        case .textField: "AXTextField"
        case .link: "AXLink"
        case .image: "AXImage"
        case .group: "AXGroup"
        case .slider: "AXSlider"
        case .checkbox: "AXCheckBox"
        case .menu: "AXMenu"
        case .staticText: "AXStaticText"
        case .radioButton: "AXRadioButton"
        case .menuItem: "AXMenuItem"
        case .window: "AXWindow"
        case .dialog: "AXDialog"
        case .other: "AXUnknown"
        }
    }

    func convertRoleToElementType(_ role: String) -> ElementType {
        switch role {
        case "AXButton": .button
        case "AXTextField", "AXTextArea": .textField
        case "AXLink": .link
        case "AXImage": .image
        case "AXGroup": .group
        case "AXSlider": .slider
        case "AXCheckBox": .checkbox
        case "AXMenu", "AXMenuItem": .menu
        default: .other
        }
    }

    func isActionableType(_ type: ElementType) -> Bool {
        switch type {
        case .button, .textField, .link, .checkbox, .slider, .menu, .menuItem, .radioButton:
            true
        case .image, .group, .other, .staticText, .window, .dialog:
            false
        }
    }

    func organizeElementsByType(_ elements: [DetectedElement]) -> DetectedElements {
        var buttons: [DetectedElement] = []
        var textFields: [DetectedElement] = []
        var links: [DetectedElement] = []
        var images: [DetectedElement] = []
        var groups: [DetectedElement] = []
        var sliders: [DetectedElement] = []
        var checkboxes: [DetectedElement] = []
        var menus: [DetectedElement] = []
        var other: [DetectedElement] = []

        for element in elements {
            switch element.type {
            case .button: buttons.append(element)
            case .textField: textFields.append(element)
            case .link: links.append(element)
            case .image: images.append(element)
            case .group: groups.append(element)
            case .slider: sliders.append(element)
            case .checkbox: checkboxes.append(element)
            case .menu, .menuItem: menus.append(element)
            case .other, .staticText, .radioButton, .window, .dialog: other.append(element)
            }
        }

        return DetectedElements(
            buttons: buttons,
            textFields: textFields,
            links: links,
            images: images,
            groups: groups,
            sliders: sliders,
            checkboxes: checkboxes,
            menus: menus,
            other: other)
    }

    func applyWindowContext(_ context: WindowContext, to snapshotData: inout UIAutomationSnapshot) {
        snapshotData.applicationName = context.applicationName ?? snapshotData.applicationName
        snapshotData.applicationBundleId = context.applicationBundleId ?? snapshotData.applicationBundleId
        snapshotData.applicationProcessId = context.applicationProcessId ?? snapshotData.applicationProcessId
        snapshotData.windowTitle = context.windowTitle ?? snapshotData.windowTitle
        snapshotData.windowBounds = context.windowBounds ?? snapshotData.windowBounds
        if let windowID = context.windowID {
            snapshotData.windowID = CGWindowID(windowID)
        }
    }

    func applyLegacyWarnings(_ warnings: [String], to snapshotData: inout UIAutomationSnapshot) {
        for warning in warnings {
            if warning.hasPrefix("APP:") || warning.hasPrefix("app:") {
                snapshotData.applicationName = String(warning.dropFirst(4))
            } else if warning.hasPrefix("WINDOW:") || warning.hasPrefix("window:") {
                snapshotData.windowTitle = String(warning.dropFirst(7))
            } else if warning.hasPrefix("BOUNDS:"),
                      let boundsData = String(warning.dropFirst(7)).data(using: .utf8),
                      let bounds = try? JSONDecoder().decode(CGRect.self, from: boundsData)
            {
                snapshotData.windowBounds = bounds
            } else if warning.hasPrefix("WINDOW_ID:"),
                      let windowID = CGWindowID(String(warning.dropFirst(10)))
            {
                snapshotData.windowID = windowID
            } else if warning.hasPrefix("AX_IDENTIFIER:") {
                snapshotData.windowAXIdentifier = String(warning.dropFirst(14))
            }
        }
    }

    func buildWarnings(from snapshotData: UIAutomationSnapshot) -> [String] {
        var warnings: [String] = []
        if let appName = snapshotData.applicationName {
            warnings.append("APP:\(appName)")
        }
        if let windowTitle = snapshotData.windowTitle {
            warnings.append("WINDOW:\(windowTitle)")
        }
        if let windowBounds = snapshotData.windowBounds,
           let boundsData = try? JSONEncoder().encode(windowBounds),
           let boundsString = String(data: boundsData, encoding: .utf8)
        {
            warnings.append("BOUNDS:\(boundsString)")
        }
        if let windowID = snapshotData.windowID {
            warnings.append("WINDOW_ID:\(windowID)")
        }
        if let axIdentifier = snapshotData.windowAXIdentifier {
            warnings.append("AX_IDENTIFIER:\(axIdentifier)")
        }
        return warnings
    }

    func windowContext(from snapshotData: UIAutomationSnapshot) -> WindowContext? {
        guard snapshotData.applicationName != nil ||
            snapshotData.applicationBundleId != nil ||
            snapshotData.applicationProcessId != nil ||
            snapshotData.windowTitle != nil ||
            snapshotData.windowID != nil ||
            snapshotData.windowBounds != nil
        else {
            return nil
        }

        return WindowContext(
            applicationName: snapshotData.applicationName,
            applicationBundleId: snapshotData.applicationBundleId,
            applicationProcessId: snapshotData.applicationProcessId,
            windowTitle: snapshotData.windowTitle,
            windowID: snapshotData.windowID.map(Int.init),
            windowBounds: snapshotData.windowBounds)
    }

    func countScreenshots(in snapshotURL: URL) -> Int {
        let files = try? FileManager.default.contentsOfDirectory(at: snapshotURL, includingPropertiesForKeys: nil)
        return files?.count(where: { $0.pathExtension == "png" }) ?? 0
    }

    func calculateDirectorySize(_ url: URL) -> Int64 {
        var totalSize: Int64 = 0

        if let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles])
        {
            for case let fileURL as URL in enumerator {
                if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                   let fileSize = resourceValues.fileSize
                {
                    totalSize += Int64(fileSize)
                }
            }
        }

        return totalSize
    }

    func extractProcessId(from snapshotId: String) -> Int32 {
        // Try to extract PID from old-style snapshot IDs (just numbers)
        if let pid = Int32(snapshotId) {
            return pid
        }
        // For new timestamp-based IDs, return 0
        return 0
    }

    func isProcessActive(_ pid: Int32) -> Bool {
        guard pid > 0 else { return false }
        return kill(pid, 0) == 0
    }
}
