import Foundation

public struct ContextMeter: Sendable {
    private var tokens = 0
    public init() {}
    public mutating func update(tokens: Int) { self.tokens = tokens }
    public mutating func reset() { tokens = 0 }
    public var stacks: Int { min(5, tokens / 100_000) }

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
