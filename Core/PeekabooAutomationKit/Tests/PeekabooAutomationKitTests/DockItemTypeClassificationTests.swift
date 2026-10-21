import Testing
@testable import PeekabooAutomationKit

struct DockItemTypeClassificationTests {
    @Test(arguments: [
        ("AXApplicationDockItem", DockItemType.application),
        ("AXFolderDockItem", .folder),
        ("AXFileDockItem", .file),
        ("AXURLDockItem", .url),
        ("AXMinimizedWindowDockItem", .minimizedWindow),
        ("AXSeparatorDockItem", .separator),
        ("AXTrashDockItem", .trash),
        ("", .unknown),
        ("AXSeparator", .unknown),
    ])
    func `Dock item types are classified by Accessibility subrole`(subrole: String, expectedType: DockItemType) {
        #expect(DockService.dockItemType(subrole: subrole) == expectedType)
    }
}
