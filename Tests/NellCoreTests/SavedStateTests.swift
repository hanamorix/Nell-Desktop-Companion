import Foundation
import Testing
@testable import NellCore

@Test func savedStateRoundTrips() throws {
    let url = URL(fileURLWithPath: tmpSocket()).deletingLastPathComponent().appending(path: "state.json")
    var s = SavedState()
    s.projectDir = "/Users/x/My Proj"; s.codeSessionId = "c"; s.chatSessionId = "h"; s.positions["1"] = CGPoint(x: 10, y: 20)
    try s.save(url)
    #expect(SavedState.load(url) == s)
}

@Test func corruptStateFileLoadsDefault() throws {
    let url = URL(fileURLWithPath: tmpSocket()).deletingLastPathComponent().appending(path: "state.json")
    try Data("{nope".utf8).write(to: url)
    #expect(SavedState.load(url) == SavedState())
    #expect(SavedState.load(url.appending(path: "missing")) == SavedState())
}
