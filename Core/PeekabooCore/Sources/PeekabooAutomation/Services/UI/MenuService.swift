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
}
