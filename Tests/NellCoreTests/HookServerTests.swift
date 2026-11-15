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

@Test func serverDeliversEventAndRepliesEmpty() throws {
    let sock = tmpSocket(); let events = Box<(Mode, String)>()
    let s = HookServer(socketPath: sock, registry: ApprovalRegistry(), onEvent: { m, e, _ in events.add((m, e.name)) }, onRequestSettled: { _, _, _ in })
    try s.start(); defer { s.stop() }
    #expect(output(curl(sock, try fixture("Stop"), mode: "chat")) == "")
    waitFor { !events.all.isEmpty }
    #expect(events.all.first?.0 == .chat); #expect(events.all.first?.1 == "Stop")
}

@Test func permissionBlocksUntilAnswered() throws {
    let sock = tmpSocket(); let reg = ApprovalRegistry(); let ids = Box<String>(); let settled = Box<ApprovalAnswer>()
    let s = HookServer(socketPath: sock, registry: reg, onEvent: { _, _, id in if let id { ids.add(id) } }, onRequestSettled: { _, _, a in settled.add(a) })
    try s.start(); defer { s.stop() }
    let p = curl(sock, try fixture("PermissionRequest-Bash"))
    waitFor { !ids.all.isEmpty }
    usleep(300_000); #expect(p.isRunning)
    _ = reg.answer(id: ids.all[0], .allow)
    #expect(output(p) == String(decoding: approvalResponseBody(.allow), as: UTF8.self))
    waitFor { !settled.all.isEmpty }; #expect(settled.all == [.allow])
}

@Test func peerKilledMidWaitReportsNone() throws {
    let sock = tmpSocket(); let reg = ApprovalRegistry(); let ids = Box<String>(); let settled = Box<ApprovalAnswer>()
    let s = HookServer(socketPath: sock, registry: reg, onEvent: { _, _, id in if let id { ids.add(id) } }, onRequestSettled: { _, _, a in settled.add(a) })
    try s.start(); defer { s.stop() }
    let p = curl(sock, try fixture("PermissionRequest-Bash"))
    waitFor { !ids.all.isEmpty }
    p.terminate()
    waitFor { !settled.all.isEmpty }
    #expect(settled.all == [.none]); #expect(reg.pendingIds.isEmpty)
}

@Test func rebindsOverStaleSocketFile() throws {
    let sock = tmpSocket()
    FileManager.default.createFile(atPath: sock, contents: Data("stale".utf8))
    let s = HookServer(socketPath: sock, registry: ApprovalRegistry(), onEvent: { _, _, _ in }, onRequestSettled: { _, _, _ in })
    try s.start(); defer { s.stop() }
    #expect(output(curl(sock, try fixture("Stop"))) == "")
    let perms = try FileManager.default.attributesOfItem(atPath: sock)[.posixPermissions] as? Int
    #expect(perms == 0o600)
}

@Test func hookScriptDeliversHugeBodyQuickly() throws {
    // curl sends `Expect: 100-continue` for big bodies and waits 1 s — longer than the script's 0.5 s budget.
    let sock = tmpSocket(); let events = Box<String>()
    let s = HookServer(socketPath: sock, registry: ApprovalRegistry(), onEvent: { _, e, _ in events.add(e.name) }, onRequestSettled: { _, _, _ in })
    try s.start(); defer { s.stop() }
    let big = #"{"hook_event_name":"PreToolUse","session_id":"S","tool_name":"Write","tool_input":{"file_path":"/x/a.txt","content":""# + String(repeating: "x", count: 1_500_000) + #""}}"#
    let script = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appending(path: "../../Sources/Nell/Resources/nell-hook.sh").path
    let p = Process(); p.executableURL = URL(fileURLWithPath: "/bin/bash"); p.arguments = [script, "code", sock]
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
    try s.start(); defer { s.stop() }
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
    try s.start(); defer { s.stop() }
    #expect(postStatus(sock, Data(#"{"model":{}}"#.utf8)) == "")
    usleep(200_000); #expect(readings.all.isEmpty)
}
