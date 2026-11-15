import Foundation

/// One line per hook event and decision in Application Support/Nell/nell.log; restarted past 1 MB.
enum EventLog {
    nonisolated(unsafe) private static var url: URL?
    private static let lock = NSLock()

    static func start(_ u: URL) { url = u }

    static func write(_ line: String) {
        lock.lock(); defer { lock.unlock() }
        guard let url else { return }
        // one event, one line: a newline inside a tool name or error can't forge or split entries
        let flat = line.replacingOccurrences(of: "\n", with: "\\n").replacingOccurrences(of: "\r", with: "\\r")
        let data = Data("\(ISO8601DateFormatter().string(from: Date())) \(flat)\n".utf8)
        guard let h = try? FileHandle(forWritingTo: url) else { try? data.write(to: url); return } // no log yet
        defer { try? h.close() }
        // a log line that can't be written (disk full) has nowhere to be reported, and must never stop Nell
        guard let end = try? h.seekToEnd() else { return } // writing from offset 0 would overwrite the log's start
        if end > 1_000_000 { try? h.truncate(atOffset: 0) }
        try? h.write(contentsOf: data)
    }
}
