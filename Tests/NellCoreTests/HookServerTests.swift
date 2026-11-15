import Foundation
import Testing
@testable import NellCore

final class Box<T>: @unchecked Sendable { let lock = NSLock(); var items: [T] = []
    func add(_ x: T) { lock.lock(); items.append(x); lock.unlock() }
    var all: [T] { lock.lock(); defer { lock.unlock() }; return items } }

func tmpSocket() -> String {
    let dir = URL(fileURLWithPath: "/tmp").appending(path: "nt-\(UUID().uuidString.prefix(8))")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir.appending(path: "n.sock").path
}

func curl(_ sock: String, _ body: Data, mode: String = "code") -> Process {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
    p.arguments = ["-s", "-m", "10", "--unix-socket", sock, "--data-binary", "@-", "http://nell/hook?mode=\(mode)"]
    let inp = Pipe(); p.standardInput = inp; p.standardOutput = Pipe()
    try! p.run(); inp.fileHandleForWriting.write(body); try! inp.fileHandleForWriting.close()
    return p
}
func output(_ p: Process) -> String {
    p.waitUntilExit()
    return String(decoding: (p.standardOutput as! Pipe).fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
}
func waitFor(_ cond: () -> Bool) { for _ in 0..<100 where !cond() { usleep(50_000) } }
/// Stops the server and removes the test's `/tmp/nt-*` folder.
func stopAndClean(_ s: HookServer, _ sock: String) { s.stop(); try? FileManager.default.removeItem(atPath: (sock as NSString).deletingLastPathComponent) }

/// A bare client: what a non-curl process (or one that hangs up early) does on the socket.
func rawConnect(_ sock: String) -> Int32 {
    let c = tryConnect(sock)
    precondition(c >= 0, "connect \(errno)")
    return c
}
/// -1 if the connect is refused.
func tryConnect(_ sock: String) -> Int32 {
    let c = socket(AF_UNIX, SOCK_STREAM, 0)
    var one: Int32 = 1
    setsockopt(c, SOL_SOCKET, SO_NOSIGPIPE, &one, socklen_t(MemoryLayout<Int32>.size))
    var addr = sockaddr_un(); addr.sun_family = sa_family_t(AF_UNIX)
    withUnsafeMutableBytes(of: &addr.sun_path) { buf in for (i, b) in sock.utf8CString.enumerated() { buf[i] = UInt8(bitPattern: b) } }
    let r = withUnsafePointer(to: &addr) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(c, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) } }
    if r != 0 { close(c); return -1 }
    return c
}
func rawPost(_ path: String, _ body: Data) -> Data {
    var d = Data("POST \(path) HTTP/1.1\r\nHost: nell\r\nContent-Length: \(body.count)\r\n\r\n".utf8); d.append(body); return d
}
func send(_ c: Int32, _ d: Data) { _ = d.withUnsafeBytes { write(c, $0.baseAddress, d.count) } }
func readToEOF(_ c: Int32) -> Data {
    var out = Data(); var b = [UInt8](repeating: 0, count: 4096)
    while true { let n = read(c, &b, b.count); if n <= 0 { return out }; out.append(contentsOf: b[0..<n]) }
}

@Test func serverDeliversEventAndRepliesEmpty() throws {
    let sock = tmpSocket(); let events = Box<(Mode, String)>()
    let s = HookServer(socketPath: sock, registry: ApprovalRegistry(), onEvent: { m, e, _ in events.add((m, e.name)) }, onRequestSettled: { _, _, _ in })
    try s.start(); defer { stopAndClean(s, sock) }
    #expect(output(curl(sock, try fixture("Stop"), mode: "chat")) == "")
    waitFor { !events.all.isEmpty }
    #expect(events.all.first?.0 == .chat); #expect(events.all.first?.1 == "Stop")
}

@Test func permissionBlocksUntilAnswered() throws {
    let sock = tmpSocket(); let reg = ApprovalRegistry(); let ids = Box<String>(); let settled = Box<ApprovalAnswer>()
    let s = HookServer(socketPath: sock, registry: reg, onEvent: { _, _, id in if let id { ids.add(id) } }, onRequestSettled: { _, _, a in settled.add(a) })
    try s.start(); defer { stopAndClean(s, sock) }
    let p = curl(sock, try fixture("PermissionRequest-Bash"))
    waitFor { !ids.all.isEmpty }
    usleep(2_500_000); #expect(p.isRunning) // past the 2 s receive timeout, which only bounds reading the request
    _ = reg.answer(id: ids.all[0], .allow)
    #expect(output(p) == String(decoding: approvalResponseBody(.allow), as: UTF8.self))
    waitFor { !settled.all.isEmpty }; #expect(settled.all == [.allow])
}

@Test func peerKilledMidWaitReportsNone() throws {
    let sock = tmpSocket(); let reg = ApprovalRegistry(); let ids = Box<String>(); let settled = Box<ApprovalAnswer>()
    let s = HookServer(socketPath: sock, registry: reg, onEvent: { _, _, id in if let id { ids.add(id) } }, onRequestSettled: { _, _, a in settled.add(a) })
    try s.start(); defer { stopAndClean(s, sock) }
    let p = curl(sock, try fixture("PermissionRequest-Bash"))
    waitFor { !ids.all.isEmpty }
    p.terminate()
    waitFor { !settled.all.isEmpty }
    #expect(settled.all == [.none]); #expect(!reg.answer(id: ids.all[0], .allow))
}

@Test func rebindsOverStaleSocketFile() throws {
    let sock = tmpSocket()
    FileManager.default.createFile(atPath: sock, contents: Data("stale".utf8))
    let s = HookServer(socketPath: sock, registry: ApprovalRegistry(), onEvent: { _, _, _ in }, onRequestSettled: { _, _, _ in })
    try s.start(); defer { stopAndClean(s, sock) }
    #expect(output(curl(sock, try fixture("Stop"))) == "")
    let perms = try FileManager.default.attributesOfItem(atPath: sock)[.posixPermissions] as? Int
    #expect(perms == 0o600)
}

@Test func hookScriptDeliversHugeBodyQuickly() throws {
    // curl sends `Expect: 100-continue` for big bodies and waits 1 s — longer than the script's 0.5 s budget.
    let sock = tmpSocket(); let events = Box<String>()
    let s = HookServer(socketPath: sock, registry: ApprovalRegistry(), onEvent: { _, e, _ in events.add(e.name) }, onRequestSettled: { _, _, _ in })
    try s.start(); defer { stopAndClean(s, sock) }
    let big = #"{"hook_event_name":"PreToolUse","session_id":"S","tool_name":"Write","tool_input":{"file_path":"/x/a.txt","content":""# + String(repeating: "x", count: 1_500_000) + #""}}"#
    let script = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appending(path: "../../Sources/Nell/Resources/nell-hook.sh").path
    let p = Process(); p.executableURL = URL(fileURLWithPath: "/bin/bash"); p.arguments = [script, "code", sock, "PreToolUse"]
    let inp = Pipe(); p.standardInput = inp; p.standardOutput = Pipe()
    try p.run(); inp.fileHandleForWriting.write(Data(big.utf8)); try inp.fileHandleForWriting.close()
    p.waitUntilExit()
    waitFor { !events.all.isEmpty }
    #expect(events.all == ["PreToolUse"])
}

private func postStatus(_ sock: String, _ body: Data) -> String {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
    p.arguments = ["-s", "-m", "10", "--unix-socket", sock, "--data-binary", "@-", "http://nell/status"]
    let inp = Pipe(); p.standardInput = inp; p.standardOutput = Pipe()
    try! p.run(); inp.fileHandleForWriting.write(body); try! inp.fileHandleForWriting.close()
    return output(p)
}

@Test func statusRouteRepliesWithLineAndReportsReading() throws {
    let sock = tmpSocket(); let events = Box<String>(); let readings = Box<UsageReading>()
    let s = HookServer(socketPath: sock, registry: ApprovalRegistry(), onEvent: { _, e, _ in events.add(e.name) },
                       onRequestSettled: { _, _, _ in }, onStatus: { readings.add($0) })
    try s.start(); defer { stopAndClean(s, sock) }
    let body = try fixture("statusline")
    let expected = try #require(UsageReading.decode(body))
    #expect(postStatus(sock, body) == statusLineText(expected))
    waitFor { !readings.all.isEmpty }
    #expect(readings.all == [expected]); #expect(events.all.isEmpty)
}

@Test func statusRouteWithoutLimitsRepliesEmpty() throws {
    let sock = tmpSocket(); let readings = Box<UsageReading>()
    let s = HookServer(socketPath: sock, registry: ApprovalRegistry(), onEvent: { _, _, _ in },
                       onRequestSettled: { _, _, _ in }, onStatus: { readings.add($0) })
    try s.start(); defer { stopAndClean(s, sock) }
    #expect(postStatus(sock, Data(#"{"model":{}}"#.utf8)) == "")
    usleep(200_000); #expect(readings.all.isEmpty)
}

@Test func clientHangingUpBeforeReplyLeavesServerAlive() throws {
    signal(SIGPIPE, SIG_DFL) // like the app: nothing ignores SIGPIPE
    let sock = tmpSocket()
    let s = HookServer(socketPath: sock, registry: ApprovalRegistry(), onEvent: { _, _, _ in }, onRequestSettled: { _, _, _ in })
    try s.start(); defer { stopAndClean(s, sock) }
    let stop = try fixture("Stop")
    for _ in 0..<20 { let c = rawConnect(sock); send(c, rawPost("/hook?mode=code", stop)); close(c) }
    let p = curl(sock, stop)
    #expect(output(p) == ""); #expect(p.terminationStatus == 0)
}

@Test func deeplyNestedBodiesDoNotCrashServer() throws {
    let sock = tmpSocket(); let events = Box<String>()
    let s = HookServer(socketPath: sock, registry: ApprovalRegistry(), onEvent: { _, e, _ in events.add(e.name) }, onRequestSettled: { _, _, _ in })
    try s.start(); defer { stopAndClean(s, sock) }
    let n = 509 // plus the outer object: 510 levels, inside Foundation's limit, so both parsers really recurse
    let deep = String(repeating: #"{"a":"#, count: n) + "1" + String(repeating: "}", count: n)
    let hook = #"{"hook_event_name":"PreToolUse","session_id":"S","tool_name":"Bash","tool_input":"# + deep + "}"
    _ = output(curl(sock, Data(hook.utf8)))
    _ = postStatus(sock, Data((#"{"rate_limits":"# + deep + "}").utf8))
    _ = output(curl(sock, try fixture("Stop")))
    waitFor { events.all.count == 2 }
    #expect(events.all == ["PreToolUse", "Stop"])
}

@Test func idleConnectionIsClosedAfterReceiveTimeout() throws {
    let sock = tmpSocket()
    let s = HookServer(socketPath: sock, registry: ApprovalRegistry(), onEvent: { _, _, _ in }, onRequestSettled: { _, _, _ in })
    try s.start(); defer { stopAndClean(s, sock) }
    let c = rawConnect(sock); defer { close(c) }
    var tv = timeval(tv_sec: 6, tv_usec: 0)
    setsockopt(c, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
    let start = Date(); var b: UInt8 = 0
    let n = recv(c, &b, 1, 0)
    #expect(n == 0); #expect(Date().timeIntervalSince(start) < 4)
}

@Test func tricklingClientIsClosedWithinRequestDeadline() throws {
    let sock = tmpSocket(); let events = Box<String>()
    let s = HookServer(socketPath: sock, registry: ApprovalRegistry(), onEvent: { _, e, _ in events.add(e.name) }, onRequestSettled: { _, _, _ in })
    try s.start(); defer { stopAndClean(s, sock) }
    let c = rawConnect(sock); defer { close(c) }
    let start = Date(); var closedAfter: TimeInterval?
    for _ in 0..<16 { // one byte every 0.5 s: each read finishes well inside the 2 s receive timeout
        if (Data("a".utf8).withUnsafeBytes { write(c, $0.baseAddress, 1) }) < 0 { closedAfter = Date().timeIntervalSince(start); break }
        usleep(500_000)
    }
    #expect(closedAfter != nil, "still open after 8 s"); #expect((closedAfter ?? 99) < 5)
    _ = output(curl(sock, try fixture("Stop")))
    waitFor { !events.all.isEmpty }
    #expect(events.all == ["Stop"])
}

@Test func burstOfConnectsIsNotRefused() throws {
    let sock = tmpSocket()
    let s = HookServer(socketPath: sock, registry: ApprovalRegistry(), onEvent: { _, _, _ in }, onRequestSettled: { _, _, _ in })
    try s.start(); defer { stopAndClean(s, sock) }
    let stop = rawPost("/hook?mode=code", try fixture("Stop"))
    let refused = Box<Int>()
    DispatchQueue.concurrentPerform(iterations: 100) { _ in // hooks from several sessions, all at once
        let c = tryConnect(sock); if c < 0 { refused.add(1) } else { send(c, stop); close(c) }
    }
    #expect(refused.all.count == 0) // a refusal reads as "Nell is down" to the hook script, and as "stale" to a second start()
}

@Test func secondStartThrowsWhileFirstHoldsTheLock() throws {
    // even when the live socket can't be reached (here: its file is gone), only the lock holder may bind the path
    let sock = tmpSocket()
    let s = HookServer(socketPath: sock, registry: ApprovalRegistry(), onEvent: { _, _, _ in }, onRequestSettled: { _, _, _ in })
    try s.start(); defer { stopAndClean(s, sock) }
    unlink(sock)
    let second = HookServer(socketPath: sock, registry: ApprovalRegistry(), onEvent: { _, _, _ in }, onRequestSettled: { _, _, _ in })
    #expect(throws: HookServerError.alreadyRunning) { try second.start() }
    second.stop()
}

@Test func strayByteThenHangupSettlesAsNone() throws {
    // a byte after the request must be consumed, or the watcher spins on it and never sees the hang-up
    let sock = tmpSocket(); let ids = Box<String>(); let settled = Box<ApprovalAnswer>()
    let s = HookServer(socketPath: sock, registry: ApprovalRegistry(), onEvent: { _, _, id in if let id { ids.add(id) } },
                       onRequestSettled: { _, _, a in settled.add(a) })
    try s.start(); defer { stopAndClean(s, sock) }
    let c = rawConnect(sock)
    send(c, rawPost("/hook?mode=code", try fixture("PermissionRequest-Bash")))
    waitFor { !ids.all.isEmpty }
    send(c, Data("x".utf8)); usleep(300_000); close(c)
    waitFor { !settled.all.isEmpty }
    #expect(settled.all == [.none])
}

@Test func failedReplySettlesAsNone() throws {
    // Allow clicked as the hook dies: Claude never got it, so the app must offer the console, not say "Allowed"
    // the peer is a child process, reaped before the click: nothing else can hold its socket open
    let sock = tmpSocket(); let reg = ApprovalRegistry(); let settled = Box<ApprovalAnswer>(); let client = Box<Process>()
    let s = HookServer(socketPath: sock, registry: reg, onEvent: { _, _, id in
        guard let id else { return }
        waitFor { !client.all.isEmpty }
        client.all[0].terminate(); client.all[0].waitUntilExit()
        reg.answer(id: id, .allow) // before the watcher starts, so only the reply can find the hook gone
    }, onRequestSettled: { _, _, a in settled.add(a) })
    try s.start(); defer { stopAndClean(s, sock) }
    client.add(curl(sock, try fixture("PermissionRequest-Bash")))
    waitFor { !settled.all.isEmpty }
    #expect(settled.all == [.none])
}

@Test func secondStartOnLivePathThrowsAndKeepsSocket() throws {
    let sock = tmpSocket(); let events = Box<String>()
    let s = HookServer(socketPath: sock, registry: ApprovalRegistry(), onEvent: { _, e, _ in events.add(e.name) }, onRequestSettled: { _, _, _ in })
    try s.start(); defer { stopAndClean(s, sock) }
    let second = HookServer(socketPath: sock, registry: ApprovalRegistry(), onEvent: { _, _, _ in }, onRequestSettled: { _, _, _ in })
    #expect(throws: HookServerError.alreadyRunning) { try second.start() }
    second.stop()
    _ = output(curl(sock, try fixture("Stop")))
    waitFor { !events.all.isEmpty }
    #expect(events.all == ["Stop"])
}

@Test func unknownOrMissingModeIsIgnored() throws {
    let sock = tmpSocket(); let events = Box<String>()
    let s = HookServer(socketPath: sock, registry: ApprovalRegistry(), onEvent: { _, e, _ in events.add(e.name) }, onRequestSettled: { _, _, _ in })
    try s.start(); defer { stopAndClean(s, sock) }
    let stop = try fixture("Stop")
    #expect(output(curl(sock, stop, mode: "bogus")) == "")
    #expect(output(curl(sock, stop, mode: "")) == "")
    let c = rawConnect(sock); send(c, rawPost("/hook", stop))
    #expect(String(decoding: readToEOF(c), as: UTF8.self).hasPrefix("HTTP/1.1 200 OK\r\nContent-Length: 0\r\n")); close(c)
    usleep(200_000); #expect(events.all.isEmpty)
}

@Test func bodyOver4MBIsDropped() throws {
    let sock = tmpSocket(); let events = Box<String>()
    let s = HookServer(socketPath: sock, registry: ApprovalRegistry(), onEvent: { _, e, _ in events.add(e.name) }, onRequestSettled: { _, _, _ in })
    try s.start(); defer { stopAndClean(s, sock) }
    let big = #"{"hook_event_name":"PreToolUse","session_id":"S","tool_name":"Write","tool_input":{"content":""# + String(repeating: "x", count: 5_000_000) + #""}}"#
    _ = output(curl(sock, Data(big.utf8)))
    _ = output(curl(sock, try fixture("Stop")))
    waitFor { !events.all.isEmpty }
    #expect(events.all == ["Stop"])
}
