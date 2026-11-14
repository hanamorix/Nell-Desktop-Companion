import CoreGraphics
import Foundation

/// An Aseprite "array" JSON export: frame rects + durations, and one tag per NellState raw value.
public struct SpriteSheet: Sendable {
    public struct Frame: Sendable, Equatable { public let rect: CGRect; public let duration: TimeInterval }
    public let frames: [Frame]
    public let tags: [String: ClosedRange<Int>]

    /// shortcut: frames wider than 128 px are the smooth concept placeholder; switch to a meta flag once real pixel art lands.
    public var isPlaceholder: Bool { (frames.first?.rect.width ?? 0) > 128 }

    public static func parse(_ json: Data) throws -> SpriteSheet {
        struct R: Decodable { let x, y, w, h: Double }
        struct F: Decodable { let frame: R; let duration: Double }
        struct T: Decodable { let name: String; let from: Int; let to: Int }
        struct M: Decodable { let frameTags: [T] }
        struct File: Decodable { let frames: [F]; let meta: M }
        let f = try JSONDecoder().decode(File.self, from: json)
        let frames = f.frames.map { Frame(rect: CGRect(x: $0.frame.x, y: $0.frame.y, width: $0.frame.w, height: $0.frame.h), duration: $0.duration / 1000) }
        var tags: [String: ClosedRange<Int>] = [:]
        for t in f.meta.frameTags where t.from <= t.to && t.to < frames.count { tags[t.name] = t.from...t.to }
        return SpriteSheet(frames: frames, tags: tags)
    }

    public func frames(for state: NellState) -> [Frame] {
        guard let r = tags[state.rawValue] ?? tags[NellState.idle.rawValue] else { return Array(frames.prefix(1)) }
        return Array(frames[r])
    }
}

/// Clicks pass through Nell unless they land on something with a control, or on her sprite while ⌥ is held.
public func isInteractive(_ p: CGPoint, rects: [CGRect], grabRects: [CGRect], optionHeld: Bool) -> Bool {
    rects.contains { $0.contains(p) } || (optionHeld && grabRects.contains { $0.contains(p) })
}
