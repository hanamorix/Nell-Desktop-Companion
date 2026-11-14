import CoreGraphics
import Foundation

/// An Aseprite "array" JSON export: frame rects + durations, tags, slices and layer names.
/// The concept placeholder uses NellState-named tags; v3 art uses `body:`, `face:`, `between:`, `eyes:closed`, `paper:` and `emoji:` tags.
public struct SpriteSheet: Sendable {
    public struct Frame: Sendable, Equatable { public let rect: CGRect; public let duration: TimeInterval }
    public let frames: [Frame]
    public let tags: [String: ClosedRange<Int>]
    /// Slice name → the frame each key starts at → bounds.
    public let slices: [String: [Int: CGRect]]
    public let layers: [String]
    private let tagData: [String: String]

    /// shortcut: frames wider than 128 px are the smooth concept placeholder; switch to a meta flag once real pixel art lands.
    public var isPlaceholder: Bool { (frames.first?.rect.width ?? 0) > 128 }

    public static func parse(_ json: Data) throws -> SpriteSheet {
        struct R: Decodable { let x, y, w, h: Double; var rect: CGRect { CGRect(x: x, y: y, width: w, height: h) } }
        struct F: Decodable { let frame: R; let duration: Double }
        struct T: Decodable { let name: String; let from: Int; let to: Int; let data: String? }
        struct K: Decodable { let frame: Int; let bounds: R }
        struct S: Decodable { let name: String; let keys: [K] }
        struct L: Decodable { let name: String }
        struct M: Decodable { let frameTags: [T]; let slices: [S]?; let layers: [L]? }
        struct File: Decodable { let frames: [F]; let meta: M }
        let f = try JSONDecoder().decode(File.self, from: json)
        let frames = f.frames.map { Frame(rect: $0.frame.rect, duration: $0.duration / 1000) }
        var tags: [String: ClosedRange<Int>] = [:], data: [String: String] = [:]
        for t in f.meta.frameTags where t.from <= t.to && t.to < frames.count { tags[t.name] = t.from...t.to; data[t.name] = t.data }
        var slices: [String: [Int: CGRect]] = [:]
        for s in f.meta.slices ?? [] { for k in s.keys { slices[s.name, default: [:]][k.frame] = k.bounds.rect } }
        return SpriteSheet(frames: frames, tags: tags, slices: slices, layers: f.meta.layers?.map(\.name) ?? [], tagData: data)
    }

    public func frames(for state: NellState) -> [Frame] {
        guard let r = tags[state.rawValue] ?? tags[NellState.idle.rawValue] else { return Array(frames.prefix(1)) }
        return Array(frames[r])
    }

    public func tag(_ name: String) -> ClosedRange<Int>? { tags[name] }

    /// Bounds from the latest key at or before `frame`.
    public func slice(_ name: String, frame: Int) -> CGRect? {
        slices[name]?.filter { $0.key <= frame }.max { $0.key < $1.key }?.value
    }

    /// Absolute frames named by the `body:` tag's user data `rest=i,j` (offsets from its first frame); else its first frame.
    public func restingFrames(body: Body) -> [Int] {
        let name = "body:\(body.rawValue)"
        guard let r = tags[name] else { return [] }
        let rest = tagData[name]?.split(whereSeparator: \.isWhitespace).first { $0.hasPrefix("rest=") }?
            .dropFirst(5).split(separator: ",").compactMap { Int($0) }.map { r.lowerBound + $0 }.filter(r.contains) ?? []
        return rest.isEmpty ? [r.lowerBound] : rest
    }
}

/// Clicks pass through Nell unless they land on something with a control, or on her sprite while ⌥ is held.
public func isInteractive(_ p: CGPoint, rects: [CGRect], grabRects: [CGRect], optionHeld: Bool) -> Bool {
    rects.contains { $0.contains(p) } || (optionHeld && grabRects.contains { $0.contains(p) })
}
