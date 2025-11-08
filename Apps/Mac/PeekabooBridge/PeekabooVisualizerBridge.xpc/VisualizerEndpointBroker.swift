import Foundation
import os
import PeekabooCore

final class VisualizerEndpointBroker: NSObject, VisualizerEndpointBrokerProtocol {
    private let logger = Logger(subsystem: "boo.peekaboo.mac", category: "VisualizerEndpointBroker")
    private let stateQueue = DispatchQueue(label: "boo.peekaboo.visualizer.bridge")
    private var endpoint: NSXPCListenerEndpoint?

    func registerVisualizerEndpoint(_ endpoint: NSXPCListenerEndpoint, reply: @escaping (Bool) -> Void) {
        self.stateQueue.async {
            self.logger.debug("Broker received updated endpoint")
            self.endpoint = endpoint
            reply(true)
        }
    }

    func fetchVisualizerEndpoint(_ reply: @escaping (NSXPCListenerEndpoint?) -> Void) {
        self.stateQueue.async {
            reply(self.endpoint)
        }
    }
}
