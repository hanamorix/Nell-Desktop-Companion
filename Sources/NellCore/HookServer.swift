import Darwin
import Foundation

public enum HookServerError: Error, Equatable, CustomStringConvertible {
    case socket(String), alreadyRunning
    public var description: String {
        switch self {
        case .socket(let s): s
        case .alreadyRunning: "another Nell is already running"
        }
    }
}

/// HTTP over a Unix socket at a fixed path; one request per connection. PermissionRequest connections block for an answer.
public final class HookServer: @unchecked Sendable {
    public typealias OnEvent = @Sendable (Mode, HookEvent, _ requestId: String?) -> Void
    public typealias OnSettled = @Sendable (Mode, _ requestId: String, ApprovalAnswer) -> Void

    private let path: String
    private let registry: ApprovalRegistry
    private let onEvent: OnEvent
    private let onRequestSettled: OnSettled
    private let onStatus: @Sendable (UsageReading) -> Void
    private var fd: Int32 = -1
    private var lock: Int32 = -1 // flock'd `<socket>.lock`: whoever holds it owns the socket path
    private var source: DispatchSourceRead?

    public init(socketPath: String, registry: ApprovalRegistry, onEvent: @escaping OnEvent, onRequestSettled: @escaping OnSettled,
                onStatus: @escaping @Sendable (UsageReading) -> Void = { _ in }) {
        self.path = socketPath; self.registry = registry; self.onEvent = onEvent; self.onRequestSettled = onRequestSettled; self.onStatus = onStatus
    }

    public func start() throws {
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(path.utf8CString)
        guard bytes.count <= MemoryLayout.size(ofValue: addr.sun_path) else { throw HookServerError.socket("path too long") }
        withUnsafeMutableBytes(of: &addr.sun_path) { buf in for (i, b) in bytes.enumerated() { buf[i] = UInt8(bitPattern: b) } }
        func atPath(_ s: Int32, _ f: (Int32, UnsafePointer<sockaddr>?, socklen_t) -> Int32) -> Int32 {
            withUnsafePointer(to: &addr) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { f(s, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) } }
        }
        // Another Nell holds the lock while it runs (the kernel drops it if she crashes). Only the holder may unlink and bind.
        let l = open(path + ".lock", O_RDWR | O_CREAT | O_CLOEXEC, 0o600)
        guard l >= 0 else { throw HookServerError.socket("lock: \(errno)") }
        guard flock(l, LOCK_EX | LOCK_NB) == 0 else {
            let e = errno; close(l)
            throw e == EWOULDBLOCK ? HookServerError.alreadyRunning : HookServerError.socket("flock: \(e)")
        }
        lock = l
        var started = false
        defer { // a failed start gives the lock back (and leaves the path alone: it may be a live Nell's socket)
            if !started { if fd >= 0 { close(fd); fd = -1 }; close(l); lock = -1 }
        }
        // a Nell from before the lock still answers on the path: leave its socket alone. Anything else is stale, left by a crash.
        let probe = socket(AF_UNIX, SOCK_STREAM, 0)
        guard probe >= 0 else { throw HookServerError.socket("socket") }
        let live = atPath(probe, connect) == 0
        close(probe)
        if live { throw HookServerError.alreadyRunning }
        unlink(path)
        fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw HookServerError.socket("socket") }
        var one: Int32 = 1 // accepted sockets inherit it, even from a client that hung up before accept
        guard setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, socklen_t(MemoryLayout<Int32>.size)) == 0 else { throw HookServerError.socket("SO_NOSIGPIPE: \(errno)") }
        // a full queue refuses connects, which the hook script reads as "Nell is down": room for a burst from every session
        guard atPath(fd, bind) == 0, chmod(path, 0o600) == 0, listen(fd, SOMAXCONN) == 0 else { throw HookServerError.socket("bind/listen: \(errno)") }
        let src = DispatchSource.makeReadSource(fileDescriptor: fd, queue: DispatchQueue(label: "nell.accept"))
        src.setEventHandler { [weak self] in
            guard let self else { return }
            let c = accept(self.fd, nil, nil)
            guard c >= 0 else { return }
            // Foundation's JSON parsers recurse up to 512 levels; a 512 KB GCD worker stack overflows long before that
            let t = Thread { self.serve(c) }
            t.stackSize = 4 << 20
            t.start()
        }
        src.resume()
        source = src
        started = true
    }

    public func stop() {
        source?.cancel(); source = nil
        if fd >= 0 { close(fd); fd = -1 }
        if lock >= 0 { unlink(path); close(lock); lock = -1 } // only the lock holder owns the path
    }

    private func serve(_ c: Int32) {
        defer { close(c) }
        var tv = timeval(tv_sec: 2, tv_usec: 0) // bounds each read; the approval wait below uses poll, which ignores it
        setsockopt(c, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        guard let r = readRequest(c) else { return }
        if r.path == "/status" { // the status line, not a hook: reply with Claude's status-bar text
            guard let reading = UsageReading.decode(r.body) else { reply(c, Data()); return }
            onStatus(reading); reply(c, Data(statusLineText(reading).utf8)); return
        }
        guard let mode = Mode(rawValue: r.query["mode"] ?? ""), let e = try? HookEvent.decode(r.body) else {
            reply(c, Data()); return
        }
        guard e.name == "PermissionRequest" else { onEvent(mode, e, nil); reply(c, Data()); return }

        let id = UUID().uuidString
        registry.register(id: id)
        onEvent(mode, e, id)
        let watcher = DispatchQueue(label: "nell.peer")
        let answered = Flag()
        watcher.async { [registry] in // the hook script died or timed out → no decision
            var b: UInt8 = 0
            while !answered.value {
                var p = pollfd(fd: c, events: Int16(POLLIN), revents: 0)
                // consume stray bytes (a peek leaves them readable and spins); 0 or an error means the hook is gone
                if poll(&p, 1, 200) > 0, !answered.value, recv(c, &b, 1, 0) <= 0 { registry.closed(id: id); return }
            }
        }
        let a = registry.wait(id: id, timeout: TimeInterval(Timings.hookTimeout))
        answered.value = true
        let delivered = reply(c, approvalResponseBody(a))
        onRequestSettled(mode, id, delivered ? a : .none) // the hook was already gone: Claude never got the decision
        watcher.sync {} // done with `c` before it's closed and its number reused
    }

    /// The whole request must arrive within 2 s (at worst ~4 s: a read may block for its 2 s timeout), or a trickling client holds a thread and an fd.
    private func readRequest(_ c: Int32) -> HTTPRequest? {
        let deadline = DispatchTime.now() + 2
        var buf = Data(); var chunk = [UInt8](repeating: 0, count: 65_536)
        while true {
            let n = read(c, &chunk, chunk.count)
            guard n > 0, DispatchTime.now() < deadline else { return nil }
            buf.append(contentsOf: chunk[0..<n])
            switch parseHTTPRequest(buf) {
            case .complete(let r): return r
            case .invalid: return nil
            case .incomplete: if buf.count > 4_000_000 { return nil }
            }
        }
    }

    @discardableResult
    private func reply(_ c: Int32, _ body: Data) -> Bool {
        let d = httpResponse(body: body)
        return d.withUnsafeBytes { write(c, $0.baseAddress, d.count) } == d.count
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
