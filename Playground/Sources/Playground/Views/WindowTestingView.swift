import SwiftUI
import AppKit

struct WindowTestingView: View {
    @EnvironmentObject var actionLogger: ActionLogger
    @State private var windowSize = CGSize(width: 800, height: 600)
    @State private var windowPosition = CGPoint(x: 100, y: 100)
    @State private var isMinimized = false
    @State private var isMaximized = false
    @State private var newWindowCount = 0
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                SectionHeader(title: "Window Testing", icon: "macwindow")
                
                // Current window info
                GroupBox("Current Window") {
                    if let window = NSApp.mainWindow {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Label("Title:", systemImage: "textformat")
                                Text(window.title)
                                    .fontWeight(.medium)
                            }
                            
                            HStack {
                                Label("Position:", systemImage: "arrow.up.left.square")
                                Text("X: \(Int(window.frame.origin.x)), Y: \(Int(window.frame.origin.y))")
                                    .font(.system(.body, design: .monospaced))
                            }
                            
                            HStack {
                                Label("Size:", systemImage: "arrow.up.left.and.arrow.down.right")
                                Text("W: \(Int(window.frame.width)), H: \(Int(window.frame.height))")
                                    .font(.system(.body, design: .monospaced))
                            }
                            
                            HStack {
                                Label("State:", systemImage: "info.circle")
                                if window.isMiniaturized {
                                    Text("Minimized")
                                        .foregroundColor(.orange)
                                } else if window.isZoomed {
                                    Text("Maximized")
                                        .foregroundColor(.green)
                                } else {
                                    Text("Normal")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
                
                // Window controls
                GroupBox("Window Controls") {
                    VStack(spacing: 15) {
                        HStack(spacing: 20) {
                            Button("Minimize") {
                                NSApp.mainWindow?.miniaturize(nil)
                                actionLogger.log(.window, "Window minimized")
                            }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("minimize-button")
                            
                            Button("Maximize") {
                                NSApp.mainWindow?.zoom(nil)
                                actionLogger.log(.window, "Window maximized/restored")
                            }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("maximize-button")
                            
                            Button("Center") {
                                NSApp.mainWindow?.center()
                                if let frame = NSApp.mainWindow?.frame {
                                    actionLogger.log(.window, "Window centered", 
                                                   details: "Position: (\(Int(frame.origin.x)), \(Int(frame.origin.y)))")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("center-button")
                            
                            Button("Bring to Front") {
                                NSApp.mainWindow?.makeKeyAndOrderFront(nil)
                                actionLogger.log(.window, "Window brought to front")
                            }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("bring-front-button")
                        }
                    }
                }
                
                // Window positioning
                GroupBox("Window Positioning") {
                    VStack(spacing: 15) {
                        HStack(spacing: 20) {
                            Button("Top Left") {
                                moveWindow(to: CGPoint(x: 0, y: 0))
                            }
                            .accessibilityIdentifier("move-top-left")
                            
                            Button("Top Right") {
                                if let screen = NSScreen.main {
                                    let x = screen.frame.width - (NSApp.mainWindow?.frame.width ?? 800)
                                    moveWindow(to: CGPoint(x: x, y: 0))
                                }
                            }
                            .accessibilityIdentifier("move-top-right")
                            
                            Button("Bottom Left") {
                                if let screen = NSScreen.main {
                                    let y = screen.frame.height - (NSApp.mainWindow?.frame.height ?? 600)
                                    moveWindow(to: CGPoint(x: 0, y: y))
                                }
                            }
                            .accessibilityIdentifier("move-bottom-left")
                            
                            Button("Bottom Right") {
                                if let screen = NSScreen.main, let window = NSApp.mainWindow {
                                    let x = screen.frame.width - window.frame.width
                                    let y = screen.frame.height - window.frame.height
                                    moveWindow(to: CGPoint(x: x, y: y))
                                }
                            }
                            .accessibilityIdentifier("move-bottom-right")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                // Window resizing
                GroupBox("Window Resizing") {
                    VStack(spacing: 15) {
                        HStack(spacing: 20) {
                            Button("Small (600x400)") {
                                resizeWindow(to: CGSize(width: 600, height: 400))
                            }
                            .accessibilityIdentifier("resize-small")
                            
                            Button("Medium (800x600)") {
                                resizeWindow(to: CGSize(width: 800, height: 600))
                            }
                            .accessibilityIdentifier("resize-medium")
                            
                            Button("Large (1200x800)") {
                                resizeWindow(to: CGSize(width: 1200, height: 800))
                            }
                            .accessibilityIdentifier("resize-large")
                            
                            Button("Square (700x700)") {
                                resizeWindow(to: CGSize(width: 700, height: 700))
                            }
                            .accessibilityIdentifier("resize-square")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                // Multiple windows
                GroupBox("Multiple Windows") {
                    VStack(spacing: 15) {
                        HStack {
                            Button("Open New Window") {
                                openNewWindow()
                            }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("open-new-window")
                            
                            Button("Open Log Viewer") {
                                openLogViewer()
                            }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("open-log-viewer")
                            
                            Spacer()
                            
                            Text("Windows opened: \(newWindowCount)")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Button("Cascade Windows") {
                                cascadeWindows()
                            }
                            .accessibilityIdentifier("cascade-windows")
                            
                            Button("Tile Windows") {
                                tileWindows()
                            }
                            .accessibilityIdentifier("tile-windows")
                            
                            Button("Close Other Windows") {
                                closeOtherWindows()
                            }
                            .foregroundColor(.red)
                            .accessibilityIdentifier("close-other-windows")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                // Window state triggers
                GroupBox("State Triggers") {
                    Text("These buttons simulate window state changes for testing:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    HStack(spacing: 20) {
                        Button("Simulate Focus Lost") {
                            NSApp.mainWindow?.resignKey()
                            actionLogger.log(.window, "Window focus lost (simulated)")
                        }
                        .accessibilityIdentifier("simulate-focus-lost")
                        
                        Button("Simulate Focus Gained") {
                            NSApp.mainWindow?.makeKey()
                            actionLogger.log(.window, "Window focus gained (simulated)")
                        }
                        .accessibilityIdentifier("simulate-focus-gained")
                        
                        Button("Toggle Full Screen") {
                            NSApp.mainWindow?.toggleFullScreen(nil)
                            actionLogger.log(.window, "Full screen toggled")
                        }
                        .accessibilityIdentifier("toggle-fullscreen")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding()
        }
    }
    
    private func moveWindow(to point: CGPoint) {
        NSApp.mainWindow?.setFrameOrigin(point)
        actionLogger.log(.window, "Window moved", 
                       details: "Position: (\(Int(point.x)), \(Int(point.y)))")
    }
    
    private func resizeWindow(to size: CGSize) {
        if let window = NSApp.mainWindow {
            var frame = window.frame
            frame.size = size
            window.setFrame(frame, display: true)
            actionLogger.log(.window, "Window resized", 
                           details: "Size: \(Int(size.width))x\(Int(size.height))")
        }
    }
    
    private func openNewWindow() {
        newWindowCount += 1
        let window = NSWindow(
            contentRect: NSRect(x: 100 + (newWindowCount * 30), 
                              y: 100 + (newWindowCount * 30), 
                              width: 400, 
                              height: 300),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Test Window \(newWindowCount)"
        window.contentView = NSHostingView(rootView: TestWindowContent(number: newWindowCount))
        window.makeKeyAndOrderFront(nil)
        
        actionLogger.log(.window, "New window opened", 
                       details: "Window #\(newWindowCount)")
    }
    
    private func openLogViewer() {
        if let url = URL(string: "peekaboo-playground://showWindow?id=log-viewer") {
            NSWorkspace.shared.open(url)
        }
        actionLogger.log(.window, "Log viewer window requested")
    }
    
    private func cascadeWindows() {
        var offset: CGFloat = 0
        for window in NSApp.windows where window.isVisible && !window.isMiniaturized {
            window.setFrameOrigin(CGPoint(x: 50 + offset, y: 50 + offset))
            offset += 30
        }
        actionLogger.log(.window, "Windows cascaded", 
                       details: "Count: \(NSApp.windows.filter { $0.isVisible }.count)")
    }
    
    private func tileWindows() {
        let visibleWindows = NSApp.windows.filter { $0.isVisible && !$0.isMiniaturized }
        guard !visibleWindows.isEmpty else { return }
        
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let columns = min(3, visibleWindows.count)
        let rows = (visibleWindows.count + columns - 1) / columns
        let width = screenFrame.width / CGFloat(columns)
        let height = screenFrame.height / CGFloat(rows)
        
        for (index, window) in visibleWindows.enumerated() {
            let col = index % columns
            let row = index / columns
            let frame = NSRect(
                x: screenFrame.origin.x + CGFloat(col) * width,
                y: screenFrame.origin.y + screenFrame.height - CGFloat(row + 1) * height,
                width: width,
                height: height
            )
            window.setFrame(frame, display: true)
        }
        
        actionLogger.log(.window, "Windows tiled", 
                       details: "Grid: \(columns)x\(rows)")
    }
    
    private func closeOtherWindows() {
        let mainWindow = NSApp.mainWindow
        var closedCount = 0
        for window in NSApp.windows {
            if window != mainWindow && window.isVisible && window.title.starts(with: "Test Window") {
                window.close()
                closedCount += 1
            }
        }
        if closedCount > 0 {
            newWindowCount = 0
            actionLogger.log(.window, "Other windows closed", 
                           details: "Closed: \(closedCount)")
        }
    }
}

struct TestWindowContent: View {
    let number: Int
    
    var body: some View {
        VStack {
            Text("Test Window \(number)")
                .font(.title)
            Text("This is a test window for Peekaboo automation")
                .foregroundColor(.secondary)
            Spacer()
            Button("Log Action") {
                ActionLogger.shared.log(.window, "Button clicked in Test Window \(number)")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}