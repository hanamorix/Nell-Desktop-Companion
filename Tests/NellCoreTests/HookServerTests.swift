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
