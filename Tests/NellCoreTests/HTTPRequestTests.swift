import Foundation
import Testing
@testable import NellCore

private func request(body: Data) -> Data {
    var d = Data("POST /hook?mode=code HTTP/1.1\r\nHost: nell\r\nContent-Type: application/x-www-form-urlencoded\r\nContent-Length: \(body.count)\r\n\r\n".utf8)
    d.append(body)
    return d
}

@Test func parseIncompleteThenComplete() {
    let body = Data(#"{"a":1}"#.utf8)
    let full = request(body: body)
    #expect(parseHTTPRequest(full.prefix(full.count - 3)) == .incomplete)
    guard case .complete(let r) = parseHTTPRequest(full) else { Issue.record("not complete"); return }
    #expect(r.path == "/hook")
    #expect(r.query["mode"] == "code")
    #expect(r.body == body)
}

@Test func parseLargeChunkedBody() {
    let body = Data(repeating: UInt8(ascii: "x"), count: 1_000_000)
    let full = request(body: body)
    var n = 65_536
    while n < full.count {
        #expect(parseHTTPRequest(full.prefix(n)) == .incomplete)
        n += 65_536
    }
    guard case .complete(let r) = parseHTTPRequest(full) else { Issue.record("not complete"); return }
    #expect(r.body == body)
}

@Test func parseGarbageIsInvalid() {
    #expect(parseHTTPRequest(Data("hello\r\n\r\n".utf8)) == .invalid)
}

private func head(_ contentLength: String) -> Data { Data("POST /hook?mode=code HTTP/1.1\r\nContent-Length: \(contentLength)\r\n\r\nxy".utf8) }

@Test func parseBadContentLengths() {
    #expect(parseHTTPRequest(head("-1")) == .invalid)
    #expect(parseHTTPRequest(head("99999999999999999999999")) == .invalid) // overflows Int
    #expect(parseHTTPRequest(head("\(Int.max)")) == .incomplete) // the server's 4 MB cap ends it
}

@Test func parseHeaderCapIs16KB() {
    #expect(parseHTTPRequest(Data(repeating: UInt8(ascii: "a"), count: 16_384)) == .incomplete)
    #expect(parseHTTPRequest(Data(repeating: UInt8(ascii: "a"), count: 16_385)) == .invalid)
}

@Test func parseWithoutQueryHasNoMode() {
    guard case .complete(let r) = parseHTTPRequest(Data("POST /hook HTTP/1.1\r\nContent-Length: 0\r\n\r\n".utf8)) else { Issue.record("not complete"); return }
    #expect(r.path == "/hook"); #expect(r.query["mode"] == nil)
}

@Test func responseHasLengthAndClose() {
    let s = String(decoding: httpResponse(body: Data("ok".utf8)), as: UTF8.self)
    #expect(s.hasPrefix("HTTP/1.1 200 OK\r\n"))
    #expect(s.contains("Content-Length: 2\r\n"))
    #expect(s.contains("Connection: close\r\n"))
    #expect(s.hasSuffix("\r\n\r\nok"))
}
