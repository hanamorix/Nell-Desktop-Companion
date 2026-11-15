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
