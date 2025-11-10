//
//  VisualizerEndpointBrokerHost.swift
//  Peekaboo
//

import Foundation
import os
import PeekabooCore

@MainActor
final class VisualizerEndpointBrokerHost: NSObject {
    static let shared = VisualizerEndpointBrokerHost()

    private let logger = Logger(subsystem: "boo.peekaboo.mac", category: "VisualizerEndpointBrokerHost")
    private let stateQueue = DispatchQueue(label: "boo.peekaboo.visualizer.endpoint")
    private let listener = NSXPCListener(machServiceName: VisualizerEndpointBrokerServiceName)

    private var currentEndpoint: NSXPCListenerEndpoint?
    private var didStart = false

    private override init() {
        super.init()
        self.listener.delegate = self
    }

    func startIfNeeded() {
        guard !self.didStart else { return }
        self.listener.resume()
        self.didStart = true
        self.logger.info("Visualizer endpoint broker host started")
    }

    func publish(endpoint: NSXPCListenerEndpoint) {
        self.startIfNeeded()
        self.stateQueue.async {
            self.currentEndpoint = endpoint
        }
    }
}

extension VisualizerEndpointBrokerHost: VisualizerEndpointBrokerProtocol {
    func registerVisualizerEndpoint(_ endpoint: NSXPCListenerEndpoint, reply: @escaping (Bool) -> Void) {
        self.publish(endpoint: endpoint)
        reply(true)
    }

    func fetchVisualizerEndpoint(_ reply: @escaping (NSXPCListenerEndpoint?) -> Void) {
        self.stateQueue.async {
            reply(self.currentEndpoint)
        }
    }
}

extension VisualizerEndpointBrokerHost: NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: VisualizerEndpointBrokerProtocol.self)
        newConnection.exportedObject = self
        newConnection.resume()
        return true
    }
}
