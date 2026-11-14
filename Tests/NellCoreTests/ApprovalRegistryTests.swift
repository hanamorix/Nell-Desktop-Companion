import Foundation
import Testing
@testable import NellCore

@Test func twoPendingAnswerOneLeavesOther() {
    let r = ApprovalRegistry()
    r.register(id: "a"); r.register(id: "b")
    #expect(r.answer(id: "a", .allow))
    #expect(r.wait(id: "a", timeout: 1) == .allow)
    #expect(r.pendingIds == ["b"])
    #expect(r.wait(id: "b", timeout: 0.1) == .none)
}

@Test func closedConnectionSettlesAsNoneNotDeny() {
    let r = ApprovalRegistry()
    r.register(id: "a")
    r.closed(id: "a")
    #expect(r.wait(id: "a", timeout: 1) == .none)
}

@Test func answerAfterCloseIsIgnored() {
    let r = ApprovalRegistry()
    r.register(id: "a")
    r.closed(id: "a")
    #expect(!r.answer(id: "a", .allow))
    #expect(r.wait(id: "a", timeout: 1) == .none)
}

@Test func waitBlocksUntilAnsweredFromAnotherThread() {
    let r = ApprovalRegistry()
    r.register(id: "a")
    DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) { _ = r.answer(id: "a", .deny) }
    #expect(r.wait(id: "a", timeout: 5) == .deny)
}

@Test func responseBodies() {
    #expect(approvalResponseBody(.none).isEmpty)
    let s = String(decoding: approvalResponseBody(.allow), as: UTF8.self)
    #expect(s == #"{"hookSpecificOutput":{"decision":{"behavior":"allow"},"hookEventName":"PermissionRequest"}}"#)
    #expect(String(decoding: approvalResponseBody(.deny), as: UTF8.self).contains(#""behavior":"deny""#))
}
