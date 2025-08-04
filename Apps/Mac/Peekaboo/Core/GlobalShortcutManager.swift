import Carbon
import Foundation
import os.log

/// Manages global keyboard shortcuts using Carbon HotKey API
///
/// This class provides a bridge between Carbon's RegisterEventHotKey API
/// and Swift closures, allowing for proper global shortcut handling.
@MainActor
final class GlobalShortcutManager: NSObject {
    static let shared = GlobalShortcutManager()
    
    private let logger = Logger(subsystem: "boo.peekaboo.app", category: "GlobalShortcuts")
    private var handlers: [UInt32: () -> Void] = [:]
    private var eventHandlerRef: EventHandlerRef?
    
    override init() {
        super.init()
        self.setupEventHandler()
    }
    
    deinit {
        if let eventHandlerRef = eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }
    
    func setHandler(for id: UInt32, handler: @escaping () -> Void) {
        self.handlers[id] = handler
        self.logger.info("Registered handler for shortcut ID: \(id)")
    }
    
    func clearAllHandlers() {
        self.handlers.removeAll()
        self.logger.info("Cleared all shortcut handlers")
    }
    
    private func setupEventHandler() {
        let eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        ]
        
        let eventHandlerCallback: EventHandlerProcPtr = { _, event, userData in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }
            
            let manager = Unmanaged<GlobalShortcutManager>.fromOpaque(userData).takeUnretainedValue()
            return manager.handleHotKeyEvent(event)
        }
        
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            eventHandlerCallback,
            1,
            eventTypes,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef)
        
        if status != noErr {
            self.logger.error("Failed to install global shortcut event handler: \(status)")
        } else {
            self.logger.info("Successfully installed global shortcut event handler")
        }
    }
    
    private func handleHotKeyEvent(_ event: EventRef?) -> OSStatus {
        guard let event = event else { return OSStatus(eventNotHandledErr) }
        
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            OSType(kEventParamDirectObject),
            OSType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID)
        
        if status != noErr {
            self.logger.error("Failed to get hot key ID from event: \(status)")
            return OSStatus(eventNotHandledErr)
        }
        
        self.logger.info("Hot key pressed: ID \(hotKeyID.id)")
        
        // Execute the handler on the main thread
        Task { @MainActor in
            if let handler = self.handlers[hotKeyID.id] {
                handler()
            } else {
                self.logger.warning("No handler found for hot key ID: \(hotKeyID.id)")
            }
        }
        
        return noErr
    }
}