import Foundation

public struct HTTPRequest: Equatable, Sendable {
    public var path: String
    public var query: [String: String]
    public var body: Data
}

public enum HTTPParse: Equatable, Sendable { case incomplete, complete(HTTPRequest), invalid }

/// Parses one request; only what curl sends to Nell (request line, Content-Length, body).
public func parseHTTPRequest(_ buffer: Data) -> HTTPParse {
    let sep = Data("\r\n\r\n".utf8)
    guard let end = buffer.range(of: sep) else { return buffer.count > 16_384 ? .invalid : .incomplete }
    let head = String(decoding: buffer[buffer.startIndex..<end.lowerBound], as: UTF8.self)
    let lines = head.components(separatedBy: "\r\n")
    let parts = lines[0].split(separator: " ")
    guard parts.count == 3, parts[2].hasPrefix("HTTP/"), let comps = URLComponents(string: String(parts[1])) else { return .invalid }
    var length = 0
    for line in lines.dropFirst() {
        let kv = line.split(separator: ":", maxSplits: 1)
        if kv.count == 2, kv[0].lowercased() == "content-length" {
            guard let n = Int(kv[1].trimmingCharacters(in: .whitespaces)), n >= 0 else { return .invalid }
            length = n
        }
    }
    let bodyStart = end.upperBound
    guard buffer.count - (bodyStart - buffer.startIndex) >= length else { return .incomplete }
    let body = Data(buffer[bodyStart..<(bodyStart + length)])
    var query: [String: String] = [:]
    for item in comps.queryItems ?? [] { query[item.name] = item.value ?? "" }
    return .complete(HTTPRequest(path: comps.path, query: query, body: body))
}

public func httpResponse(body: Data) -> Data {
    var d = Data("HTTP/1.1 200 OK\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n".utf8)
    d.append(body)
    return d
}
