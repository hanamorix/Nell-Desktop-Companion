import Foundation

/// One line per hook event and decision in Application Support/Nell/nell.log; restarted past 1 MB.
enum EventLog {
    nonisolated(unsafe) private static var url: URL?
    private static let lock = NSLock()

    static func start(_ u: URL) {
        url = u
        if ((try? FileManager.default.attributesOfItem(atPath: u.path)[.size] as? Int) ?? 0) > 1_000_000 { try? FileManager.default.removeItem(at: u) }
    }

    static func write(_ line: String) {
        lock.lock(); defer { lock.unlock() }
        guard let url else { return }
        let data = Data("\(ISO8601DateFormatter().string(from: Date())) \(line)\n".utf8)
        if let h = try? FileHandle(forWritingTo: url) { h.seekToEndOfFile(); h.write(data); try? h.close() }
        else { try? data.write(to: url) }
    }
}
