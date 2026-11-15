import AppKit
import ImageIO
import NellCore
import SwiftUI

/// Runs the animator and composes Nell's 128 px frame. It wakes only when the animator, the pose or an overlay changes,
/// and not at all while the screen is locked or asleep.
@MainActor final class SpriteDriver: ObservableObject {
    @Published private(set) var image: CGImage?
    var paused = false { didSet { if paused != oldValue { tick() } } }
    var mirrored = false { didSet { if mirrored != oldValue { redraw() } } }

    let sheet: SpriteSheet
    /// The alpha of the frame on screen, so a click on her drawn pixels is hers and a gap clicks through. Built only when
    /// the pointer asks, not on every frame.
    var mask: SpriteMask? {
        if maskCache == nil, let image { maskCache = SpriteMask(image: image) }
        return maskCache
    }
    private var maskCache: SpriteMask?
    private let sheetImage: CGImage
    private var animator: Animator
    private var frame: Animator.Frame?
    private var pose: (body: Body, face: Face)?
    private var emoji: Emoji?
    private var stacks = 0
    private var lastEvent = Date()
    private var timer: Timer?

    init(sheet: SpriteSheet, image: CGImage) {
        self.sheet = sheet; sheetImage = image
        animator = Animator(sheet: sheet, seed: .random(in: 0 ... .max))
        tick()
    }

    /// Repeating the current pose and overlays does nothing.
    func show(body: Body, face: Face, emoji: Emoji?, stacks: Int) {
        let overlays = emoji != self.emoji || stacks != self.stacks
        self.emoji = emoji; self.stacks = stacks
        if pose?.body != body || pose?.face != face {
            pose = (body, face)
            animator.request(body: body, face: face, now: Date())
            tick(redraw: overlays)
        } else if overlays { redraw() }
    }

    /// Any hook event ends a long quiet spell.
    func eventArrived() {
        let wasQuiet = isQuiet(Date())
        lastEvent = Date()
        if wasQuiet { tick() }
    }

    private func isQuiet(_ now: Date) -> Bool { now >= lastEvent + Timings.longQuiet }

    /// Draw if the animator has a new frame, then sleep until its next change (or until quiet begins).
    private func tick(redraw force: Bool = false) {
        timer?.invalidate(); timer = nil
        guard !paused else { return }
        let now = Date(), quiet = isQuiet(now)
        if let f = animator.tick(now: now, quiet: quiet) { frame = f; redraw() } else if force { redraw() }
        var next = animator.nextChange // .distantPast means "tick now": the timer fires on the next run-loop turn
        if !quiet { next = min(next, lastEvent + Timings.longQuiet) } // tick once when quiet flips on
        guard next != .distantFuture else { return }
        let t = Timer(fire: max(next, now), interval: 0, repeats: false) { [weak self] _ in MainActor.assumeIsolated { self?.tick() } }
        t.tolerance = 0.005
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func redraw() {
        guard let f = frame else { return }
        let size = sheet.frames[f.body].rect.size
        guard let ctx = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0,
                                  space: sheetImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
        ctx.interpolationQuality = .none
        for b in sheet.blits(f, stacks: stacks, emoji: emoji, mirrored: mirrored) {
            guard let part = sheetImage.cropping(to: b.src) else { continue }
            let r = CGRect(x: b.dst.minX, y: size.height - b.dst.maxY, width: b.dst.width, height: b.dst.height) // CG is y-up
            ctx.saveGState()
            if b.flipped { ctx.translateBy(x: 2 * r.midX, y: 0); ctx.scaleBy(x: -1, y: 1) }
            ctx.draw(part, in: r)
            ctx.restoreGState()
        }
        image = ctx.makeImage()
        maskCache = nil
    }
}

/// Nell at exactly 2×, nearest-neighbour: 1 art pixel = 2 pt.
struct SpriteCompositor: View {
    @ObservedObject var driver: SpriteDriver
    var body: some View {
        Group {
            if let img = driver.image { Image(decorative: img, scale: 1).resizable().interpolation(.none) } else { Color.clear }
        }
        .frame(width: 256, height: 256)
        .accessibilityElement()
        .accessibilityLabel("Nell")
    }
}

func loadSprites() -> (SpriteSheet, CGImage)? {
    guard let json = try? Data(contentsOf: resourceURL("sprites/nell.json")),
          let sheet = try? SpriteSheet.parse(json),
          let src = CGImageSourceCreateWithURL(resourceURL("sprites/nell.png") as CFURL, nil),
          let lazy = CGImageSourceCreateImageAtIndex(src, 0, nil), let img = decodedBitmap(lazy)
    else { return nil }
    return (sheet, img)
}
