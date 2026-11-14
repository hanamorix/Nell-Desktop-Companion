import Darwin
import Foundation

public enum HookServerError: Error { case socket(String) }

/// HTTP over a Unix socket at a fixed path; one request per connection. PermissionRequest connections block for an answer.
public final class HookServer: @unchecked Sendable {
    public typealias OnEvent = @Sendable (Mode, HookEvent, _ requestId: String?) -> Void
    public typealias OnSettled = @Sendable (Mode, _ requestId: String, ApprovalAnswer) -> Void

    private let path: String
    private let registry: ApprovalRegistry
    private let onEvent: OnEvent
    private let onRequestSettled: OnSettled
    private var fd: Int32 = -1
    private var source: DispatchSourceRead?

    public init(socketPath: String, registry: ApprovalRegistry, onEvent: @escaping OnEvent, onRequestSettled: @escaping OnSettled) {
        self.path = socketPath; self.registry = registry; self.onEvent = onEvent; self.onRequestSettled = onRequestSettled
    }

    public func start() throws {
        unlink(path) // a stale socket or file left by a crashed Nell
        fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw HookServerError.socket("socket") }
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(path.utf8CString)
        guard bytes.count <= MemoryLayout.size(ofValue: addr.sun_path) else { throw HookServerError.socket("path too long") }
        withUnsafeMutableBytes(of: &addr.sun_path) { buf in for (i, b) in bytes.enumerated() { buf[i] = UInt8(bitPattern: b) } }
        let ok = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard ok == 0, chmod(path, 0o600) == 0, listen(fd, 16) == 0 else { throw HookServerError.socket("bind/listen: \(errno)") }
        let src = DispatchSource.makeReadSource(fileDescriptor: fd, queue: DispatchQueue(label: "nell.accept"))
        src.setEventHandler { [weak self] in
            guard let self else { return }
            let c = accept(self.fd, nil, nil)
            if c >= 0 { DispatchQueue.global().async { self.serve(c) } }
        }
        src.resume()
        source = src
    }

    public func stop() {
        source?.cancel(); source = nil
        if fd >= 0 { close(fd); fd = -1 }
        unlink(path)
    }

    private func serve(_ c: Int32) {
        defer { close(c) }
        var one: Int32 = 1
        setsockopt(c, SOL_SOCKET, SO_NOSIGPIPE, &one, socklen_t(MemoryLayout<Int32>.size))
        var buf = Data(); var chunk = [UInt8](repeating: 0, count: 65_536)
        var request: HTTPRequest?
        while request == nil {
            let n = read(c, &chunk, chunk.count)
            guard n > 0 else { return }
            buf.append(contentsOf: chunk[0..<n])
            switch parseHTTPRequest(buf) {
            case .complete(let r): request = r
            case .invalid: return
            case .incomplete: if buf.count > 4_000_000 { return }
            }
        }
        guard let r = request, let mode = Mode(rawValue: r.query["mode"] ?? ""), let e = try? HookEvent.decode(r.body) else {
            reply(c, Data()); return
        }
        guard e.name == "PermissionRequest" else { onEvent(mode, e, nil); reply(c, Data()); return }

        let id = UUID().uuidString
        registry.register(id: id)
        onEvent(mode, e, id)
        let watcher = DispatchQueue(label: "nell.peer")
        let answered = Flag()
        watcher.async { [registry] in // the hook script died or timed out → no decision
            while true {
                if answered.value { return }
                var p = pollfd(fd: c, events: Int16(POLLIN), revents: 0)
                if poll(&p, 1, 200) > 0 {
                    var b: UInt8 = 0
                    if recv(c, &b, 1, MSG_PEEK) <= 0 { registry.closed(id: id); return }
                }
            }
        }
        let a = registry.wait(id: id, timeout: TimeInterval(Timings.hookTimeout))
        answered.value = true
        reply(c, approvalResponseBody(a))
        onRequestSettled(mode, id, a)
    }

    private func reply(_ c: Int32, _ body: Data) {
        let d = httpResponse(body: body)
        _ = d.withUnsafeBytes { write(c, $0.baseAddress, d.count) }
    }
}

final class Flag: @unchecked Sendable {
    private let lock = NSLock()
    private var v = false
    var value: Bool {
        get { lock.lock(); defer { lock.unlock() }; return v }
        set { lock.lock(); v = newValue; lock.unlock() }
    }
}
