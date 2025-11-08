//
//  VisualizerEndpointBrokerProtocol.swift
//  PeekabooCore
//

import Foundation

@objc public protocol VisualizerEndpointBrokerProtocol {
    func registerVisualizerEndpoint(_ endpoint: NSXPCListenerEndpoint, reply: @escaping (Bool) -> Void)
    func fetchVisualizerEndpoint(_ reply: @escaping (NSXPCListenerEndpoint?) -> Void)
}

public let VisualizerEndpointBrokerServiceName = "boo.peekaboo.visualizer.bridge"
