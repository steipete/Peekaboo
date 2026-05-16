import PeekabooAutomationKit

enum DetectedElementSnapshotConverter {
    static func convert(_ detected: [DetectedElement]) -> [UIElement] {
        detected.map { element in
            UIElement(
                id: element.id,
                elementId: element.id,
                role: element.type.rawValue,
                title: element.label,
                label: element.label,
                value: element.value,
                description: element.attributes["description"],
                help: element.attributes["help"],
                roleDescription: element.attributes["roleDescription"],
                identifier: element.attributes["identifier"],
                frame: element.bounds,
                isActionable: element.isEnabled,
                parentId: nil,
                children: [],
                keyboardShortcut: element.attributes["keyboardShortcut"])
        }
    }
}
