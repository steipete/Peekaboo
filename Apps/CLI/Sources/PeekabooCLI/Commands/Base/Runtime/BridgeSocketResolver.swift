enum BridgeSocketResolver {
    static func explicitBridgeSocket(
        options: CommandRuntimeOptions,
        environment: [String: String]
    ) -> String? {
        if let socket = options.bridgeSocketPath, !socket.isEmpty {
            return socket
        }
        if let socket = environment["PEEKABOO_BRIDGE_SOCKET"], !socket.isEmpty {
            return socket
        }
        return nil
    }
}
