import Foundation
import Testing
@testable import NellCore

@Test func burstKeepsHighestPriority() {
    var r = ReactionState()
    r.flash(.heart, now: at(0)); r.flash(.thumbsup, now: at(0.2)); r.flash(.crying, now: at(0.4))
    #expect(r.current(now: at(1)) == .crying)
    r.setHeld(.warning, true)
    #expect(r.current(now: at(1)) == .warning)
    r.setHeld(.warning, false)
    #expect(r.current(now: at(1)) == .crying)
    #expect(r.current(now: at(5)) == nil)
}

@Test func briefEmojiExpiresAfter2_5s() {
    var r = ReactionState(); r.flash(.heart, now: at(0))
    #expect(r.current(now: at(2.49)) == .heart)
    #expect(r.current(now: at(2.5)) == nil)
}

@Test func heldEmojiStaysUntilReleased() {
    var r = ReactionState(); r.setHeld(.plug, true); r.setHeld(.question, true)
    #expect(r.current(now: at(10_000)) == .question)
    r.setHeld(.question, false); #expect(r.current(now: at(10_000)) == .plug)
    r.setHeld(.plug, false); #expect(r.current(now: at(10_000)) == nil)
}

@Test func emojiPriorityOrder() {
    #expect(Emoji.allCases == [.warning, .question, .plug, .alert, .crying, .heart, .thumbsup])
    #expect(Emoji.warning < .thumbsup)
}

@Test func bodyPriorities() {
    let idle = started().stopped()
    var typing = started(); typing.handle(ev("PreToolUse", tool: "Bash", input: bash, id: "a"), requestId: nil, now: at(1))
    var testing = started(); testing.handle(ev("PreToolUse", tool: "Bash", input: ["command": .string("swift test")], id: "b"), requestId: nil, now: at(1))
    var limited = started()
    limited.handle(HookEvent(name: "StopFailure", sessionId: "S", toolName: nil, toolInput: nil, toolUseId: nil, prompt: nil,
                             message: nil, notificationType: nil, lastAssistantMessage: nil, error: "rate_limit"), requestId: nil, now: at(1))
    #expect(body(code: limited, chat: testing, selected: .code) == .sleeping)
    #expect(body(code: idle, chat: limited, selected: .code) == .sleeping)
    #expect(body(code: testing, chat: idle, selected: .code) == .yawning)
    #expect(body(code: typing, chat: idle, selected: .code) == .typing)
    #expect(body(code: idle, chat: idle, selected: .code) == .idle)
    #expect(body(code: idle, chat: typing, selected: .code) == .idle)
    #expect(body(code: idle, chat: typing, selected: .chat) == .typing)
    #expect(body(code: idle, chat: testing, selected: .code) == .idle) // yawning is Code-only
}

@Test func faceFollowsEmojiThenBody() {
    #expect(face(body: .idle, emoji: .heart) == .happy)
    #expect(face(body: .typing, emoji: .thumbsup) == .smile)
    #expect(face(body: .idle, emoji: .crying) == .sad)
    #expect(face(body: .sleeping, emoji: .warning) == .scared)
    #expect(face(body: .idle, emoji: nil) == .idle)
    #expect(face(body: .typing, emoji: .plug) == .intent)
    #expect(face(body: .yawning, emoji: nil) == .exhausted)
    #expect(face(body: .sleeping, emoji: .question) == .exhausted)
}

private extension SessionTracker {
    func stopped() -> SessionTracker { var t = self; t.handle(ev("Stop"), requestId: nil, now: at(1)); t.tick(now: at(10)); return t }
}

@Test func tiredFaceOnlyWhenIdle() {
    #expect(face(body: .idle, emoji: nil, tired: true) == .exhausted)
    #expect(face(body: .typing, emoji: nil, tired: true) == .intent)
    #expect(face(body: .idle, emoji: .heart, tired: true) == .happy)
    #expect(face(body: .idle, emoji: nil) == .idle)
}
