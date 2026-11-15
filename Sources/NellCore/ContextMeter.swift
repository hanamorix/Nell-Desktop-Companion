import Foundation

public struct ContextMeter: Sendable {
    private var tokens = 0
    public init() {}
    public mutating func update(tokens: Int) { self.tokens = tokens }
    public mutating func reset() { tokens = 0 }
    public var stacks: Int { min(5, tokens / 100_000) }

    /// The last `maxBytes` of a file (the whole file if smaller), or nil if it can't be read.
    public static func tail(of url: URL, maxBytes: Int) -> Data? {
        guard let h = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? h.close() }
        guard let end = try? h.seekToEnd() else { return nil }
        try? h.seek(toOffset: end > UInt64(maxBytes) ? end - UInt64(maxBytes) : 0)
        return try? h.readToEnd() ?? Data()
    }

    /// Last non-sidechain assistant usage; a later `compact_boundary` supersedes it with `postTokens`
    /// (the usage is stale until the next turn). The first line of a tail may be cut off: unparsable lines are skipped.
    public static func tokens(fromTranscriptTail data: Data) -> Int? {
        var result: Int?
        for line in data.split(separator: UInt8(ascii: "\n")) {
            guard let o = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else { continue }
            if o["type"] as? String == "assistant", o["isSidechain"] as? Bool != true,
               let u = (o["message"] as? [String: Any])?["usage"] as? [String: Any] {
                result = ["input_tokens", "cache_read_input_tokens", "cache_creation_input_tokens"].reduce(0) { $0 + (u[$1] as? Int ?? 0) }
            } else if o["type"] as? String == "system", o["subtype"] as? String == "compact_boundary",
                      let post = (o["compactMetadata"] as? [String: Any])?["postTokens"] as? Int {
                result = post
            }
        }
        return result
    }
}
