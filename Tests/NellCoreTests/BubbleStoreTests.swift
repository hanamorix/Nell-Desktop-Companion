import Foundation
import Testing
@testable import NellCore

@Test func approvalNeverFadesUntilSettled() {
    var b = BubbleStore()
    b.add(.approval(requestId: "r1"), mode: .code, text: "Wants to run `ls`", now: t0)
    b.tick(now: at(1000), userIdle: 0, hovered: nil)
    #expect(b.visible(now: at(1000)).first?.opacity == 1)
    b.settle(requestId: "r1", as: "Allowed")
    #expect(b.bubbles.first?.settled == true)
    #expect(b.bubbles.first?.text.hasSuffix("Allowed") == true)
    b.tick(now: at(1001), userIdle: 0, hovered: nil)
    #expect(b.visible(now: at(1001 + Timings.bubbleVisible + Timings.bubbleFade)).isEmpty)
}

@Test func fadeWaitsForUserActivity() {
    var b = BubbleStore()
    b.add(.reply, mode: .chat, text: "Hello", now: t0)
    b.tick(now: at(500), userIdle: 400, hovered: nil)
    #expect(b.visible(now: at(500)).count == 1)
    b.tick(now: at(501), userIdle: 1, hovered: nil)
    #expect(b.visible(now: at(501 + Timings.chatReplyVisible - 1)).first?.opacity == 1)
    #expect(b.visible(now: at(501 + Timings.chatReplyVisible + Timings.bubbleFade)).isEmpty)
}

@Test func hoverPausesFade() {
    var b = BubbleStore()
    b.add(.user, mode: .code, text: "hi", now: t0)
    let id = b.bubbles[0].id
    b.tick(now: at(19), userIdle: 0, hovered: id)
    #expect(b.visible(now: at(30)).first?.opacity == 1)
}

@Test func onlyFourVisibleWithDescendingOpacity() {
    var b = BubbleStore()
    for i in 0..<6 { b.add(.user, mode: .code, text: "m\(i)", now: at(Double(i))) }
    let v = b.visible(now: at(6))
    #expect(v.map(\.bubble.text) == ["m2", "m3", "m4", "m5"])
    #expect(v.map(\.opacity) == [0.12, 0.3, 0.55, 1.0])
}

@Test func statusBubbleReplacedNotStacked() {
    var b = BubbleStore()
    b.setStatus(mode: .code, text: "Reading a.ts", now: t0)
    b.setStatus(mode: .code, text: "Editing a.ts", now: at(1))
    b.setStatus(mode: .chat, text: "Thinking", now: at(1))
    #expect(b.bubbles.map(\.text) == ["Editing a.ts", "Thinking"])
    b.clearStatus(mode: .code)
    #expect(b.bubbles.map(\.text) == ["Thinking"])
}

@Test func codeReplyTruncatedChatReplyWhole() {
    var b = BubbleStore()
    let long = "1\n2\n3\n4\n5"
    b.add(.reply, mode: .code, text: long, now: t0)
    b.add(.reply, mode: .chat, text: long, now: t0)
    #expect(b.bubbles[0].text == "1\n2\n3\n…more in ⌘")
    #expect(b.bubbles[1].text == long)
}

@Test func questionSettlesByMode() {
    var b = BubbleStore()
    b.add(.question, mode: .code, text: "Cats or dogs?", now: t0)
    b.settleQuestions(mode: .chat)
    #expect(b.bubbles[0].settled == false)
    b.settleQuestions(mode: .code)
    #expect(b.bubbles[0].settled == true)
}

@Test func hoveredPendingApprovalStays() {
    var b = BubbleStore()
    b.add(.approval(requestId: "r1"), mode: .code, text: "Wants to run `ls`", now: t0)
    let id = b.bubbles[0].id
    b.tick(now: at(1), userIdle: 0, hovered: id)
    b.tick(now: at(100), userIdle: 0, hovered: nil)
    #expect(b.visible(now: at(100)).first?.opacity == 1)
}

@Test func pendingApprovalSurvivesNewerBubbles() {
    var b = BubbleStore()
    b.add(.approval(requestId: "r1"), mode: .code, text: "Wants to run `ls`", now: t0)
    for i in 0..<5 { b.add(.user, mode: .code, text: "m\(i)", now: at(Double(i + 1))) }
    let v = b.visible(now: at(6))
    let approval = v.first { $0.bubble.kind == .approval(requestId: "r1") }
    #expect(approval?.opacity == 1)
    #expect(v.count <= Timings.maxVisibleBubbles + 1)
}
