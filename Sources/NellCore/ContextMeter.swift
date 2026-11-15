import Foundation

public struct ContextMeter: Sendable {
    private var tokens = 0
    public init() {}
    public mutating func update(tokens: Int) { self.tokens = tokens }
    public mutating func reset() { tokens = 0 }
    public var stacks: Int { min(5, tokens / 100_000) }

    /// The last `maxBytes` of a regular file (the whole file if smaller), or nil if it can't be read.
    /// The path comes off the socket: non-blocking so a FIFO can't hang the open, regular files only so a device can't stream forever.
    public static func tail(of url: URL, maxBytes: Int) -> Data? {
        let fd = open(url.path, O_RDONLY | O_NONBLOCK)
        guard fd >= 0 else { return nil }
        let h = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        var st = stat()
        guard fstat(fd, &st) == 0, st.st_mode & S_IFMT == S_IFREG, let end = try? h.seekToEnd(),
              (try? h.seek(toOffset: end > UInt64(maxBytes) ? end - UInt64(maxBytes) : 0)) != nil else { return nil }
        return try? h.read(upToCount: maxBytes) ?? Data()
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
