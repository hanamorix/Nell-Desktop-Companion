import CoreGraphics
import Foundation

/// Decides which sprite frames to draw. Faces change only behind a blink; body loops change only on a resting frame,
/// through the drawn in-between when there is one. Each timeline moves at most one step per tick, so no state is skipped.
public struct Animator: Sendable {
    public struct Frame: Equatable, Sendable {
        public let body: Int
        public let face: Int
        public let faceAt: CGRect
        public let eyesClosed: Bool
    }

    public static let blinkDuration: TimeInterval = 0.12

    private let sheet: SpriteSheet
    private var rng: SplitMix64
    private var body = Body.idle, target = Body.idle
    private var face = Face.idle, pendingFace: Face?
    private var frame: Int
    private var between: (to: Body, last: Int)?
    private var frameStart: Date?
    private var nextBlink = Date.distantFuture, blinkEnd: Date?
    private var quiet = false
    private var last: Frame?

    public init(sheet: SpriteSheet, seed: UInt64) {
        self.sheet = sheet
        rng = SplitMix64(state: seed)
        frame = sheet.tag("body:idle")?.lowerBound ?? 0
    }

    /// Repeating the current body and face does nothing.
    public mutating func request(body: Body, face: Face, now: Date) {
        start(now)
        target = body
        pendingFace = face == self.face ? nil : face
    }

    /// The frame to draw, or nil when nothing visible changed since the last one returned.
    public mutating func tick(now: Date, quiet: Bool) -> Frame? {
        guard !sheet.frames.isEmpty else { return nil }
        start(now)
        self.quiet = quiet
        if let due = bodyDue, now >= due { frame = nextFrame(); frameStart = now }

        // A face drawn into the body (yawning, sleeping) hides the face and the blink: hold the swap until it shows.
        let swap = pendingFace != nil && !sheet.faceDrawn(frame: frame)
        if let end = blinkEnd {
            if now >= end {
                if swap { blinkEnd = now + Self.blinkDuration }  // stay closed for the new face
                else { blinkEnd = nil; nextBlink = now + blinkInterval() }
            }
        } else if now >= nextBlink || swap {
            blinkEnd = now + Self.blinkDuration
        }
        if blinkEnd != nil, swap, let f = pendingFace { face = f; pendingFace = nil }

        let faceFrame = (sheet.tag("face:\(face.rawValue)") ?? sheet.tag("face:idle"))?.lowerBound ?? 0
        let f = Frame(body: frame, face: faceFrame, faceAt: sheet.slice("face", frame: frame) ?? .zero, eyesClosed: blinkEnd != nil)
        if f == last { return nil }
        last = f
        return f
    }

    /// When the next tick can return a frame, so the caller can sleep until then.
    public var nextChange: Date {
        guard frameStart != nil, pendingFace == nil || sheet.faceDrawn(frame: frame) else { return .distantPast }
        return min(bodyDue ?? .distantFuture, blinkEnd ?? nextBlink)
    }

    private mutating func start(_ now: Date) {
        guard frameStart == nil else { return }
        frameStart = now
        nextBlink = now + blinkInterval()
    }

    private var resting: Bool {
        let rest = sheet.restingFrames(body: body)
        return between == nil && (rest.isEmpty || rest.contains(frame))
    }

    /// End of the current body frame; nil while quiet holds a resting frame with no change pending.
    private var bodyDue: Date? {
        guard let s = frameStart, !(quiet && resting && target == body) else { return nil }
        return s + sheet.frames[frame].duration
    }

    private func loop(_ b: Body) -> ClosedRange<Int> { sheet.tag("body:\(b.rawValue)") ?? 0...0 }

    private mutating func nextFrame() -> Int {
        if let b = between {
            if frame < b.last { return frame + 1 }
            body = b.to
            between = nil
            return loop(body).lowerBound
        }
        if resting && target != body {
            if let r = sheet.tag("between:\(body.rawValue)-\(target.rawValue)") {
                between = (target, r.upperBound)
                return r.lowerBound
            }
            body = target
            return loop(body).lowerBound
        }
        let r = loop(body)
        return r.contains(frame + 1) ? frame + 1 : r.lowerBound
    }

    private mutating func blinkInterval() -> TimeInterval {
        quiet ? .random(in: 8...15, using: &rng) : .random(in: 3...6, using: &rng)
    }
}

/// SplitMix64: a tiny seeded generator so blink timing is reproducible in tests.
struct SplitMix64: RandomNumberGenerator, Sendable {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
