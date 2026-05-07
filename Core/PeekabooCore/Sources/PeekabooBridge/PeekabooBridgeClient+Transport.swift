import Darwin
import Foundation
import PeekabooFoundation

extension PeekabooBridgeClient {
    func send(
        _ request: PeekabooBridgeRequest,
        timeoutSec: TimeInterval? = nil) async throws -> PeekabooBridgeResponse
    {
        let payload = try self.encoder.encode(request)
        let op = request.operation
        let start = Date()
        self.logger.debug("Sending bridge request \(op.rawValue, privacy: .public)")

        let effectiveTimeoutSec = timeoutSec ?? self.requestTimeoutSec
        let (socketPath, maxResponseBytes, requestTimeoutSec) =
            (self.socketPath, self.maxResponseBytes, effectiveTimeoutSec)
        let responseData = try await Task.detached(priority: .userInitiated) {
            try Self.sendBlocking(
                socketPath: socketPath,
                requestData: payload,
                maxResponseBytes: maxResponseBytes,
                timeoutSec: requestTimeoutSec)
        }.value

        guard !responseData.isEmpty else {
            let details = """
            EOF while reading response for \(op.rawValue).

            This usually means the host closed the socket before replying \
            (often due to an authorization/TeamID check). \
            Update Peekaboo.app / ClawdBot.app to a host build that returns a structured \
            `unauthorizedClient` response, or launch the host with \
            PEEKABOO_ALLOW_UNSIGNED_SOCKET_CLIENTS=1 for local development.
            """

            throw PeekabooBridgeErrorEnvelope(
                code: .internalError,
                message: "Bridge host returned no response",
                details: details)
        }

        let response: PeekabooBridgeResponse
        do {
            response = try self.decoder.decode(PeekabooBridgeResponse.self, from: responseData)
        } catch {
            throw PeekabooBridgeErrorEnvelope(
                code: .decodingFailed,
                message: "Bridge host returned an invalid response",
                details: "\(error)")
        }
        let duration = Date().timeIntervalSince(start)
        self.logger.debug(
            "bridge \(op.rawValue, privacy: .public) completed in \(duration, format: .fixed(precision: 3))s")
        return response
    }

    func sendExpectOK(_ request: PeekabooBridgeRequest) async throws {
        let response = try await self.send(request)
        switch response {
        case .ok:
            return
        case let .error(envelope):
            throw envelope
        default:
            throw PeekabooBridgeErrorEnvelope(code: .invalidRequest, message: "Unexpected response for void request")
        }
    }

    private nonisolated static func disableSigPipe(fd: Int32) {
        var one: Int32 = 1
        _ = setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, socklen_t(MemoryLayout.size(ofValue: one)))
    }

    private nonisolated static func sendBlocking(
        socketPath: String,
        requestData: Data,
        maxResponseBytes: Int,
        timeoutSec: TimeInterval) throws -> Data
    {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        defer { close(fd) }

        Self.disableSigPipe(fd: fd)

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let capacity = MemoryLayout.size(ofValue: addr.sun_path)
        let copied = socketPath.withCString { cstr -> Int in
            strlcpy(&addr.sun_path.0, cstr, capacity)
        }
        guard copied < capacity else { throw POSIXError(.ENAMETOOLONG) }
        addr.sun_len = UInt8(MemoryLayout.size(ofValue: addr))

        let len = socklen_t(MemoryLayout.size(ofValue: addr))
        let connectResult = withUnsafePointer(to: &addr) { ptr in
            connect(fd, UnsafePointer<sockaddr>(OpaquePointer(ptr)), len)
        }
        guard connectResult == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .ECONNREFUSED) }

        try Self.writeAll(fd: fd, data: requestData)
        _ = shutdown(fd, SHUT_WR)

        return try Self.readAll(fd: fd, maxBytes: maxResponseBytes, timeoutSec: timeoutSec)
    }

    private nonisolated static func writeAll(fd: Int32, data: Data) throws {
        try data.withUnsafeBytes { buf in
            guard let base = buf.baseAddress else { return }
            var written = 0
            while written < data.count {
                let n = write(fd, base.advanced(by: written), data.count - written)
                if n > 0 {
                    written += n
                    continue
                }
                if n == -1, errno == EINTR { continue }
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            }
        }
    }

    private nonisolated static func readAll(fd: Int32, maxBytes: Int, timeoutSec: TimeInterval) throws -> Data {
        let deadline = Date().addingTimeInterval(timeoutSec)
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 16 * 1024)

        while true {
            let remaining = deadline.timeIntervalSinceNow
            if remaining <= 0 {
                throw POSIXError(.ETIMEDOUT)
            }

            var pfd = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
            let sliceMs = max(1.0, min(remaining, 0.25) * 1000.0)
            let polled = poll(&pfd, 1, Int32(sliceMs))
            if polled == 0 { continue }
            if polled < 0 {
                if errno == EINTR { continue }
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            }

            let n = buffer.withUnsafeMutableBytes { read(fd, $0.baseAddress!, $0.count) }
            if n > 0 {
                data.append(buffer, count: n)
                if data.count > maxBytes {
                    throw POSIXError(.EMSGSIZE)
                }
                continue
            }

            if n == 0 {
                return data
            }

            if errno == EINTR { continue }
            if errno == EAGAIN { continue }
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
    }
}
