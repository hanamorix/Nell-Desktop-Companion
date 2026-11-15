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

@Test func holdEndedByTheWatchdogGoesBackToTheBar() {
    // NellModel.tick's order. No hook event comes after an Esc in kitty, and the prompt may still be open: nothing is sent.
    var t = started(), q = InputQueue()
    t.handle(ev("PreToolUse", tool: "Bash", input: bash, id: "u1"), requestId: nil, now: at(1))
    t.handle(ev("PermissionRequest", tool: "Bash", input: bash), requestId: "r1", now: at(1))
    t.settleApproval("r1", answer: .none, now: at(591))
    #expect(q.submit("follow-up", held: t.inputHeld) == nil)
    let early = t.tick(now: at(592)), ended = t.tick(now: at(591 + Timings.typingWatchdog))
    let again = t.tick(now: at(591 + Timings.typingWatchdog + 1))
    #expect(!early); #expect(ended, "the watchdog ended the hold"); #expect(!again, "reported once")
    let back = q.release(held: false)
    #expect(mergedDraft(returned: back, typed: "and also") == "follow-up\nand also", "for the bar, not kitty")
    #expect(q.count == 0)
}

@Test func returnedTextKeepsWhatYouAreTyping() {
    #expect(mergedDraft(returned: ["one", "two"], typed: "") == "one\ntwo")
    #expect(mergedDraft(returned: [], typed: "typing") == "typing")
}

@Test func watchdogReportsTheHoldEvenWhileAnotherApprovalWaits() {
    var t = started()
    let other: [String: JSONValue] = ["command": .string("pwd")]
    t.handle(ev("PreToolUse", tool: "Bash", input: bash, id: "u1"), requestId: nil, now: at(1))
    t.handle(ev("PreToolUse", tool: "Bash", input: other, id: "u2"), requestId: nil, now: at(1))
    t.handle(ev("PermissionRequest", tool: "Bash", input: bash), requestId: "r1", now: at(1))
    t.handle(ev("PermissionRequest", tool: "Bash", input: other), requestId: "r2", now: at(1))
    t.settleApproval("r1", answer: .none, now: at(591))
    // the model takes the queue now: a later Allow on r2 would otherwise flush it into the prompt the watchdog gave up on
    let ended = t.tick(now: at(591 + Timings.typingWatchdog))
    #expect(ended); #expect(t.inputHeld, "r2 still holds the bar")
}

@Test func emptyOrWhitespaceIgnored() {
    var q = InputQueue()
    #expect(q.submit("  \n ", held: false) == nil)
    #expect(q.submit("", held: true) == nil)
    #expect(q.count == 0)
    #expect(q.submit(" keep my spaces ", held: false) == " keep my spaces ")
}
