import Foundation
import Testing
@testable import NellCore

/// runTool is called on the main thread while Nell holds `&model.state` open (inout). If it ran the run loop while
/// waiting, a SwiftUI layout pass could read model.state mid-access and Swift aborts with an exclusivity conflict
/// (the crash when switching between the Chat and Code chips), and timers or hook events could re-enter the model.
@Test func runToolWaitsWithoutRunningTheRunLoop() {
    var fired = false
    let t = Timer(timeInterval: 0.01, repeats: false) { _ in fired = true }
    RunLoop.current.add(t, forMode: .default)
    let r = runTool(["/bin/sleep", "0.3"])
    #expect(r.status == 0)
    #expect(!fired, "the timer fired while runTool was waiting, so runTool ran the run loop")
    t.invalidate()
}

@Test func runToolReturnsOutputAndStatus() {
    let ok = runTool(["/bin/sh", "-c", "printf hi; exit 3"])
    #expect(ok.status == 3)
    #expect(String(decoding: ok.out, as: UTF8.self) == "hi")
    let fed = runTool(["/bin/cat"], stdin: Data("echoed".utf8))
    #expect(String(decoding: fed.out, as: UTF8.self) == "echoed")
    #expect(runTool(["/nonexistent/tool"]).status == -1)
}

@Test func runToolTimeoutKillsAHungToolAndNeverWaitsForAHeldPipe() {
    var start = Date()
    let hung = runTool(["/bin/sleep", "10"], timeout: 0.3)
    #expect(hung.status == -2)
    #expect(Date().timeIntervalSince(start) < 2)
    // an rc file that leaves a background job holding stdout: the tool exited, so its output comes back at once
    start = Date()
    let held = runTool(["/bin/sh", "-c", "/bin/sleep 3 & echo hi"], timeout: 5)
    #expect(held.status == 0)
    #expect(String(decoding: held.out, as: UTF8.self) == "hi\n")
    #expect(Date().timeIntervalSince(start) < 2)
}

@Test func runToolPassesEnvironmentAndCanKeepStderr() {
    #expect(String(decoding: runTool(["/usr/bin/env"], environment: ["ONLY": "1"]).out, as: UTF8.self) == "ONLY=1\n")
    #expect(String(decoding: runTool(["/bin/sh", "-c", "echo err >&2"]).out, as: UTF8.self) == "")
    #expect(String(decoding: runTool(["/bin/sh", "-c", "echo err >&2"], stderr: true).out, as: UTF8.self) == "err\n")
}

@Test func runToolTimeoutEndsTheToolsChildrenToo() {
    // a login shell whose rc started a job that holds stdout: the timeout ends the whole process group
    let marker = "30.\(Int.random(in: 1000...9999))"
    let start = Date()
    let r = runTool(["/bin/sh", "-c", "/bin/sleep \(marker) & /bin/sleep 30"], timeout: 0.3)
    #expect(r.status == -2)
    #expect(Date().timeIntervalSince(start) < 2)
    usleep(200_000)
    #expect(runTool(["/usr/bin/pgrep", "-f", "sleep \(marker)"]).status != 0, "the background child was left running")
}

@Test func cancellationEndsTheRunningToolAndAnyStartedAfter() {
    let c = Cancellation()
    DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) { c.cancel() }
    let start = Date()
    #expect(runTool(["/bin/sh", "-c", "/bin/sleep 10 & /bin/sleep 10"], cancel: c).status != 0)
    #expect(Date().timeIntervalSince(start) < 2, "it waited for the tool instead of ending it")
    #expect(c.isCancelled)
    #expect(runTool(["/bin/sleep", "10"], cancel: c).status != 0) // pressed before it started
    #expect(Date().timeIntervalSince(start) < 3)
    #expect(runTool(["/bin/echo", "cleanup"]).status == 0, "a run without the cancellation still works")
}
