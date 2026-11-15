import CoreGraphics
import Foundation

/// An Aseprite "array" JSON export: frame rects + durations, tags, slices and layer names.
/// Tags: `body:`, `face:`, `between:`, `eyes:closed`, `paper:` and `emoji:`. Tag user data is whitespace-separated tokens.
public struct SpriteSheet: Sendable {
    public struct Frame: Sendable, Equatable { public let rect: CGRect; public let duration: TimeInterval }
    public let frames: [Frame]
    public let tags: [String: ClosedRange<Int>]
    /// Slice name → the frame each key starts at → bounds.
    public let slices: [String: [Int: CGRect]]
    public let layers: [String]
    private let tagData: [String: String]

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

    /// True when `frame` is in a tag marked `face=drawn` (yawning, sleeping and their in-betweens): no face or blink overlay.
    public func faceDrawn(frame: Int) -> Bool {
        tags.contains { $0.value.contains(frame) && tagData[$0.key]?.split(whereSeparator: \.isWhitespace).contains("face=drawn") == true }
    }

    /// What to draw, back to front, in sprite pixels (y down): the body frame, the face (or the closed eyes over it),
    /// the paper stack and the emoji. Overlay art sits at its slice's frame-0 key in its own frame and is drawn at the
    /// body frame's key, so it follows her breathing. `mirrored` turns her to face right; the emoji stays readable.
    public func blits(_ f: Animator.Frame, stacks: Int, emoji: Emoji?, mirrored: Bool) -> [Blit] {
        guard frames.indices.contains(f.body) else { return [] }
        let size = frames[f.body].rect.size
        var out = [Blit(src: frames[f.body].rect, dst: CGRect(origin: .zero, size: size), flipped: false)]
        func overlay(_ slice: String, frame: Int?) {
            guard let frame, frames.indices.contains(frame), let src = self.slice(slice, frame: 0),
                  let dst = self.slice(slice, frame: f.body) else { return }
            let o = frames[frame].rect.origin
            out.append(Blit(src: src.offsetBy(dx: o.x, dy: o.y), dst: CGRect(origin: dst.origin, size: src.size), flipped: false))
        }
        if !faceDrawn(frame: f.body) {
            if let src = slice("face", frame: 0), frames.indices.contains(f.face) {
                let o = frames[f.face].rect.origin
                out.append(Blit(src: src.offsetBy(dx: o.x, dy: o.y), dst: CGRect(origin: f.faceAt.origin, size: src.size), flipped: false))
            }
            if f.eyesClosed { overlay("eyes", frame: tag("eyes:closed")?.lowerBound) }
        }
        if stacks > 0 { overlay("paper", frame: tag("paper:\(min(stacks, 5))")?.lowerBound) }
        if let emoji { overlay("emoji", frame: tag("emoji:\(emoji.rawValue)")?.lowerBound) }
        guard mirrored else { return out }
        return out.enumerated().map { i, b in
            let isEmoji = emoji != nil && i == out.count - 1
            return Blit(src: b.src, dst: CGRect(x: size.width - b.dst.maxX, y: b.dst.minY, width: b.dst.width, height: b.dst.height), flipped: !isEmoji)
        }
    }
}

/// Copy `src` (sheet pixels) to `dst` (sprite pixels), mirrored left-right when `flipped`.
public struct Blit: Equatable, Sendable {
    public let src: CGRect
    public let dst: CGRect
    public let flipped: Bool
}

/// Clicks pass through Nell unless they land on something with a control, or on her sprite while ⌥ is held.
public func isInteractive(_ p: CGPoint, rects: [CGRect], grabRects: [CGRect], optionHeld: Bool) -> Bool {
    rects.contains { $0.contains(p) } || (optionHeld && grabRects.contains { $0.contains(p) })
}
