import Darwin
import Foundation
import OSLog
import Security

/// Lightweight UNIX-domain socket host for Peekaboo automation.
///
/// This is a single-request-per-connection protocol: clients write one JSON request then half-close,
/// the host replies with one JSON response and closes.
public final actor PeekabooBridgeHost {
    private nonisolated static let logger = Logger(subsystem: "boo.peekaboo.bridge", category: "host")

    private var listenFD: Int32 = -1
    private var acceptTask: Task<Void, Never>?

    private let socketPath: String
    private let maxMessageBytes: Int
    private let allowedTeamIDs: Set<String>
    private let requestTimeoutSec: TimeInterval
    private let server: PeekabooBridgeServer

    public init(
        socketPath: String = PeekabooBridgeConstants.peekabooSocketPath,
        server: PeekabooBridgeServer,
        maxMessageBytes: Int = 64 * 1024 * 1024,
        allowedTeamIDs: Set<String> = ["Y5PE65HELJ"],
        requestTimeoutSec: TimeInterval = 10)
    {
        self.socketPath = socketPath
        self.server = server
        self.maxMessageBytes = maxMessageBytes
        self.allowedTeamIDs = allowedTeamIDs
        self.requestTimeoutSec = requestTimeoutSec
    }

    public func start() {
        guard self.listenFD == -1 else { return }

        let path = self.socketPath
        let fm = FileManager.default

        let dir = (path as NSString).deletingLastPathComponent
        try? fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
        unlink(path)

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let capacity = MemoryLayout.size(ofValue: addr.sun_path)
        let copied = path.withCString { cstr -> Int in
            strlcpy(&addr.sun_path.0, cstr, capacity)
        }
        if copied >= capacity {
            close(fd)
            return
        }
        addr.sun_len = UInt8(MemoryLayout.size(ofValue: addr))
        let len = socklen_t(MemoryLayout.size(ofValue: addr))
        if bind(fd, withUnsafePointer(to: &addr) { UnsafePointer<sockaddr>(OpaquePointer($0)) }, len) != 0 {
            close(fd)
            return
        }

        chmod(path, S_IRUSR | S_IWUSR)
        if listen(fd, SOMAXCONN) != 0 {
            close(fd)
            return
        }

        self.listenFD = fd

        let server = self.server
        let allowedTeamIDs = self.allowedTeamIDs
        let maxMessageBytes = self.maxMessageBytes
        let requestTimeoutSec = self.requestTimeoutSec

        self.acceptTask = Task.detached(priority: .utility) {
            await Self.acceptLoop(
                listenFD: fd,
                server: server,
                allowedTeamIDs: allowedTeamIDs,
                maxMessageBytes: maxMessageBytes,
                requestTimeoutSec: requestTimeoutSec)
        }
    }

    public func stop() {
        self.acceptTask?.cancel()
        self.acceptTask = nil
        if self.listenFD != -1 {
            close(self.listenFD)
            self.listenFD = -1
        }
        unlink(self.socketPath)
    }

    private nonisolated static func acceptLoop(
        listenFD: Int32,
        server: PeekabooBridgeServer,
        allowedTeamIDs: Set<String>,
        maxMessageBytes: Int,
        requestTimeoutSec: TimeInterval) async
    {
        while !Task.isCancelled {
            var addr = sockaddr()
            var len = socklen_t(MemoryLayout<sockaddr>.size)
            let client = accept(listenFD, &addr, &len)
            if client < 0 {
                if errno == EINTR { continue }
                if errno == EBADF || errno == EINVAL { return }
                self.logger.error("accept failed: \(errno, privacy: .public)")
                try? await Task.sleep(nanoseconds: 50_000_000)
                continue
            }

            Self.disableSigPipe(fd: client)
            Task.detached(priority: .utility) {
                defer { close(client) }
                await Self.handleClient(
                    fd: client,
                    server: server,
                    allowedTeamIDs: allowedTeamIDs,
                    maxMessageBytes: maxMessageBytes,
                    requestTimeoutSec: requestTimeoutSec)
            }
        }
    }

    private nonisolated static func handleClient(
        fd: Int32,
        server: PeekabooBridgeServer,
        allowedTeamIDs: Set<String>,
        maxMessageBytes: Int,
        requestTimeoutSec: TimeInterval) async
    {
        guard let peer = self.peerInfoIfAllowed(fd: fd, allowedTeamIDs: allowedTeamIDs) else {
            return
        }

        do {
            let requestData = try self.readAll(
                fd: fd,
                maxBytes: maxMessageBytes,
                timeoutSec: requestTimeoutSec)

            let responseData = await server.decodeAndHandle(requestData, peer: peer)

            try self.writeAll(fd: fd, data: responseData)
        } catch {
            self.logger.error("bridge socket request failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private nonisolated static func disableSigPipe(fd: Int32) {
        var one: Int32 = 1
        _ = setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, socklen_t(MemoryLayout.size(ofValue: one)))
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

    private nonisolated static func peerInfoIfAllowed(fd: Int32, allowedTeamIDs: Set<String>) -> PeekabooBridgePeer? {
        var pid: pid_t = 0
        var pidSize = socklen_t(MemoryLayout<pid_t>.size)
        let r = getsockopt(fd, SOL_LOCAL, LOCAL_PEERPID, &pid, &pidSize)
        guard r == 0, pid > 0 else { return nil }

        let teamID = self.teamID(pid: pid)
        if let teamID, allowedTeamIDs.contains(teamID) {
            let bundleID = self.bundleIdentifier(pid: pid)
            let uid = self.uid(for: pid)
            return PeekabooBridgePeer(
                processIdentifier: pid,
                userIdentifier: uid,
                bundleIdentifier: bundleID,
                teamIdentifier: teamID)
        }

        #if DEBUG
        let env = ProcessInfo.processInfo.environment["PEEKABOO_ALLOW_UNSIGNED_SOCKET_CLIENTS"]
        if env == "1", let callerUID = self.uid(for: pid), callerUID == getuid() {
            self.logger.warning(
                "allowing unsigned bridge client pid=\(pid, privacy: .public) (debug override)")
            let bundleID = self.bundleIdentifier(pid: pid)
            return PeekabooBridgePeer(
                processIdentifier: pid,
                userIdentifier: callerUID,
                bundleIdentifier: bundleID,
                teamIdentifier: nil)
        }
        #endif

        if let callerUID = self.uid(for: pid) {
            self.logger.error("bridge client rejected pid=\(pid, privacy: .public) uid=\(callerUID, privacy: .public)")
        } else {
            self.logger.error("bridge client rejected pid=\(pid, privacy: .public) (uid unknown)")
        }
        return nil
    }

    private nonisolated static func uid(for pid: pid_t) -> uid_t? {
        var info = kinfo_proc()
        var size = MemoryLayout.size(ofValue: info)
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        let ok = mib.withUnsafeMutableBufferPointer { mibPtr -> Bool in
            sysctl(mibPtr.baseAddress, u_int(mibPtr.count), &info, &size, nil, 0) == 0
        }
        return ok ? info.kp_eproc.e_ucred.cr_uid : nil
    }

    private nonisolated static func bundleIdentifier(pid: pid_t) -> String? {
        let attrs: NSDictionary = [kSecGuestAttributePid: pid]
        var secCode: SecCode?
        guard SecCodeCopyGuestWithAttributes(nil, attrs, SecCSFlags(), &secCode) == errSecSuccess,
              let code = secCode
        else { return nil }

        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, SecCSFlags(), &staticCode) == errSecSuccess,
              let sCode = staticCode
        else { return nil }

        var infoCF: CFDictionary?
        let flags = SecCSFlags(rawValue: UInt32(kSecCSSigningInformation))
        guard SecCodeCopySigningInformation(sCode, flags, &infoCF) == errSecSuccess,
              let info = infoCF as? [String: Any]
        else { return nil }

        return info[kSecCodeInfoIdentifier as String] as? String
    }

    private nonisolated static func teamID(pid: pid_t) -> String? {
        let attrs: NSDictionary = [kSecGuestAttributePid: pid]
        var secCode: SecCode?
        guard SecCodeCopyGuestWithAttributes(nil, attrs, SecCSFlags(), &secCode) == errSecSuccess,
              let code = secCode
        else { return nil }

        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, SecCSFlags(), &staticCode) == errSecSuccess,
              let sCode = staticCode
        else { return nil }

        var infoCF: CFDictionary?
        // `kSecCodeInfoTeamIdentifier` is only included when requesting signing information.
        let flags = SecCSFlags(rawValue: UInt32(kSecCSSigningInformation))
        guard SecCodeCopySigningInformation(sCode, flags, &infoCF) == errSecSuccess,
              let info = infoCF as? [String: Any]
        else { return nil }

        if let teamID = info[kSecCodeInfoTeamIdentifier as String] as? String {
            return teamID
        }

        if let entitlements = info[kSecCodeInfoEntitlementsDict as String] as? [String: Any],
           let appIdentifier = entitlements["application-identifier"] as? String,
           let prefix = appIdentifier.split(separator: ".").first
        {
            return String(prefix)
        }

        return nil
    }
}
