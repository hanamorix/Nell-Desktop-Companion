import Foundation
import Testing
@testable import NellCore

let t0 = Date(timeIntervalSince1970: 1_000_000)
func at(_ s: TimeInterval) -> Date { t0.addingTimeInterval(s) }

func ev(_ name: String, tool: String? = nil, input: [String: JSONValue]? = nil, id: String? = nil,
        message: String? = nil, type: String? = nil) -> HookEvent {
    HookEvent(name: name, sessionId: "S", toolName: tool, toolInput: input, toolUseId: id, prompt: nil,
              message: message, notificationType: type, lastAssistantMessage: nil, error: nil)
}
let bash: [String: JSONValue] = ["command": .string("ls")]
let ask: [String: JSONValue] = ["questions": .array([.object(["question": .string("Cats or dogs?")])])]

func started() -> SessionTracker {
    var t = SessionTracker(); t.handle(ev("SessionStart"), requestId: nil, now: t0); t.handle(ev("UserPromptSubmit"), requestId: nil, now: t0); return t
}

@Test func promptThenToolThenStop() {
    var t = started()
    #expect(t.state == .thinking)
    t.handle(ev("PreToolUse", tool: "Bash", input: bash, id: "u1"), requestId: nil, now: at(1)); #expect(t.state == .typing)
    t.handle(ev("PostToolUse", tool: "Bash", input: bash, id: "u1"), requestId: nil, now: at(2)); #expect(t.state == .thinking)
    t.handle(ev("Stop"), requestId: nil, now: at(3)); #expect(t.state == .idle)
}

@Test func lateToolEventsAfterStopIgnored() {
    var t = started()
    t.handle(ev("Stop"), requestId: nil, now: at(1))
    t.handle(ev("PostToolUse", tool: "Bash", id: "u9"), requestId: nil, now: at(2))
    t.handle(ev("PreToolUse", tool: "Bash", id: "u9"), requestId: nil, now: at(2))
    #expect(t.state == .idle)
}

@Test func subagentStopIsNotDone() {
    var t = started()
    t.handle(ev("PreToolUse", tool: "Bash", input: bash, id: "u1"), requestId: nil, now: at(1))
    t.handle(ev("SubagentStop"), requestId: nil, now: at(2))
    #expect(t.state == .typing)
}

@Test func failureKeepsThinking() {
    var t = started()
    t.handle(ev("PostToolUseFailure", tool: "Bash", id: "u1"), requestId: nil, now: at(1)); #expect(t.state == .thinking)
}

@Test func alertRightAfterAFailureEndsLikeAnyOther() {
    var t = started()
    t.handle(ev("PostToolUseFailure", tool: "Bash", id: "u1"), requestId: nil, now: at(1))
    t.handle(ev("Notification", message: "Claude is waiting for your input", type: "idle_prompt"), requestId: nil, now: at(1.5))
    t.clearAlert() // its bubble faded
    t.tick(now: at(10_000)); #expect(t.state == .idle); #expect(!t.turnRunning)
}

@Test func permissionSettledByMatchingPostToolUse() {
    var t = started()
    t.handle(ev("PreToolUse", tool: "Bash", input: bash, id: "u1"), requestId: nil, now: at(1))
    t.handle(ev("PermissionRequest", tool: "Bash", input: bash), requestId: "r1", now: at(1))
    #expect(t.state == .needsYou); #expect(t.inputHeld)
    let settled = t.handle(ev("PostToolUse", tool: "Bash", input: bash, id: "u1"), requestId: nil, now: at(5))
    #expect(settled == ["r1"]); #expect(!t.inputHeld); #expect(t.state == .thinking)
}

@Test func secondPermissionDoesNotSettleFirst() {
    var t = started()
    t.handle(ev("PreToolUse", tool: "Bash", input: bash, id: "u1"), requestId: nil, now: at(1))
    t.handle(ev("PermissionRequest", tool: "Bash", input: bash), requestId: "r1", now: at(1))
    let other: [String: JSONValue] = ["command": .string("pwd")]
    t.handle(ev("PreToolUse", tool: "Bash", input: other, id: "u2"), requestId: nil, now: at(2))
    let settled = t.handle(ev("PermissionRequest", tool: "Bash", input: other), requestId: "r2", now: at(2))
    #expect(settled.isEmpty); #expect(t.pendingApprovals.keys.sorted() == ["r1", "r2"])
    #expect(t.handle(ev("PostToolUse", tool: "Bash", input: other, id: "u2"), requestId: nil, now: at(3)) == ["r2"])
    #expect(t.pendingApprovals.keys.sorted() == ["r1"]); #expect(t.state == .needsYou)
}

@Test func subagentPreToolUseDoesNotSettleApproval() {
    var t = started()
    t.handle(ev("PreToolUse", tool: "Bash", input: bash, id: "u1"), requestId: nil, now: at(1))
    t.handle(ev("PermissionRequest", tool: "Bash", input: bash), requestId: "r1", now: at(1))
    #expect(t.handle(ev("PreToolUse", tool: "Read", id: "u3"), requestId: nil, now: at(2)).isEmpty)
    #expect(t.state == .needsYou)
}

@Test func turnEndSettlesAllApprovals() {
    var t = started()
    t.handle(ev("PermissionRequest", tool: "Bash", input: bash), requestId: "r1", now: at(1))
    #expect(t.handle(ev("Stop"), requestId: nil, now: at(2)) == ["r1"])
    #expect(t.pendingApprovals.isEmpty)
}

@Test func heldAfterNoneSettleUntilItsToolFinishes() {
    var t = started()
    t.handle(ev("PreToolUse", tool: "Bash", input: bash, id: "u1"), requestId: nil, now: at(1))
    t.handle(ev("PermissionRequest", tool: "Bash", input: bash), requestId: "r1", now: at(1))
    t.settleApproval("r1", answer: .none, now: at(2))
    #expect(t.inputHeld)
    t.handle(ev("Notification", message: "Claude needs your permission", type: "permission_prompt"), requestId: nil, now: at(6))
    #expect(t.inputHeld)
    #expect(t.lastAlert == nil, "you're answering that prompt in the console"); #expect(t.state != .alert)
    t.handle(ev("PostToolUse", tool: "Bash", id: "u1"), requestId: nil, now: at(9))
    #expect(!t.inputHeld)
}

@Test func allowSettleReleasesHoldImmediately() {
    var t = started()
    t.handle(ev("PermissionRequest", tool: "Bash", input: bash), requestId: "r1", now: at(1))
    t.settleApproval("r1", answer: .allow, now: at(2))
    #expect(!t.inputHeld); #expect(t.state != .needsYou)
}

@Test func questionHeldUntilAnswered() {
    var t = started()
    t.handle(ev("PreToolUse", tool: "AskUserQuestion", input: ask, id: "u4"), requestId: nil, now: at(1))
    t.handle(ev("PermissionRequest", tool: "AskUserQuestion", input: ask), requestId: "r4", now: at(1))
    #expect(t.state == .question); #expect(t.pendingQuestion == "Cats or dogs?"); #expect(t.pendingApprovals.isEmpty)
    t.handle(ev("Notification", message: "Claude needs your permission", type: "permission_prompt"), requestId: nil, now: at(7))
    #expect(t.inputHeld)
    t.handle(ev("PostToolUse", tool: "AskUserQuestion", id: "u4"), requestId: nil, now: at(20))
    #expect(t.pendingQuestion == nil); #expect(!t.inputHeld)
}

@Test func permissionNotificationSuppressedWhilePending() {
    var t = started()
    t.handle(ev("PermissionRequest", tool: "Bash", input: bash), requestId: "r1", now: at(1))
    #expect(t.handle(ev("Notification", message: "Claude needs your permission", type: "permission_prompt"), requestId: nil, now: at(7)).isEmpty)
    #expect(t.lastAlert == nil); #expect(t.state == .needsYou)
}

@Test func duplicateIdleNotificationShownOnce() {
    var t = started()
    t.handle(ev("Stop"), requestId: nil, now: at(1))
    t.handle(ev("Notification", message: "Claude is waiting for your input", type: "idle_prompt"), requestId: nil, now: at(60))
    #expect(t.state == .alert); #expect(t.lastAlert == "Claude is waiting for your input")
    t.clearAlert()
    t.handle(ev("Notification", message: "Claude is waiting for your input", type: "idle_prompt"), requestId: nil, now: at(120))
    #expect(t.state == .idle); #expect(t.lastAlert == nil)
}

@Test func watchdogDropsTypingAfter180s() {
    var t = started()
    t.handle(ev("PreToolUse", tool: "Bash", input: bash, id: "u1"), requestId: nil, now: at(1))
    t.tick(now: at(1 + Timings.typingWatchdog - 1)); #expect(t.state == .typing)
    t.tick(now: at(1 + Timings.typingWatchdog)); #expect(t.state == .idle)
}

@Test func watchdogLeavesPendingApprovalAlone() {
    var t = started()
    t.handle(ev("PermissionRequest", tool: "Bash", input: bash), requestId: "r1", now: at(1))
    t.tick(now: at(1000)); #expect(t.state == .needsYou)
}

@Test func noSleepyAfterLongIdle() {
    var t = started()
    t.handle(ev("Stop"), requestId: nil, now: at(1))
    t.tick(now: at(1 + 100_000)); #expect(t.state == .idle)
}

@Test func usageLimitedFromRateLimitUntilStop() {
    var t = started()
    t.handle(HookEvent(name: "StopFailure", sessionId: "S", toolName: nil, toolInput: nil, toolUseId: nil, prompt: nil,
                       message: nil, notificationType: nil, lastAssistantMessage: nil, error: "rate_limit"), requestId: nil, now: at(1))
    #expect(t.usageLimited)
    t.handle(ev("StopFailure"), requestId: nil, now: at(2)); #expect(t.usageLimited) // other failure doesn't clear it
    t.handle(ev("UserPromptSubmit"), requestId: nil, now: at(3)); t.handle(ev("Stop"), requestId: nil, now: at(4))
    #expect(!t.usageLimited)
}

@Test func testRunningFromPreToolUseToMatchingPost() {
    var t = started()
    let swiftTest: [String: JSONValue] = ["command": .string("swift test")]
    t.handle(ev("PreToolUse", tool: "Bash", input: bash, id: "u0"), requestId: nil, now: at(1)); #expect(!t.testRunning)
    t.handle(ev("PreToolUse", tool: "Bash", input: swiftTest, id: "u1"), requestId: nil, now: at(2)); #expect(t.testRunning)
    t.handle(ev("PostToolUse", tool: "Bash", input: bash, id: "u0"), requestId: nil, now: at(3)); #expect(t.testRunning)
    t.handle(ev("PostToolUseFailure", tool: "Bash", input: swiftTest, id: "u1"), requestId: nil, now: at(4)); #expect(!t.testRunning)
    t.handle(ev("PreToolUse", tool: "Bash", input: swiftTest, id: "u2"), requestId: nil, now: at(5)); #expect(t.testRunning)
    t.handle(ev("Stop"), requestId: nil, now: at(6)); #expect(!t.testRunning)
}

@Test func disconnectedIfNoSessionStartIn8s() {
    var t = SessionTracker(); t.markLaunched(now: t0)
    t.tick(now: at(Timings.hooksNotConnected - 1)); #expect(t.state == .idle)
    t.tick(now: at(Timings.hooksNotConnected)); #expect(t.state == .disconnected)
    t.handle(ev("SessionStart"), requestId: nil, now: at(20)); #expect(t.state == .idle)
}

@Test func needsYouInChatBeatsTypingInCode() {
    var code = started(); code.handle(ev("PreToolUse", tool: "Bash", input: bash, id: "u1"), requestId: nil, now: at(1))
    var chat = started(); chat.handle(ev("PermissionRequest", tool: "Bash", input: bash), requestId: "r1", now: at(1))
    #expect(promptWaiting(code: code, chat: chat) == .needsYou)
}

@Test func promptWaitingTellsAQuestionFromNothing() {
    var code = started(); code.handle(ev("PreToolUse", tool: "AskUserQuestion", input: ask, id: "u4"), requestId: nil, now: at(1))
    var chat = started()
    #expect(promptWaiting(code: code, chat: chat) == .question, "needs-you → question still chimes")
    chat.handle(ev("PermissionRequest", tool: "Bash", input: bash), requestId: "r1", now: at(1))
    #expect(promptWaiting(code: code, chat: chat) == .needsYou)
    #expect(promptWaiting(code: started(), chat: started()) == nil)
}

// MARK: final-review fixes

@Test func heldUntilSessionStartAfterLaunch() {
    var t = SessionTracker(); t.markLaunched(now: t0)
    #expect(t.inputHeld) // the trust dialog or a still-starting claude would eat the text
    t.handle(ev("SessionStart"), requestId: nil, now: at(2))
    #expect(!t.inputHeld)
}

@Test func sessionEndDoesNotCountAsConnected() {
    var t = SessionTracker(); t.markLaunched(now: t0)
    t.handle(ev("SessionEnd"), requestId: nil, now: at(1)) // the old window's session closing
    t.tick(now: at(Timings.hooksNotConnected)); #expect(t.state == .disconnected)
}

@Test func unrelatedEventsKeepHoldAfterOpenTerminal() {
    var t = started()
    t.handle(ev("PreToolUse", tool: "Bash", input: bash, id: "u1"), requestId: nil, now: at(1))
    t.handle(ev("PermissionRequest", tool: "Bash", input: bash), requestId: "r1", now: at(1))
    t.settleApproval("r1", answer: .none, now: at(1))
    t.handle(ev("PreToolUse", tool: "Read", id: "u7"), requestId: nil, now: at(2))   // a parallel subagent tool
    t.handle(ev("PostToolUse", tool: "Read", id: "u7"), requestId: nil, now: at(3))
    #expect(t.inputHeld)
    t.handle(ev("PostToolUse", tool: "Bash", input: bash, id: "u1"), requestId: nil, now: at(4))
    #expect(!t.inputHeld)
}

@Test func unrelatedEventsKeepQuestion() {
    var t = started()
    t.handle(ev("PreToolUse", tool: "AskUserQuestion", input: ask, id: "u4"), requestId: nil, now: at(1))
    t.handle(ev("PostToolUse", tool: "Read", id: "u9"), requestId: nil, now: at(2))
    #expect(t.pendingQuestion != nil)
    t.handle(ev("Stop"), requestId: nil, now: at(3))
    #expect(t.pendingQuestion == nil)
}

@Test func holdExpiresAfterSilence() {
    var t = started()
    t.handle(ev("PermissionRequest", tool: "Bash", input: bash), requestId: "r1", now: at(1))
    t.settleApproval("r1", answer: .none, now: at(1)) // then Esc in kitty: no event ever comes
    t.tick(now: at(1 + Timings.typingWatchdog)); #expect(!t.inputHeld)
}

@Test func permissionMatchedWithTwoOpenPreToolUses() {
    var t = started()
    let other: [String: JSONValue] = ["command": .string("pwd")]
    t.handle(ev("PreToolUse", tool: "Bash", input: bash, id: "uA"), requestId: nil, now: at(1))
    t.handle(ev("PreToolUse", tool: "Bash", input: other, id: "uB"), requestId: nil, now: at(1))
    t.handle(ev("PermissionRequest", tool: "Bash", input: bash), requestId: "rA", now: at(1))
    #expect(t.pendingApprovals["rA"] == "uA")
    #expect(t.handle(ev("PostToolUse", tool: "Bash", input: bash, id: "uA"), requestId: nil, now: at(2)) == ["rA"])
}

@Test func sessionStartRecordsSessionId() {
    var t = SessionTracker()
    var e = ev("SessionStart"); e.sessionId = "new-id"
    t.handle(e, requestId: nil, now: t0)
    #expect(t.sessionId == "new-id")
}

// MARK: review fixes (P3)

@Test func deadlineHandoffHoldIsTimedFromItsOwnStart() {
    var t = started()
    t.handle(ev("PreToolUse", tool: "Bash", input: bash, id: "u1"), requestId: nil, now: at(1))
    t.handle(ev("PermissionRequest", tool: "Bash", input: bash), requestId: "r1", now: at(1))
    t.settleApproval("r1", answer: .none, now: at(591)) // the 590 s deadline: Claude's own prompt is still open in kitty
    t.tick(now: at(592)); #expect(t.inputHeld, "silence since the last event isn't the hold's age")
    t.tick(now: at(591 + Timings.typingWatchdog - 1)); #expect(t.inputHeld)
    t.tick(now: at(591 + Timings.typingWatchdog)); #expect(!t.inputHeld)
}

@Test func identicalParallelCallsMatchInOrder() {
    var t = started()
    t.handle(ev("PreToolUse", tool: "Bash", input: bash, id: "u1"), requestId: nil, now: at(1))
    t.handle(ev("PreToolUse", tool: "Bash", input: bash, id: "u2"), requestId: nil, now: at(1))
    t.handle(ev("PermissionRequest", tool: "Bash", input: bash), requestId: "r1", now: at(1))
    t.settleApproval("r1", answer: .allow, now: at(2)) // answered before the second request arrives
    t.handle(ev("PermissionRequest", tool: "Bash", input: bash), requestId: "r2", now: at(3))
    #expect(t.pendingApprovals["r2"] == "u2")
    #expect(t.handle(ev("PostToolUse", tool: "Bash", input: bash, id: "u1"), requestId: nil, now: at(4)).isEmpty, "u1 isn't r2's")
    #expect(t.handle(ev("PostToolUse", tool: "Bash", input: bash, id: "u2"), requestId: nil, now: at(5)) == ["r2"])
}

@Test func identicalCallsBothPendingMatchInOrder() {
    var t = started()
    t.handle(ev("PreToolUse", tool: "Bash", input: bash, id: "u1"), requestId: nil, now: at(1))
    t.handle(ev("PreToolUse", tool: "Bash", input: bash, id: "u2"), requestId: nil, now: at(1))
    t.handle(ev("PermissionRequest", tool: "Bash", input: bash), requestId: "r1", now: at(1))
    t.handle(ev("PermissionRequest", tool: "Bash", input: bash), requestId: "r2", now: at(1))
    #expect(t.pendingApprovals["r1"] == "u1"); #expect(t.pendingApprovals["r2"] == "u2")
    #expect(t.handle(ev("PostToolUse", tool: "Bash", input: bash, id: "u1"), requestId: nil, now: at(2)) == ["r1"])
}

@Test func unfinishedToolUsesDontOutliveTheirTurnOrDenial() {
    var t = started()
    t.handle(ev("PreToolUse", tool: "Bash", input: bash, id: "u0"), requestId: nil, now: at(1)) // never finishes (Esc)
    t.handle(ev("Stop"), requestId: nil, now: at(2))
    t.handle(ev("UserPromptSubmit"), requestId: nil, now: at(3))
    t.handle(ev("PreToolUse", tool: "Bash", input: bash, id: "u1"), requestId: nil, now: at(4))
    t.handle(ev("PermissionRequest", tool: "Bash", input: bash), requestId: "r1", now: at(4))
    #expect(t.pendingApprovals["r1"] == "u1", "not the last turn's u0")
    t.settleApproval("r1", answer: .deny, now: at(5)) // a denied tool gets no Post: Claude retries the same call
    t.handle(ev("PreToolUse", tool: "Bash", input: bash, id: "u2"), requestId: nil, now: at(6))
    t.handle(ev("PermissionRequest", tool: "Bash", input: bash), requestId: "r2", now: at(6))
    #expect(t.pendingApprovals["r2"] == "u2", "not the denied u1")
}

@Test func deniedTestStopsTheYawn() {
    var t = started()
    t.handle(ev("PreToolUse", tool: "Bash", input: ["command": .string("swift test")], id: "u1"), requestId: nil, now: at(1))
    t.handle(ev("PermissionRequest", tool: "Bash", input: ["command": .string("swift test")]), requestId: "r1", now: at(1))
    #expect(t.testRunning)
    t.settleApproval("r1", answer: .deny, now: at(2))
    #expect(!t.testRunning, "a denied test never runs")
}

@Test func relaunchedClaudeStartsClean() {
    var t = started()
    t.handle(ev("PreToolUse", tool: "AskUserQuestion", input: ask, id: "u4"), requestId: nil, now: at(1))
    t.handle(ev("PreToolUse", tool: "Bash", input: ["command": .string("swift test")], id: "u5"), requestId: nil, now: at(2))
    t.handle(ev("PreToolUse", tool: "Bash", input: bash, id: "u6"), requestId: nil, now: at(3))
    t.handle(ev("PermissionRequest", tool: "Bash", input: bash), requestId: "r6", now: at(3))
    t.markLaunched(now: at(10)) // claude died with no SessionEnd; Nell starts a new one
    var resume = ev("SessionStart"); resume.source = "resume"; resume.sessionId = "new"
    #expect(t.handle(resume, requestId: nil, now: at(12)) == ["r6"])
    #expect(t.pendingQuestion == nil); #expect(!t.testRunning); #expect(!t.inputHeld); #expect(t.state == .idle)
    t.handle(ev("PostToolUse", tool: "Bash", input: bash, id: "u6"), requestId: nil, now: at(13)) // the dead process's late event
    #expect(t.state == .idle); #expect(!t.turnRunning)
}

@Test func compactionMidTurnKeepsTyping() {
    var t = started()
    t.handle(ev("PreToolUse", tool: "Bash", input: bash, id: "u1"), requestId: nil, now: at(1))
    var compact = ev("SessionStart"); compact.source = "compact"
    t.handle(compact, requestId: nil, now: at(2))
    #expect(t.state == .typing); #expect(t.turnRunning)
}

@Test func interruptGoesIdleButKeepsTrackingTheTurn() {
    var t = started()
    t.handle(ev("PreToolUse", tool: "Bash", input: bash, id: "u1"), requestId: nil, now: at(1))
    var esc = ev("PostToolUseFailure", tool: "Bash", input: bash, id: "u1"); esc.isInterrupt = true
    t.handle(esc, requestId: nil, now: at(2))
    #expect(t.state == .idle); #expect(!t.turnRunning)
    t.handle(ev("PreToolUse", tool: "Bash", input: bash, id: "u2"), requestId: nil, now: at(3)) // not finalized: still tracked
    t.handle(ev("PermissionRequest", tool: "Bash", input: bash), requestId: "r2", now: at(3))
    #expect(t.pendingApprovals["r2"] == "u2"); #expect(t.state == .needsYou)
}

@Test func approvalAfterStopIsStillTracked() {
    var t = started()
    t.handle(ev("Stop"), requestId: nil, now: at(1))
    t.handle(ev("PermissionRequest", tool: "Bash", input: bash), requestId: "r1", now: at(2)) // a blocking hook: a live prompt
    #expect(t.pendingApprovals.keys.sorted() == ["r1"]); #expect(t.inputHeld); #expect(t.state == .needsYou)
    t.settleApproval("r1", answer: .none, now: at(592)) // the deadline: Claude's own prompt is open in kitty
    t.tick(now: at(593)); #expect(t.inputHeld)
}

@Test func turnEndSettlesPinnedQuestionAndConsoleBubbles() {
    func store() -> BubbleStore {
        var b = BubbleStore()
        b.add(.question, mode: .code, text: "Cats or dogs?", now: t0)
        b.add(.consoleNeeded, mode: .code, text: "Answer in the console", now: t0)
        b.add(.question, mode: .chat, text: "The other mode's", now: t0)
        return b
    }
    var resume = ev("SessionStart"); resume.source = "resume"
    for e in [ev("UserPromptSubmit"), ev("Stop"), ev("StopFailure"), ev("SessionEnd"), resume] {
        var b = store(); settleBubbles(after: e, mode: .code, settled: [], in: &b)
        #expect(b.bubbles.map(\.settled) == [true, true, false], "\(e.name)")
    }
    var compact = ev("SessionStart"); compact.source = "compact"
    var b = store(); settleBubbles(after: compact, mode: .code, settled: [], in: &b)
    #expect(b.bubbles.map(\.settled) == [false, true, false], "compaction isn't a turn end; any SessionStart answers the console")
    b = store(); settleBubbles(after: ev("PostToolUse", tool: "Read", id: "u1"), mode: .code, settled: [], in: &b)
    #expect(b.bubbles.map(\.settled) == [false, false, false])
    b = store(); settleBubbles(after: ev("PostToolUse", tool: "AskUserQuestion", id: "u4"), mode: .code, settled: [], in: &b)
    #expect(b.bubbles.map(\.settled) == [true, false, false])
}

@Test func approvalsTheTrackerSettledAreAnsweredInConsole() {
    var b = BubbleStore(); b.add(.approval(requestId: "r1"), mode: .code, text: "Run ls", now: t0)
    settleBubbles(after: ev("PostToolUse", tool: "Bash", id: "u1"), mode: .code, settled: ["r1"], in: &b)
    #expect(b.bubbles[0].settled); #expect(b.bubbles[0].text == "Run ls — Answered in console")
}

@Test func dismissingAQuestionReleasesTheBar() {
    var t = started()
    t.handle(ev("PreToolUse", tool: "AskUserQuestion", input: ask, id: "u4"), requestId: nil, now: at(1))
    t.handle(ev("PermissionRequest", tool: "AskUserQuestion", input: ask), requestId: "r4", now: at(1))
    t.tick(now: at(100_000)); #expect(t.inputHeld, "no timer on a question: you may be away")
    t.dismissQuestion()
    #expect(t.pendingQuestion == nil); #expect(!t.inputHeld); #expect(t.state != .question)
}
