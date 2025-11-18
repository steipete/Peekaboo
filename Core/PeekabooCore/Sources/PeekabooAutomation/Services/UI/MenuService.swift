//
//  MenuService.swift
//  PeekabooCore
//

import AppKit
import AXorcist
import CoreFoundation
import CoreGraphics
import Foundation
import os
import PeekabooFoundation
import PeekabooVisualizer

@MainActor
public final class MenuService: MenuServiceProtocol {
    let applicationService: any ApplicationServiceProtocol
    let logger: Logger

    // Visualizer client for visual feedback
    let visualizerClient: VisualizationClient

    // Traversal limits to avoid unbounded menu walks
    let traversalLimits: MenuTraversalLimits
    let partialMatchEnabled: Bool
    let cacheTTL: TimeInterval
    var menuCache: [String: (expiresAt: Date, structure: MenuStructure)] = [:]

    public init(
        applicationService: (any ApplicationServiceProtocol)? = nil,
        traversalPolicy: SearchPolicy = .balanced,
        logger: Logger = Logger(subsystem: "boo.peekaboo.core", category: "MenuService"),
        visualizerClient: VisualizationClient = VisualizationClient.shared,
        partialMatchEnabled: Bool = true,
        cacheTTL: TimeInterval = 2.0)
    {
        self.applicationService = applicationService ?? ApplicationService()
        self.traversalLimits = MenuTraversalLimits.from(policy: traversalPolicy)
        self.logger = logger
        self.visualizerClient = visualizerClient
        self.partialMatchEnabled = partialMatchEnabled
        self.cacheTTL = cacheTTL
        self.connectVisualizerIfNeeded()
    }

    private func connectVisualizerIfNeeded() {
        let isMacApp = Bundle.main.bundleIdentifier?.hasPrefix("boo.peekaboo.mac") == true
        if !isMacApp {
            self.logger.debug("Connecting to visualizer service (running as CLI/external tool)")
            self.visualizerClient.connect()
        } else {
            self.logger.debug("Skipping visualizer connection (running inside Mac app)")
        }
    }

    #if DEBUG
    func clearMenuCache() {
        menuCache.removeAll()
    }
    #endif

    // MARK: MenuServiceProtocol stubs — implemented in extensions
    public func listMenus(for appIdentifier: String) async throws -> MenuStructure {
        try await self.listMenusInternal(appIdentifier: appIdentifier)
    }

    public func listFrontmostMenus() async throws -> MenuStructure {
        try await self.listFrontmostMenusInternal()
    }

    public func clickMenuItem(app: String, itemPath: String) async throws {
        try await self.clickMenuItemInternal(app: app, itemPath: itemPath)
    }

    public func clickMenuItemByName(app: String, itemName: String) async throws {
        try await self.clickMenuItemByNameInternal(app: app, itemName: itemName)
    }

    public func clickMenuExtra(title: String) async throws {
        try await self.clickMenuExtraInternal(title: title)
    }

    public func listMenuExtras() async throws -> [MenuExtraInfo] {
        try await self.listMenuExtrasInternal()
    }

    public func listMenuBarItems() async throws -> [MenuBarItemInfo] {
        try await self.listMenuBarItemsInternal()
    }

    public func clickMenuBarItem(named name: String) async throws -> ClickResult {
        try await self.clickMenuBarItemNamedInternal(name: name)
    }

    public func clickMenuBarItem(at index: Int) async throws -> ClickResult {
        try await self.clickMenuBarItemIndexInternal(index: index)
    }
}
