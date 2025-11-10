import Foundation
import PeekabooCore

final class PeekabooVisualizerBridgeService: NSObject, NSXPCListenerDelegate {
    private let broker = VisualizerEndpointBroker()

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: VisualizerEndpointBrokerProtocol.self)
        newConnection.exportedObject = self.broker
        newConnection.resume()
        return true
    }
}

let serviceDelegate = PeekabooVisualizerBridgeService()
let listener: NSXPCListener
if ProcessInfo.processInfo.environment["PEEKABOO_BRIDGE_STANDALONE"] == "1" {
    listener = NSXPCListener(machServiceName: VisualizerEndpointBrokerServiceName)
} else {
    listener = NSXPCListener.service()
}
listener.delegate = serviceDelegate
listener.resume()
RunLoop.current.run()
