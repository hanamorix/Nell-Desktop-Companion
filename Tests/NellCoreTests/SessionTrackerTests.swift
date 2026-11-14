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
    t.handle(ev("Stop"), requestId: nil, now: at(3)); #expect(t.state == .done)
    t.tick(now: at(3 + Timings.doneBeat)); #expect(t.state == .idle)
}

@Test func lateToolEventsAfterStopIgnored() {
    var t = started()
    t.handle(ev("Stop"), requestId: nil, now: at(1))
    t.handle(ev("PostToolUse", tool: "Bash", id: "u9"), requestId: nil, now: at(2))
    t.handle(ev("PreToolUse", tool: "Bash", id: "u9"), requestId: nil, now: at(2))
    #expect(t.state == .done)
}

@Test func subagentStopIsNotDone() {
    var t = started()
    t.handle(ev("PreToolUse", tool: "Bash", input: bash, id: "u1"), requestId: nil, now: at(1))
    t.handle(ev("SubagentStop"), requestId: nil, now: at(2))
    #expect(t.state == .typing)
}

@Test func failureIsShortOopsThenThinking() {
    var t = started()
    t.handle(ev("PostToolUseFailure", tool: "Bash", id: "u1"), requestId: nil, now: at(1)); #expect(t.state == .oops)
    t.tick(now: at(1 + Timings.oopsBeat)); #expect(t.state == .thinking)
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

@Test func heldAfterNoneSettleUntilNextEvent() {
    var t = started()
    t.handle(ev("PermissionRequest", tool: "Bash", input: bash), requestId: "r1", now: at(1))
    t.settleApproval("r1", answer: .none)
    #expect(t.inputHeld)
    t.handle(ev("Notification", message: "Claude needs your permission", type: "permission_prompt"), requestId: nil, now: at(6))
    #expect(t.inputHeld)
    t.handle(ev("PostToolUse", tool: "Bash", id: "u1"), requestId: nil, now: at(9))
    #expect(!t.inputHeld)
}

@Test func allowSettleReleasesHoldImmediately() {
    var t = started()
    t.handle(ev("PermissionRequest", tool: "Bash", input: bash), requestId: "r1", now: at(1))
    t.settleApproval("r1", answer: .allow)
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

@Test func sleepyAfter600sIdle() {
    var t = started()
    t.handle(ev("Stop"), requestId: nil, now: at(1))
    t.tick(now: at(1 + Timings.sleepyAfter - 1)); #expect(t.state == .idle)
    t.tick(now: at(1 + Timings.sleepyAfter)); #expect(t.state == .sleepy)
    t.handle(ev("UserPromptSubmit"), requestId: nil, now: at(700)); #expect(t.state == .thinking)
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
    #expect(bodyState(selected: .code, code: code, chat: chat, listening: false) == .needsYou)
}

@Test func errorInOtherModeBeatsSelectedThinking() {
    var code = started(); code.handle(ev("StopFailure"), requestId: nil, now: at(1))
    let chat = started()
    #expect(bodyState(selected: .chat, code: code, chat: chat, listening: false) == .error)
}

@Test func listeningOnlyWhenSelectedIdle() {
    var code = started(); code.handle(ev("Stop"), requestId: nil, now: at(1)); code.tick(now: at(10))
    let chat = started()
    #expect(bodyState(selected: .code, code: code, chat: chat, listening: true) == .listening)
    #expect(bodyState(selected: .chat, code: code, chat: chat, listening: true) == .thinking)
}
