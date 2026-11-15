import Testing
@testable import NellCore

@Test func submitWhileHeldQueues() {
    var q = InputQueue()
    #expect(q.submit("hello", held: true) == nil)
    #expect(q.count == 1)
}

@Test func releaseFlushesInOrder() {
    var q = InputQueue()
    _ = q.submit("one", held: true)
    #expect(q.submit("two", held: false) == nil) // keeps order behind queued text
    #expect(q.release(held: false) == ["one", "two"])
    #expect(q.count == 0)
    #expect(q.submit("three", held: false) == "three")
}

@Test func holdEndedByTheWatchdogReleasesQueuedText() {
    // NellModel.tick's order: tick the tracker, then release what the queue holds. No hook event comes after an Esc in kitty.
    var t = started(), q = InputQueue()
    t.handle(ev("PreToolUse", tool: "Bash", input: bash, id: "u1"), requestId: nil, now: at(1))
    t.handle(ev("PermissionRequest", tool: "Bash", input: bash), requestId: "r1", now: at(1))
    t.settleApproval("r1", answer: .none, now: at(591))
    #expect(q.submit("follow-up", held: t.inputHeld) == nil)
    t.tick(now: at(592)); #expect(q.release(held: t.inputHeld).isEmpty, "Claude's prompt may still be open")
    #expect(q.count == 1)
    t.tick(now: at(591 + Timings.typingWatchdog)); #expect(q.release(held: t.inputHeld) == ["follow-up"])
}

@Test func emptyOrWhitespaceIgnored() {
    var q = InputQueue()
    #expect(q.submit("  \n ", held: false) == nil)
    #expect(q.submit("", held: true) == nil)
    #expect(q.count == 0)
    #expect(q.submit(" keep my spaces ", held: false) == " keep my spaces ")
}
