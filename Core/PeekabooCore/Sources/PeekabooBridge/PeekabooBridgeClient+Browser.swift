extension PeekabooBridgeClient {
    public func browserStatus(channel: String?) async throws -> PeekabooBridgeBrowserStatus {
        let response = try await self.send(.browserStatus(PeekabooBridgeBrowserChannelRequest(channel: channel)))
        switch response {
        case let .browserStatus(status):
            return status
        default:
            throw PeekabooBridgeErrorEnvelope(code: .invalidRequest, message: "Unexpected browser status response")
        }
    }

    public func browserConnect(channel: String?) async throws -> PeekabooBridgeBrowserStatus {
        let response = try await self.send(.browserConnect(PeekabooBridgeBrowserChannelRequest(channel: channel)))
        switch response {
        case let .browserStatus(status):
            return status
        default:
            throw PeekabooBridgeErrorEnvelope(code: .invalidRequest, message: "Unexpected browser connect response")
        }
    }

    public func browserDisconnect() async throws {
        try await self.sendExpectOK(.browserDisconnect)
    }

    public func browserExecute(_ request: PeekabooBridgeBrowserExecuteRequest) async throws
        -> PeekabooBridgeBrowserToolResponse
    {
        let response = try await self.send(.browserExecute(request))
        switch response {
        case let .browserToolResponse(result):
            return result
        default:
            throw PeekabooBridgeErrorEnvelope(code: .invalidRequest, message: "Unexpected browser tool response")
        }
    }
}
