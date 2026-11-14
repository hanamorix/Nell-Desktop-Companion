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
    #expect(q.release() == ["one", "two"])
    #expect(q.count == 0)
    #expect(q.submit("three", held: false) == "three")
}

@Test func emptyOrWhitespaceIgnored() {
    var q = InputQueue()
    #expect(q.submit("  \n ", held: false) == nil)
    #expect(q.submit("", held: true) == nil)
    #expect(q.count == 0)
    #expect(q.submit(" keep my spaces ", held: false) == " keep my spaces ")
}
