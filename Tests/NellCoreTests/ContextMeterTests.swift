import Foundation
import Testing
@testable import NellCore

@Test func contextStacksCapAt5() {
    var m = ContextMeter()
    for (tokens, stacks) in [(0, 0), (99_999, 0), (100_000, 1), (250_000, 2), (900_000, 5)] {
        m.update(tokens: tokens); #expect(m.stacks == stacks)
    }
}

@Test func contextResetsOnClearAndCompaction() throws {
    var m = ContextMeter(); m.update(tokens: 300_000); m.reset(); #expect(m.stacks == 0)
    // After /compact the stale assistant usage is superseded by compact_boundary.postTokens.
    let data = try Data(contentsOf: try #require(Bundle.module.url(forResource: "transcript-usage", withExtension: "jsonl", subdirectory: "Fixtures")))
    m.update(tokens: try #require(ContextMeter.tokens(fromTranscriptTail: data))); #expect(m.stacks == 0)
}

@Test func tokensFromTranscriptFixture() throws {
    let data = try Data(contentsOf: try #require(Bundle.module.url(forResource: "transcript-usage", withExtension: "jsonl", subdirectory: "Fixtures")))
    #expect(ContextMeter.tokens(fromTranscriptTail: data) == 15_645) // fixture ends with a compact_boundary
    let lines = String(decoding: data, as: UTF8.self).split(separator: "\n").dropLast()
    #expect(ContextMeter.tokens(fromTranscriptTail: Data(lines.joined(separator: "\n").utf8)) == 2 + 207 + 56_167)
}

@Test func tokensSkipsSidechainAndPartialFirstLine() {
    let a = #"{"type":"assistant","isSidechain":false,"message":{"usage":{"input_tokens":1,"cache_read_input_tokens":2,"cache_creation_input_tokens":3}}}"#
    let side = #"{"type":"assistant","isSidechain":true,"message":{"usage":{"input_tokens":900}}}"#
    #expect(ContextMeter.tokens(fromTranscriptTail: Data(("ial\":1}\n" + a + "\n" + side).utf8)) == 6)
    #expect(ContextMeter.tokens(fromTranscriptTail: Data()) == nil)
}
