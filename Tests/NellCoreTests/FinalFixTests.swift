import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import NellCore

// MARK: Body changes never cut straight across

private func tagOf(_ s: SpriteSheet, _ frame: Int) -> String {
    s.tags.filter { ($0.key.hasPrefix("body:") || $0.key.hasPrefix("between:")) && $0.value.contains(frame) }.map(\.key).first ?? "?"
}

/// Ticks at each `nextChange` until `stop` holds for the frame shown, recording every body frame shown.
private func run(_ a: inout Animator, _ now: inout Date, _ shown: inout [Int], until stop: (Int) -> Bool) -> Bool {
    for _ in 0..<2000 {
        let next = a.nextChange
        now = next > now ? next : now.addingTimeInterval(0.01)
        if let f = a.tick(now: now, quiet: false) {
            if shown.last != f.body { shown.append(f.body) }
            if stop(f.body) { return true }
        }
    }
    return false
}

@Test func everyBodyChangeGoesThroughADrawnInBetween() throws {
    let s = try realSheet()
    let all: [Body] = [.idle, .typing, .yawning, .sleeping]
    for from in all {
        for to in all where to != from {
            var a = Animator(sheet: s, seed: 3), now = Date(timeIntervalSinceReferenceDate: 0), shown: [Int] = []
            _ = a.tick(now: now, quiet: false)
            a.request(body: from, face: .idle, now: now)
            let home = try #require(s.tag("body:\(from.rawValue)"))
            #expect(run(&a, &now, &shown) { home.contains($0) && s.restingFrames(body: from).contains($0) }, "\(from) settles")
            shown = [shown.last!]
            a.request(body: to, face: .idle, now: now)
            let goal = try #require(s.tag("body:\(to.rawValue)"))
            #expect(run(&a, &now, &shown) { goal.contains($0) }, "\(from)→\(to) arrives")
            for (x, y) in zip(shown, shown.dropFirst()) {
                let tx = tagOf(s, x), ty = tagOf(s, y)
                if tx == ty { continue }
                if ty.hasPrefix("between:") {
                    let src = "body:" + String(ty.dropFirst(8).split(separator: "-")[0])
                    #expect(tx == src && y == s.tag(ty)!.lowerBound
                            && s.restingFrames(body: Body(rawValue: String(tx.dropFirst(5)))!).contains(x),
                            "\(from)→\(to): \(tx) frame \(x) → \(ty) frame \(y) starts an in-between from a resting frame")
                } else if tx.hasPrefix("between:") {
                    #expect(ty == "body:" + String(tx.split(separator: "-").last!), "\(from)→\(to): \(tx) lands in \(ty)")
                } else {
                    // a straight cut between two loops: only between identical resting poses, from a resting frame
                    let bx = Body(rawValue: String(tx.dropFirst(5)))!, by = Body(rawValue: String(ty.dropFirst(5)))!
                    #expect(Animator.seamless.contains([bx, by]) && s.restingFrames(body: bx).contains(x) && y == s.tag(ty)!.lowerBound,
                            "\(from)→\(to): cuts straight from \(tx) frame \(x) to \(ty) frame \(y)")
                }
            }
        }
    }
}

/// The straight switches the animator allows really are invisible: the resting poses are pixel-identical.
@Test func seamlessPairsHaveIdenticalRestingPoses() throws {
    let s = try realSheet()
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appending(path: "../../Sources/Nell/Resources/sprites/nell.png")
    let src = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
    let sheet = try #require(CGImageSourceCreateImageAtIndex(src, 0, nil))
    let decoded = try #require(decodedBitmap(sheet))
    func pixels(_ frame: Int) throws -> [UInt8] {
        let cell = try #require(decoded.cropping(to: s.frames[frame].rect))
        var buf = [UInt8](repeating: 0, count: 128 * 128 * 4)
        buf.withUnsafeMutableBytes { b in
            CGContext(data: b.baseAddress, width: 128, height: 128, bitsPerComponent: 8, bytesPerRow: 128 * 4,
                      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?
                .draw(cell, in: CGRect(x: 0, y: 0, width: 128, height: 128))
        }
        return buf
    }
    for pair in Animator.seamless {
        for a in s.restingFrames(body: pair[0]) { for b in s.restingFrames(body: pair[1]) {
            #expect(try pixels(a) == pixels(b), "\(pair[0]) rest \(a) vs \(pair[1]) rest \(b)")
        } }
    }
}

// MARK: Minors

@Test func usageLimitBubbleIsFriendly() {
    var e = HookEvent(name: "StopFailure", sessionId: "S"); e.error = "rate_limit"
    #expect(stopFailureMessage(e) == "Usage limit reached — Nell's napping until it resets")
    e.lastAssistantMessage = "You've hit your session limit · resets 3:45pm"
    #expect(stopFailureMessage(e) == "Usage limit reached — Nell's napping until it resets at 3:45pm")
    e.lastAssistantMessage = "You've hit your weekly limit · resets Mon 12:00am"
    #expect(stopFailureMessage(e) == "Usage limit reached — Nell's napping until it resets at Mon 12:00am")
    var other = HookEvent(name: "StopFailure", sessionId: "S"); other.error = "server_error"
    #expect(stopFailureMessage(other) == "server_error")
    #expect(stopFailureMessage(HookEvent(name: "StopFailure", sessionId: "S")) == "Something went wrong")
}

@Test func anyPNGExportDecodes() throws {
    let gray = try #require(CGContext(data: nil, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceGray(),
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue))
    gray.setFillColor(gray: 0.5, alpha: 1); gray.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
    let img = try #require(gray.makeImage())
    let out = try #require(decodedBitmap(img), "a grey export still loads")
    #expect(out.colorSpace?.name == CGColorSpace.sRGB)
    #expect(out.width == 4 && out.bitsPerPixel == 32)
}
