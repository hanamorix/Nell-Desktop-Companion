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

/// `tail` on a background thread; nil from the outer optional means it was still blocked after 1 s.
private func tailWithin1s(_ path: String) -> Data?? {
    let out = Box<Data?>(); let done = DispatchSemaphore(value: 0)
    Thread { out.add(ContextMeter.tail(of: URL(fileURLWithPath: path), maxBytes: 1 << 20)); done.signal() }.start()
    return done.wait(timeout: .now() + 1) == .success ? out.all.first : nil
}

@Test func tailOfRegularFileKeepsLastBytes() throws {
    let url = FileManager.default.temporaryDirectory.appending(path: "nt-tail-\(UUID().uuidString)")
    try Data("0123456789".utf8).write(to: url); defer { try? FileManager.default.removeItem(at: url) }
    #expect(ContextMeter.tail(of: url, maxBytes: 4) == Data("6789".utf8))
    #expect(ContextMeter.tail(of: url, maxBytes: 100) == Data("0123456789".utf8))
    #expect(ContextMeter.tail(of: url.appending(path: "missing"), maxBytes: 4) == nil)
}

@Test func tailOfFifoReturnsNilPromptly() {
    let path = FileManager.default.temporaryDirectory.appending(path: "nt-fifo-\(UUID().uuidString)").path
    #expect(mkfifo(path, 0o600) == 0); defer { unlink(path) }
    let r = tailWithin1s(path)
    #expect(r != nil, "still blocked"); #expect(r ?? nil == nil)
}

@Test func tailOfDeviceReturnsNilPromptly() {
    let r = tailWithin1s("/dev/zero") // endless: it must be refused, not read
    #expect(r != nil, "still reading"); #expect(r ?? nil == nil)
}

@Test func tokensSkipsSidechainAndPartialFirstLine() {
    let a = #"{"type":"assistant","isSidechain":false,"message":{"usage":{"input_tokens":1,"cache_read_input_tokens":2,"cache_creation_input_tokens":3}}}"#
    let side = #"{"type":"assistant","isSidechain":true,"message":{"usage":{"input_tokens":900}}}"#
    #expect(ContextMeter.tokens(fromTranscriptTail: Data(("ial\":1}\n" + a + "\n" + side).utf8)) == 6)
    #expect(ContextMeter.tokens(fromTranscriptTail: Data()) == nil)
}
