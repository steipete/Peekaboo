//
//  ShortcutRecorderView.swift
//  Peekaboo
//

import KeyboardShortcuts
import SwiftUI

/// A keyboard shortcut recorder component using sindresorhus/KeyboardShortcuts
struct ShortcutRecorderView: View {
    let title: String
    let shortcutName: KeyboardShortcuts.Name

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(self.title)
                .font(.headline)

            KeyboardShortcuts.Recorder(for: self.shortcutName)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ShortcutRecorderView(title: "Show Main Window", shortcutName: .showMainWindow)
        ShortcutRecorderView(title: "Toggle Popover", shortcutName: .togglePopover)
    }
    .padding()
    .frame(width: 400)
}
