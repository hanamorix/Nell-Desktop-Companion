import Foundation
import Testing
@testable import NellCore

// The final fix wave on review-fixes. The Sim and the rtf* cases come from the red team's proof tests.

/// Mirrors NellModel's routing (handle / requestSettled / tick / submit / dismissQuestion) with NellCore's real types.
private struct Sim {
    var t: [Mode: SessionTracker] = [.code: SessionTracker(), .chat: SessionTracker()]
    var q: [Mode: InputQueue] = [.code: InputQueue(), .chat: InputQueue()]
    var returned = ReturnedText()
    var bubbles = BubbleStore()
    var selected: Mode = .code
    var draft = ""
    var sent: [(Mode, String)] = []
    var releasedHooks: [(Mode, String)] = [] // registry.answer(id, .none) from handle → a later requestSettled(.none)

    mutating func start(_ m: Mode, now: Date) { handle(m, ev("SessionStart"), now: now); handle(m, ev("UserPromptSubmit"), now: now) }
    mutating func handle(_ m: Mode, _ e: HookEvent, rid: String? = nil, now: Date) {
        let settled = t[m]!.handle(e, requestId: rid, now: now)
        settleBubbles(after: e, mode: m, settled: settled, in: &bubbles)
        for id in settled { releasedHooks.append((m, id)) }
        if e.name == "PermissionRequest", let rid {
            if e.toolName == "AskUserQuestion" { releasedHooks.append((m, rid)); bubbles.add(.question, mode: m, text: "q", now: now) }
            else { bubbles.add(.approval(requestId: rid), mode: m, text: "a", now: now) }
        }
        flush(m)
    }
    mutating func settle(_ m: Mode, _ id: String, _ a: ApprovalAnswer, now: Date) {
        t[m]!.settleApproval(id, answer: a, now: now); bubbles.settle(requestId: id, as: "x"); flush(m)
    }
    mutating func tick(now: Date) { for m in Mode.allCases where t[m]!.tick(now: now) { giveBack(m) } }
    mutating func submit(_ text: String) { bubbles.add(.user, mode: selected, text: text, now: t0); enqueue(text, selected) }
    mutating func dismissQuestion(_ m: Mode) { t[m]!.dismissQuestion(); bubbles.settleQuestions(mode: m); giveBack(m) }
    mutating func select(_ m: Mode) { selected = m; draft = returned.draft(draft, selected: selected) }
    private mutating func giveBack(_ m: Mode) {
        let back = q[m]!.release(held: false); guard !back.isEmpty else { return }
        for x in back { bubbles.removeUser(mode: m, text: x) }
        returned.add(back, for: m); draft = returned.draft(draft, selected: selected)
    }
    private mutating func flush(_ m: Mode) { for x in q[m]!.release(held: t[m]!.inputHeld) { enqueue(x, m) } }
    private mutating func enqueue(_ x: String, _ m: Mode) { if let now = q[m]!.submit(x, held: t[m]!.inputHeld) { sent.append((m, now)) } }
}

private let rm: [String: JSONValue] = ["command": .string("rm -rf build")]
private func src(_ name: String, _ s: String) -> HookEvent { var e = ev(name); e.source = s; return e }

// MARK: item 4 — an approval binds to a tool call only when the match is unambiguous

// An identical earlier call still open (it needed no approval) must not take the approval of the later one.
@Test func rtfEarlierIdenticalCallFinishingLeavesTheApprovalPending() {
    var s = Sim(); s.start(.code, now: t0)
    s.handle(.code, ev("PreToolUse", tool: "Bash", input: rm, id: "u1"), now: at(1)) // auto-allowed, still running
    s.handle(.code, ev("PreToolUse", tool: "Bash", input: rm, id: "u2"), now: at(2))
    s.handle(.code, ev("PermissionRequest", tool: "Bash", input: rm), rid: "r2", now: at(2)) // this is u2's
    s.submit("typed while r2 pending")
    s.handle(.code, ev("PostToolUse", tool: "Bash", input: rm, id: "u1"), now: at(3)) // u1 finishes
    #expect(s.releasedHooks.isEmpty, "r2 was released by u1's Post")
    #expect(s.t[.code]!.pendingApprovals["r2"] != nil)
    #expect(s.sent.isEmpty, "sent \(s.sent)")
    s.settle(.code, "r2", .allow, now: at(4)) // its own hook: Allow in the bubble
    #expect(s.sent.map(\.1) == ["typed while r2 pending"])
}

// Both identical calls asked: neither Post settles either approval; a no-decision hand-off holds.
@Test func rtfParallelIdenticalBothPendingHoldUntilTheirHooks() {
    var s = Sim(); s.start(.code, now: t0)
    s.handle(.code, ev("PreToolUse", tool: "Bash", input: rm, id: "u1"), now: at(1))
    s.handle(.code, ev("PreToolUse", tool: "Bash", input: rm, id: "u2"), now: at(1))
    s.handle(.code, ev("PermissionRequest", tool: "Bash", input: rm), rid: "r1", now: at(1))
    s.handle(.code, ev("PermissionRequest", tool: "Bash", input: rm), rid: "r2", now: at(1))
    s.submit("queued")
    s.settle(.code, "r1", .allow, now: at(2))
    s.handle(.code, ev("PostToolUse", tool: "Bash", input: rm, id: "u1"), now: at(3))
    #expect(s.releasedHooks.isEmpty); #expect(s.sent.isEmpty)
    s.settle(.code, "r2", .none, now: at(4)) // the 590 s deadline or a dead hook: Claude asks in kitty
    #expect(s.sent.isEmpty, "a no-decision settle must leave a hold")
    s.handle(.code, ev("PostToolUse", tool: "Bash", input: rm, id: "u2"), now: at(5))
    #expect(s.sent.isEmpty, "the hold has no tool id, so a Post can't prove that prompt closed")
}

// The ordinary single call still settles on its own Post (answered in kitty).
@Test func rtfSingleCallSettlesOnItsPost() {
    var s = Sim(); s.start(.code, now: t0)
    s.handle(.code, ev("PreToolUse", tool: "Bash", input: rm, id: "u1"), now: at(1))
    s.handle(.code, ev("PermissionRequest", tool: "Bash", input: rm), rid: "r1", now: at(1))
    s.submit("after")
    s.handle(.code, ev("PostToolUse", tool: "Bash", input: rm, id: "u1"), now: at(2))
    #expect(s.releasedHooks.map(\.1) == ["r1"]); #expect(s.sent.map(\.1) == ["after"])
}

// MARK: item 8 — an approval after the turn ended still settles on its tool's Post

@Test func rtfApprovalAfterStopSettlesOnItsPost() {
    var s = Sim(); s.start(.code, now: t0)
    s.handle(.code, ev("Stop"), now: at(1))
    s.handle(.code, ev("PreToolUse", tool: "Bash", input: rm, id: "u9"), now: at(2)) // a background agent
    s.handle(.code, ev("PermissionRequest", tool: "Bash", input: rm), rid: "r9", now: at(2))
    #expect(s.t[.code]!.state == .needsYou)
    s.submit("x"); #expect(s.sent.isEmpty)
    s.handle(.code, ev("PostToolUse", tool: "Bash", input: rm, id: "u9"), now: at(10)) // answered in kitty
    #expect(s.releasedHooks.map(\.1) == ["r9"])
    #expect(s.sent.map(\.1) == ["x"])
    #expect(s.t[.code]!.state == .idle, "a late tool event doesn't restart her")
}

@Test func rtfApprovalAfterStopHoldsUntilItsPost() {
    var s = Sim(); s.start(.code, now: t0)
    s.handle(.code, ev("Stop"), now: at(1))
    s.handle(.code, ev("PreToolUse", tool: "Bash", input: rm, id: "u9"), now: at(2))
    s.handle(.code, ev("PermissionRequest", tool: "Bash", input: rm), rid: "r9", now: at(2))
    s.submit("x")
    s.settle(.code, "r9", .none, now: at(3)); #expect(s.sent.isEmpty) // Console: Claude's prompt is open in kitty
    s.handle(.code, ev("PostToolUse", tool: "Bash", input: rm, id: "u9"), now: at(10))
    #expect(s.sent.map(\.1) == ["x"])
}

// MARK: red-team cases that still hold as they were

@Test func rtfDeadlineHandOffHeldUntilItsOwnAgeAndSilence() {
    var s = Sim(); s.start(.code, now: t0)
    s.handle(.code, ev("PreToolUse", tool: "Bash", input: rm, id: "u1"), now: at(1))
    s.handle(.code, ev("PermissionRequest", tool: "Bash", input: rm), rid: "r1", now: at(1))
    s.submit("queued while pending")
    s.settle(.code, "r1", .none, now: at(591))
    for x in stride(from: 592.0, to: 770.0, by: 1) { s.tick(now: at(x)) }
    #expect(s.sent.isEmpty); #expect(s.draft.isEmpty)
    s.tick(now: at(771))
    #expect(s.sent.isEmpty)
    #expect(s.draft == "queued while pending")
    s.submit("next"); #expect(s.sent.map(\.1) == ["next"])
}

@Test func rtfConsoleThenPostFlushes() {
    var s = Sim(); s.start(.code, now: t0)
    s.handle(.code, ev("PreToolUse", tool: "Bash", input: rm, id: "u1"), now: at(1))
    s.handle(.code, ev("PermissionRequest", tool: "Bash", input: rm), rid: "r1", now: at(1))
    s.settle(.code, "r1", .none, now: at(5)); s.submit("after")
    s.handle(.code, ev("Notification", message: "Claude needs your permission", type: "permission_prompt"), now: at(6))
    #expect(s.t[.code]!.lastAlert == nil)
    #expect(s.sent.isEmpty)
    s.handle(.code, ev("PostToolUse", tool: "Bash", input: rm, id: "u1"), now: at(30))
    #expect(s.sent.map(\.1) == ["after"])
}

// 1 (i): Stop hands a still-pending approval to kitty with no decision; Claude's own prompt may be open, so it holds.
@Test func approvalPendingAtStopHoldsTheBar() {
    var s = Sim(); s.start(.code, now: t0)
    s.handle(.code, ev("PreToolUse", tool: "Bash", input: rm, id: "u8"), now: at(1))
    s.handle(.code, ev("PermissionRequest", tool: "Bash", input: rm), rid: "r8", now: at(1))
    s.handle(.code, ev("Stop"), now: at(2))
    #expect(s.releasedHooks.map(\.1) == ["r8"])
    s.settle(.code, "r8", .none, now: at(2))
    s.submit("typed")
    #expect(s.sent.isEmpty, "sent \(s.sent) while Claude's prompt may be open")
    s.tick(now: at(2 + Timings.typingWatchdog - 1)); #expect(s.draft.isEmpty)
    s.tick(now: at(2 + Timings.typingWatchdog))
    #expect(s.sent.isEmpty); #expect(s.draft == "typed", "the watchdog hands it back, never sends it")
}

// 1 (ii): Stop with a question's picker still open holds the bar too.
@Test func questionPendingAtStopHoldsTheBar() {
    var s = Sim(); s.start(.code, now: t0)
    s.handle(.code, ev("PreToolUse", tool: "AskUserQuestion", input: ask, id: "q1"), now: at(1))
    s.handle(.code, ev("PermissionRequest", tool: "AskUserQuestion", input: ask), rid: "rq", now: at(1))
    s.handle(.code, ev("Stop"), now: at(2))
    s.submit("typed")
    #expect(s.sent.isEmpty, "sent \(s.sent) into an open picker")
    s.handle(.code, ev("UserPromptSubmit"), now: at(9)) // you answered in kitty and Claude moved on
    #expect(s.sent.map(\.1) == ["typed"])
}

// 1: a turn end with nothing pending releases as before.
@Test func stopWithNothingPendingDoesNotHold() {
    for end in ["Stop", "StopFailure"] {
        var s = Sim(); s.start(.code, now: t0)
        s.handle(.code, ev("PreToolUse", tool: "Bash", input: rm, id: "u1"), now: at(1))
        s.handle(.code, ev("PostToolUse", tool: "Bash", input: rm, id: "u1"), now: at(2))
        s.handle(.code, ev(end), now: at(3))
        s.submit("goes straight out"); #expect(s.sent.count == 1, "\(end)")
    }
}

@Test func rtfResumeClearsQuestionAndHold() {
    var s = Sim(); s.start(.code, now: t0)
    s.handle(.code, ev("PreToolUse", tool: "AskUserQuestion", input: ask, id: "q1"), now: at(1))
    s.handle(.code, ev("PermissionRequest", tool: "AskUserQuestion", input: ask), rid: "rq", now: at(1))
    s.submit("held by question"); #expect(s.sent.isEmpty)
    s.t[.code]!.markLaunched(now: at(2))
    s.handle(.code, src("SessionStart", "resume"), now: at(4))
    #expect(s.t[.code]!.pendingQuestion == nil)
    #expect(s.sent.map(\.1) == ["held by question"])
    #expect(!s.bubbles.bubbles.contains { $0.pinned })
}

@Test func rtfDismissQuestionGivesBackNotSends() {
    var s = Sim(); s.start(.code, now: t0)
    s.handle(.code, ev("PreToolUse", tool: "AskUserQuestion", input: ask, id: "q1"), now: at(1))
    s.handle(.code, ev("PermissionRequest", tool: "AskUserQuestion", input: ask), rid: "rq", now: at(1))
    s.submit("a"); s.submit("b")
    s.dismissQuestion(.code)
    #expect(s.sent.isEmpty); #expect(s.draft == "a\nb")
    #expect(!s.bubbles.bubbles.contains { $0.kind == .user })
}

// MARK: item 6 — text handed back to a mode you're not on says where it is

@Test func rtfReturnedTextWaitsForItsModeAndShowsItIsWaiting() {
    var s = Sim(); s.start(.code, now: t0); s.start(.chat, now: t0)
    s.handle(.code, ev("PreToolUse", tool: "Bash", input: rm, id: "u1"), now: at(1))
    s.handle(.code, ev("PermissionRequest", tool: "Bash", input: rm), rid: "r1", now: at(1))
    s.submit("for code"); s.settle(.code, "r1", .none, now: at(2))
    s.select(.chat); s.draft = "typed for chat"
    s.tick(now: at(200))
    #expect(s.draft == "typed for chat")
    #expect(s.returned.isWaiting(for: .code), "Code's chip lights while its text waits")
    #expect(!s.returned.isWaiting(for: .chat))
    s.select(.code)
    #expect(s.draft == "for code\ntyped for chat")
    #expect(!s.returned.isWaiting(for: .code))
}

// MARK: item 3 — a project folder you can't enter isn't usable

@Test func usableProjectDirMustBeEnterable() throws {
    let dir = URL(fileURLWithPath: "/tmp").appending(path: "nt-proj-\(UUID().uuidString.prefix(8))")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { chmod(dir.path, 0o755); try? FileManager.default.removeItem(at: dir) }
    var s = SavedState(); s.projectDir = dir.path
    #expect(s.usableProjectDir == dir.path)
    #expect(chmod(dir.path, 0) == 0)
    #expect(s.usableProjectDir == nil, "chmod 000: Process.run can't chdir there")
}

// MARK: item 11 — an empty message is no message

@Test func stopFailureWithEmptyMessageNamesTheError() {
    var e = ev("StopFailure"); e.lastAssistantMessage = ""; e.error = "server_error"
    #expect(stopFailureMessage(e) == "server_error")
    e.error = nil
    #expect(stopFailureMessage(e) == "Something went wrong")
}

// MARK: item 13 — a failed start never keeps the lock

@Test func failedStartAfterTheLockLeavesItFree() throws {
    let sock = tmpSocket(); defer { try? FileManager.default.removeItem(atPath: (sock as NSString).deletingLastPathComponent) }
    try FileManager.default.createDirectory(atPath: sock, withIntermediateDirectories: true) // bind can't replace a folder
    let s = HookServer(socketPath: sock, registry: ApprovalRegistry(), onEvent: { _, _, _ in }, onRequestSettled: { _, _, _ in })
    #expect(throws: HookServerError.self) { try s.start() }
    try FileManager.default.removeItem(atPath: sock)
    let next = HookServer(socketPath: sock, registry: ApprovalRegistry(), onEvent: { _, _, _ in }, onRequestSettled: { _, _, _ in })
    try next.start(); next.stop()
}

// MARK: item 15 — a window whose reset has passed gives way to any newer reading

@Test func usageMergeReplacesAWindowWhoseResetPassed() {
    let reset = t0.addingTimeInterval(-60)
    let old = UsageReading(session: UsageWindow(used: 95, resetsAt: reset), weekly: UsageWindow(used: 50, resetsAt: reset))
    let after = UsageReading(session: UsageWindow(used: 3, resetsAt: reset), weekly: UsageWindow(used: 1, resetsAt: t0.addingTimeInterval(-120)))
    #expect(old.merged(after, now: t0) == after, "same or earlier stamp, but the old window is over")
    let live = UsageReading(session: UsageWindow(used: 95, resetsAt: t0.addingTimeInterval(60)))
    #expect(live.merged(UsageReading(session: UsageWindow(used: 3, resetsAt: reset)), now: t0) == live, "a stale post still loses")
}

// MARK: item 17 — a row the layout parked doesn't fade unseen

@Test func parkedRowKeepsItsCountdownUntilShown() {
    var b = BubbleStore()
    b.add(.reply, mode: .chat, text: "reply", now: t0)
    b.tick(now: t0, userIdle: 0, hovered: nil) // countdown starts
    let id = b.bubbles[0].id
    b.add(.approval(requestId: "r"), mode: .chat, text: "a", now: t0)
    let approval = b.bubbles[1].id
    for s in stride(from: 1.0, through: 200, by: 1) { b.tick(now: at(s), userIdle: 0, hovered: nil, onScreen: [approval]) }
    #expect(b.bubbles.contains { $0.id == id }, "parked behind the approval, it never got its 60 s on screen")
    b.settle(requestId: "r", as: "Allowed")
    b.tick(now: at(201), userIdle: 0, hovered: nil, onScreen: [approval, id])
    b.tick(now: at(201 + Timings.chatReplyVisible + Timings.bubbleFade), userIdle: 0, hovered: nil, onScreen: [approval, id])
    #expect(!b.bubbles.contains { $0.id == id }, "on screen, it fades as usual")
}

@Test func rowsBeyondTheVisibleSlotsStillFade() {
    var b = BubbleStore()
    for i in 0..<6 { b.add(.user, mode: .chat, text: "m\(i)", now: t0) }
    let onScreen = Set(b.visible(now: t0).map(\.bubble.id))
    #expect(onScreen.count == Timings.maxVisibleBubbles)
    b.tick(now: at(Timings.bubbleVisible + Timings.bubbleFade), userIdle: 0, hovered: nil, onScreen: onScreen)
    #expect(b.bubbles.isEmpty, "a row visible() leaves out isn't parked: it never comes back later")
}

// MARK: item 18 — one error bubble per failure

@Test func identicalErrorBubbleIsNotStacked() {
    var b = BubbleStore()
    b.add(.error, mode: .code, text: "Claude's console isn't running.", now: t0)
    b.add(.error, mode: .code, text: "Claude's console isn't running.", now: at(1))
    b.add(.error, mode: .chat, text: "Claude's console isn't running.", now: at(1))
    #expect(b.bubbles.filter { $0.kind == .error }.count == 2)
}

// MARK: re-review round

// a) a background call from before the prompt straddles the turn boundary; its approval arrives after an identical new call
@Test func proofTurnBoundaryStraddleMisbinds() {
    var s = Sim(); s.start(.code, now: t0)
    s.handle(.code, ev("PreToolUse", tool: "Bash", input: rm, id: "u8"), now: at(1)) // background agent, previous turn
    s.handle(.code, ev("Stop"), now: at(2))
    s.handle(.code, ev("UserPromptSubmit"), now: at(3))
    s.handle(.code, ev("PreToolUse", tool: "Bash", input: rm, id: "u1"), now: at(4)) // auto-allowed, running
    s.handle(.code, ev("PermissionRequest", tool: "Bash", input: rm), rid: "r8", now: at(5)) // really u8's
    s.submit("typed")
    s.handle(.code, ev("PostToolUse", tool: "Bash", input: rm, id: "u1"), now: at(6))
    #expect(s.releasedHooks.isEmpty, "r8 released by u1's Post: \(s.releasedHooks)")
    #expect(s.sent.isEmpty, "sent \(s.sent) while u8's prompt may be open")
}

// a) a new Claude process (startup/resume) or its end forgets the old one's calls
@Test func newClaudeProcessForgetsOldCalls() {
    for end in [src("SessionStart", "resume"), src("SessionStart", "startup"), ev("SessionEnd")] {
        var t = started()
        t.handle(ev("PreToolUse", tool: "Bash", input: rm, id: "u8"), requestId: nil, now: at(1)) // dies with its process
        t.handle(end, requestId: nil, now: at(2))
        t.handle(ev("UserPromptSubmit"), requestId: nil, now: at(3))
        t.handle(ev("PreToolUse", tool: "Bash", input: rm, id: "u1"), requestId: nil, now: at(4))
        t.handle(ev("PermissionRequest", tool: "Bash", input: rm), requestId: "r1", now: at(4))
        #expect(t.pendingApprovals["r1"] == "u1", "\(end.name) \(end.source ?? "")")
    }
}

// b) a question after Stop (a background agent's AskUserQuestion)
@Test func proofQuestionAfterStopHolds() {
    var s = Sim(); s.start(.code, now: t0)
    s.handle(.code, ev("Stop"), now: at(1))
    s.handle(.code, ev("PreToolUse", tool: "AskUserQuestion", input: ask, id: "q1"), now: at(2))
    s.handle(.code, ev("PermissionRequest", tool: "AskUserQuestion", input: ask), rid: "rq", now: at(2))
    s.submit("typed")
    #expect(s.t[.code]!.pendingQuestion != nil)
    #expect(s.sent.isEmpty, "sent \(s.sent) with a picker open")
    s.handle(.code, ev("PostToolUse", tool: "AskUserQuestion", input: ask, id: "q1"), now: at(9)) // answered
    #expect(s.sent.map(\.1) == ["typed"])
}

// c) Code started outside the saved project folder (the chat-folder fallback) never takes over its session id
@Test func onlyACodeLaunchInTheProjectOwnsItsSession() {
    var s = SavedState()
    #expect(s.ownsCodeSession(cwd: "/chat"), "no project: Code's session is the chat folder's")
    s.projectDir = "/p"
    #expect(s.ownsCodeSession(cwd: "/p"))
    #expect(!s.ownsCodeSession(cwd: "/chat"), "a fallback Code's id would stop the project resuming")
}

// e) the give-back bubble isn't stacked either
@Test func identicalAlertBubbleIsNotStacked() {
    var b = BubbleStore()
    b.add(.alert, mode: .code, text: "Your message to Code is back in the bar", now: t0)
    b.add(.alert, mode: .code, text: "Your message to Code is back in the bar", now: at(1))
    #expect(b.bubbles.count == 1)
}

// 2: re-picking the same project folder keeps its Code session; a different folder starts a new one
@Test func choosingTheSameProjectKeepsItsSession() {
    var s = SavedState(); s.projectDir = "/Users/x/proj"; s.codeSessionId = "c"
    s.chooseProject("/Users/x/proj/"); #expect(s.codeSessionId == "c", "same folder, trailing slash")
    s.chooseProject("/Users/x/./proj"); #expect(s.codeSessionId == "c")
    s.chooseProject("/Users/x/other"); #expect(s.codeSessionId == nil); #expect(s.projectDir == "/Users/x/other")
}
