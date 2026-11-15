import CoreGraphics
import Foundation
import Testing
@testable import NellCore

private func event(_ name: String) throws -> HookEvent { try HookEvent.decode(fixture(name)) }

// MARK: Event → brief emoji

@Test func testResultsReactInCodeOnly() throws {
    let pass = try event("PostToolUse-Bash-testpass"), fail = try event("PostToolUseFailure-Bash-testfail")
    #expect(flash(for: pass, mode: .code, approvedInKitty: false, newAlert: false) == .heart)
    #expect(flash(for: fail, mode: .code, approvedInKitty: false, newAlert: false) == .crying)
    #expect(flash(for: pass, mode: .chat, approvedInKitty: false, newAlert: false) == nil)
    #expect(flash(for: fail, mode: .chat, approvedInKitty: false, newAlert: false) == nil, "a test failure is never ❗")
}

@Test func pipedRunReactsOnlyToAWholeRunSummary() throws {
    let piped = try event("PostToolUse-Bash-testfail-piped")
    #expect(flash(for: piped, mode: .code, approvedInKitty: false, newAlert: false) == .crying, "its stdout says FAILED")
    let unclear = HookEvent(name: "PostToolUse", sessionId: "S", toolName: "Bash", toolInput: ["command": .string("swift test | tail")],
                            toolResponse: .object(["stdout": .string("done"), "stderr": .string("")]))
    #expect(flash(for: unclear, mode: .code, approvedInKitty: false, newAlert: false) == nil)
    var failed = unclear; failed.name = "PostToolUseFailure"; failed.error = "Exit code 1\nsomething"
    #expect(flash(for: failed, mode: .code, approvedInKitty: false, newAlert: false) == nil, "piped failure: no reaction, not ❗")
    #expect(flash(for: unclear, mode: .code, approvedInKitty: true, newAlert: false) == .thumbsup, "still approved in kitty")
}

@Test func nonTestFailureIsAlert() throws {
    var e = try event("PostToolUse-Bash"); e.name = "PostToolUseFailure"
    #expect(flash(for: e, mode: .code, approvedInKitty: false, newAlert: false) == .alert)
    e.isInterrupt = true
    #expect(flash(for: e, mode: .code, approvedInKitty: false, newAlert: false) == nil, "you pressed Esc")
    #expect(flash(for: try event("PostToolUse-Bash"), mode: .code, approvedInKitty: false, newAlert: false) == nil)
    #expect(flash(for: try event("PostToolUse-Bash"), mode: .code, approvedInKitty: true, newAlert: false) == .thumbsup)
    var failedAfterKitty = try event("PostToolUse-Bash"); failedAfterKitty.name = "PostToolUseFailure"
    #expect(flash(for: failedAfterKitty, mode: .code, approvedInKitty: true, newAlert: false) == .alert, "no 👍 for a failed run")
}

@Test func stopFailureAndNotifications() throws {
    let limit = try event("StopFailure-rate_limit.documented-not-observed")
    #expect(flash(for: limit, mode: .code, approvedInKitty: false, newAlert: false) == nil, "a limit sleeps instead")
    var other = limit; other.error = "server_error"
    #expect(flash(for: other, mode: .chat, approvedInKitty: false, newAlert: false) == .alert)
    let n = try event("Notification-idle_prompt")
    #expect(flash(for: n, mode: .chat, approvedInKitty: false, newAlert: true) == .alert)
    #expect(flash(for: n, mode: .chat, approvedInKitty: false, newAlert: false) == nil, "already shown")
    #expect(flash(for: try event("Stop"), mode: .code, approvedInKitty: false, newAlert: false) == nil)
}

// MARK: Held emoji

@Test func heldEmojiFromTrackerState() {
    let idle = started()
    #expect(heldEmoji(code: idle, chat: idle).isEmpty)
    var approval = started()
    approval.handle(ev("PreToolUse", tool: "Bash", input: bash, id: "u1"), requestId: nil, now: at(1))
    approval.handle(ev("PermissionRequest", tool: "Bash", input: bash), requestId: "r1", now: at(1))
    #expect(heldEmoji(code: idle, chat: approval) == [.warning])
    var question = started()
    question.handle(ev("PreToolUse", tool: "AskUserQuestion", input: ask, id: "q"), requestId: nil, now: at(1))
    #expect(heldEmoji(code: question, chat: idle) == [.question])
    var limited = started()
    limited.handle(ev("StopFailure", errorText: "rate_limit"), requestId: nil, now: at(1))
    #expect(heldEmoji(code: limited, chat: idle) == [.plug])
    var deaf = SessionTracker(); deaf.markLaunched(now: t0); deaf.tick(now: at(Timings.hooksNotConnected))
    #expect(heldEmoji(code: idle, chat: deaf) == [.plug])
}

@Test func nextExpiryOfBriefEmoji() {
    var r = ReactionState()
    #expect(r.nextExpiry(now: at(0)) == nil)
    r.flash(.heart, now: at(0)); r.flash(.alert, now: at(1))
    #expect(r.nextExpiry(now: at(1)) == at(2.5))
    #expect(r.nextExpiry(now: at(2.5)) == at(3.5))
    #expect(r.nextExpiry(now: at(3.5)) == nil)
}

// MARK: Sleeping, and 👍 after kitty

@Test func quotaNotificationsWakeHerWithoutAlert() {
    for type in ["quota_auto_resume_fired", "quota_auto_resume_stale", "quota_auto_resume_disabled"] {
        var t = started()
        t.handle(ev("StopFailure", errorText: "rate_limit"), requestId: nil, now: at(1)); #expect(t.usageLimited)
        t.handle(ev("Notification", message: "Resuming", type: type), requestId: nil, now: at(2))
        #expect(!t.usageLimited, "\(type)")
        #expect(t.lastAlert == nil, "\(type) is not an alert")
    }
}

@Test func toolCallWakesHer() {
    var t = started()
    t.handle(ev("StopFailure", errorText: "rate_limit"), requestId: nil, now: at(1))
    t.handle(ev("UserPromptSubmit"), requestId: nil, now: at(2)); #expect(t.usageLimited)
    t.handle(ev("PreToolUse", tool: "Bash", input: bash, id: "u1"), requestId: nil, now: at(3)); #expect(!t.usageLimited)
    var other = started()
    other.handle(ev("StopFailure", errorText: "server_error"), requestId: nil, now: at(1)); #expect(!other.usageLimited)
}

@Test func approvalAnsweredInKittyThenRun() {
    // Answered in kitty while Nell's bubble was still pending.
    var t = started()
    t.handle(ev("PreToolUse", tool: "Bash", input: bash, id: "u1"), requestId: nil, now: at(1))
    t.handle(ev("PermissionRequest", tool: "Bash", input: bash), requestId: "r1", now: at(1))
    #expect(t.ranAfterKittyApproval(ev("PostToolUse", tool: "Bash", input: bash, id: "u1")))
    #expect(!t.ranAfterKittyApproval(ev("PostToolUseFailure", tool: "Bash", input: bash, id: "u1")))
    #expect(!t.ranAfterKittyApproval(ev("PostToolUse", tool: "Bash", input: bash, id: "u2")))
    // Handed to the console (Console button or deadline), then answered there.
    var c = started()
    c.handle(ev("PreToolUse", tool: "Bash", input: bash, id: "u1"), requestId: nil, now: at(1))
    c.handle(ev("PermissionRequest", tool: "Bash", input: bash), requestId: "r1", now: at(1))
    c.settleApproval("r1", answer: .none, now: at(2))
    #expect(c.ranAfterKittyApproval(ev("PostToolUse", tool: "Bash", input: bash, id: "u1")))
    // Allowed in Nell: the 👍 came from the button, not again from the run.
    var a = started()
    a.handle(ev("PreToolUse", tool: "Bash", input: bash, id: "u1"), requestId: nil, now: at(1))
    a.handle(ev("PermissionRequest", tool: "Bash", input: bash), requestId: "r1", now: at(1))
    a.settleApproval("r1", answer: .allow, now: at(2))
    #expect(!a.ranAfterKittyApproval(ev("PostToolUse", tool: "Bash", input: bash, id: "u1")))
}

// MARK: Paper stacks

@Test func contextFollowsCodeOnly() throws {
    #expect(contextAction(for: try event("SessionStart-clear"), mode: .code) == .reset)
    #expect(contextAction(for: try event("PreCompact-manual"), mode: .code) == .reset)
    #expect(contextAction(for: try event("PostCompact-manual"), mode: .code) == .reset)
    #expect(contextAction(for: try event("SessionStart-compact"), mode: .code) == nil)
    #expect(contextAction(for: try event("SessionStart"), mode: .code) == .read(transcriptPath: "/Users/x/.claude/projects/-Users-x-proj/S.jsonl"),
            "after a relaunch the stacks come back before the first Stop")
    var resumed = try event("SessionStart"); resumed.source = "resume"
    #expect(contextAction(for: resumed, mode: .code) == .read(transcriptPath: "/Users/x/.claude/projects/-Users-x-proj/S.jsonl"))
    #expect(contextAction(for: resumed, mode: .chat) == nil)
    #expect(contextAction(for: try event("Stop"), mode: .code) == .read(transcriptPath: "/Users/x/.claude/projects/-Users-x-proj/S.jsonl"))
    #expect(contextAction(for: try event("Stop"), mode: .chat) == nil)
    #expect(contextAction(for: try event("SessionStart-clear"), mode: .chat) == nil)
}

@Test func transcriptTailIsBounded() throws {
    let url = try #require(Bundle.module.url(forResource: "transcript-usage", withExtension: "jsonl", subdirectory: "Fixtures"))
    let whole = try Data(contentsOf: url)
    #expect(ContextMeter.tail(of: url, maxBytes: 1 << 20) == whole)
    let tail = try #require(ContextMeter.tail(of: url, maxBytes: 1_000))
    #expect(tail == whole.suffix(1_000))
    #expect(ContextMeter.tokens(fromTranscriptTail: tail) == 15_645, "the cut first line is skipped")
    #expect(ContextMeter.tail(of: URL(fileURLWithPath: "/nonexistent/x.jsonl"), maxBytes: 10) == nil)
}

// MARK: Compositing

@Test func blitsDrawBodyFaceBlinkPaperEmoji() throws {
    let s = try realSheet()
    let f = Animator.Frame(body: 11, face: 5, faceAt: CGRect(x: 42, y: 35, width: 48, height: 35), eyesClosed: true)
    #expect(s.blits(f, stacks: 2, emoji: .heart, mirrored: false) == [
        Blit(src: CGRect(x: 384, y: 128, width: 128, height: 128), dst: CGRect(x: 0, y: 0, width: 128, height: 128), flipped: false),
        Blit(src: CGRect(x: 682, y: 36, width: 48, height: 35), dst: CGRect(x: 42, y: 35, width: 48, height: 35), flipped: false),
        Blit(src: CGRect(x: 44, y: 172, width: 45, height: 19), dst: CGRect(x: 44, y: 43, width: 45, height: 19), flipped: false),
        Blit(src: CGRect(x: 730, y: 842, width: 34, height: 34), dst: CGRect(x: 90, y: 74, width: 34, height: 34), flipped: false),
        Blit(src: CGRect(x: 796, y: 910, width: 16, height: 16), dst: CGRect(x: 28, y: 13, width: 16, height: 16), flipped: false),
    ])
    let open = Animator.Frame(body: 9, face: 0, faceAt: CGRect(x: 42, y: 36, width: 48, height: 35), eyesClosed: false)
    #expect(s.blits(open, stacks: 0, emoji: nil, mirrored: false).count == 2, "body + face only")
    #expect(s.blits(open, stacks: 9, emoji: nil, mirrored: false).count == 3, "stacks cap at paper:5")
}

@Test func faceDrawnFramesSkipFaceAndBlink() throws {
    let s = try realSheet()
    let asleep = Animator.Frame(body: 37, face: 2, faceAt: CGRect(x: 42, y: 60, width: 48, height: 35), eyesClosed: true)
    let b = s.blits(asleep, stacks: 1, emoji: .plug, mirrored: false)
    #expect(b.map(\.src.size) == [CGSize(width: 128, height: 128), CGSize(width: 34, height: 34), CGSize(width: 16, height: 16)])
    #expect(b.last?.dst == CGRect(x: 28, y: 38, width: 16, height: 16), "emoji follows her head down")
}

@Test func mirroredFlipsHerButNotTheEmoji() throws {
    let s = try realSheet()
    let f = Animator.Frame(body: 9, face: 0, faceAt: CGRect(x: 42, y: 36, width: 48, height: 35), eyesClosed: false)
    let b = s.blits(f, stacks: 0, emoji: .question, mirrored: true)
    #expect(b.map(\.flipped) == [true, true, false])
    #expect(b.map(\.dst.minX) == [0, 38, 84])
}

private func ev(_ name: String, errorText: String) -> HookEvent {
    var e = ev(name); e.error = errorText; return e
}

@Test func typingLastsThroughAFailedTool() {
    var t = started()
    t.handle(ev("PreToolUse", tool: "Bash", input: bash, id: "u1"), requestId: nil, now: at(1))
    t.handle(ev("PostToolUseFailure", tool: "Bash", input: bash, id: "u1"), requestId: nil, now: at(2))
    #expect(body(code: t, chat: SessionTracker(), selected: .code) == .typing, "the turn is still running")
    t.handle(ev("Notification", message: "Claude needs your permission", type: "idle_prompt"), requestId: nil, now: at(3))
    #expect(body(code: t, chat: SessionTracker(), selected: .code) == .typing)
}

// MARK: Fix round 1

@Test func limitClearIsAccountWide() {
    var trackers: [Mode: SessionTracker] = [.code: started(), .chat: started()]
    trackers[.chat]?.handle(ev("StopFailure", errorText: "rate_limit"), requestId: nil, now: at(1))
    #expect(trackers[.chat]?.usageLimited == true)
    // The limit lifts and you work only in Code: Code's next turn wakes her in both.
    let stop = ev("Stop")
    trackers[.code]?.handle(stop, requestId: nil, now: at(2))
    endUsageLimitAccountWide(stop, &trackers)
    #expect(trackers[.chat]?.usageLimited == false)
    #expect(body(code: trackers[.code]!, chat: trackers[.chat]!, selected: .code) == .idle)
    #expect(heldEmoji(code: trackers[.code]!, chat: trackers[.chat]!).isEmpty)
    for e in [ev("PreToolUse", tool: "Bash", input: bash, id: "u9"), ev("Notification", message: "Resuming", type: "quota_auto_resume_fired")] {
        trackers[.chat]?.handle(ev("StopFailure", errorText: "rate_limit"), requestId: nil, now: at(3))
        endUsageLimitAccountWide(e, &trackers)
        #expect(trackers[.chat]?.usageLimited == false, "\(e.name)")
    }
    // A session ending clears only its own flag: the other may still be limited.
    trackers[.chat]?.handle(ev("StopFailure", errorText: "rate_limit"), requestId: nil, now: at(4))
    trackers[.code]?.handle(ev("StopFailure", errorText: "rate_limit"), requestId: nil, now: at(4))
    let end = ev("SessionEnd")
    trackers[.code]?.handle(end, requestId: nil, now: at(5))
    endUsageLimitAccountWide(end, &trackers)
    #expect(trackers[.code]?.usageLimited == false)
    #expect(trackers[.chat]?.usageLimited == true)
    endUsageLimitAccountWide(ev("UserPromptSubmit"), &trackers)
    #expect(trackers[.chat]?.usageLimited == true, "a prompt alone proves nothing")
}

/// Ticks at each `nextChange` (or 10 ms on, if it is due now) until `stop` holds for a returned frame.
private func tickUntil(_ a: inout Animator, _ now: inout Date, max: Int = 400, _ stop: (Animator.Frame) -> Bool) -> Animator.Frame? {
    for _ in 0..<max {
        let next = a.nextChange
        now = next > now ? next : now.addingTimeInterval(0.01)
        if let f = a.tick(now: now, quiet: false), stop(f) { return f }
    }
    return nil
}

@Test func faceSwapWaitsForTheFaceToShow() throws {
    let s = try realSheet()
    var a = Animator(sheet: s, seed: 7), now = t0
    _ = a.tick(now: now, quiet: false)
    a.request(body: .yawning, face: .exhausted, now: now)
    _ = try #require(tickUntil(&a, &now) { s.tag("body:yawning")!.contains($0.body) })
    a.request(body: .yawning, face: .happy, now: now) // ❤️ while she yawns: the hand hides her mouth
    let end = now.addingTimeInterval(3)
    while now < end {
        now = max(a.nextChange, now.addingTimeInterval(0.01))
        if let f = a.tick(now: now, quiet: false) { #expect(f.face == s.tag("face:exhausted")!.lowerBound, "no swap behind a drawn face") }
    }
    a.request(body: .typing, face: .happy, now: now)
    let first = try #require(tickUntil(&a, &now) { !s.faceDrawn(frame: $0.body) })
    #expect(s.tag("body:typing")!.contains(first.body))
    #expect(first.face == s.tag("face:happy")!.lowerBound)
    #expect(first.eyesClosed, "the new face opens out of a blink")
}

@Test func heldFaceSwapDoesNotSpin() throws {
    let s = try realSheet()
    var a = Animator(sheet: s, seed: 7), now = t0
    _ = a.tick(now: now, quiet: false)
    a.request(body: .yawning, face: .exhausted, now: now)
    _ = try #require(tickUntil(&a, &now) { s.tag("body:yawning")!.contains($0.body) })
    a.request(body: .yawning, face: .scared, now: now)
    for _ in 0..<20 {
        #expect(a.nextChange > now, "a held swap must not ask for an immediate tick")
        now = a.nextChange
        _ = a.tick(now: now, quiet: false)
    }
}

@Test func pausedWhileLockedOrAsleep() {
    var p = PauseState()
    #expect(!p.paused)
    p.locked = true; #expect(p.paused)
    p.asleep = true; #expect(p.paused)
    p.asleep = false; #expect(p.paused, "display wakes on the lock screen: still locked")
    p.locked = false; #expect(!p.paused)
    p.asleep = true; #expect(p.paused)
    p.asleep = false; p.hidden = true; #expect(p.paused, "minimised: nothing on screen to animate")
    p.hidden = false; #expect(!p.paused)
}
