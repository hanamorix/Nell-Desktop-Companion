import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import NellCore

private let face = CGRect(x: 42, y: 36, width: 48, height: 35) // the face slice's frame-0 key in the real export

// MARK: Bottom row (option A: bar under her desk, chips stacked on the chair side)

/// The bar spans her desk: the widest opaque run on the idle frame's desk-top rows, at 2×.
@Test func deskSpanMatchesTheArt() throws {
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appending(path: "../../Sources/Nell/Resources/sprites/nell.png")
    let src = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
    let img = try #require(CGImageSourceCreateImageAtIndex(src, 0, nil))
    let frame = try realSheet().frames[9].rect // body:idle's first frame
    let cell = try #require(img.cropping(to: frame))
    let ctx = try #require(CGContext(data: nil, width: 128, height: 128, bitsPerComponent: 8, bytesPerRow: 128 * 4,
                                     space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    ctx.draw(cell, in: CGRect(x: 0, y: 0, width: 128, height: 128))
    let px = try #require(ctx.data).assumingMemoryBound(to: UInt8.self)
    var lo = 128, hi = -1
    for y in 104...117 { for x in 0..<128 where px[(y * 128 + x) * 4 + 3] > 0 { lo = min(lo, x); hi = max(hi, x) } } // desk top to underside
    #expect(NellBlock.desk == CGFloat(lo * 2)...CGFloat((hi + 1) * 2))
}

@Test func barSpansTheDeskAndSitsUnderHer() {
    for mirrored in [false, true] {
        let bar = NellBlock.bar(mirrored: mirrored), x = NellBlock.spriteX(mirrored: mirrored)
        #expect(bar.width == NellBlock.desk.upperBound - NellBlock.desk.lowerBound)
        #expect(bar.minX == x + (mirrored ? NellBlock.sprite - NellBlock.desk.upperBound : NellBlock.desk.lowerBound))
        #expect(bar.height == NellBlock.barHeight && bar.maxY == NellBlock.size.height)
        #expect(bar.minY >= NellBlock.sprite, "directly under the sprite")
    }
}

@Test func chipsStackOnTheChairSide() {
    let chip = CGSize(width: 38, height: 30)
    for mirrored in [false, true] {
        let c = NellBlock.chips(chip, mirrored: mirrored)
        let sprite = CGRect(x: NellBlock.spriteX(mirrored: mirrored), y: 0, width: NellBlock.sprite, height: NellBlock.sprite)
        #expect(c.code.maxY == NellBlock.bar(mirrored: mirrored).maxY, "code chip's bottom on the bar row")
        #expect(c.chat.maxY + NellBlock.chipGap == c.code.minY)
        #expect(c.chat.minX == c.code.minX)
        for r in [c.chat, c.code] {
            #expect(!r.intersects(sprite), "never over her pixels")
            #expect(CGRect(origin: .zero, size: NellBlock.size).contains(r))
            #expect(mirrored ? r.maxX <= sprite.minX : r.minX >= sprite.maxX, "chair side: right unless mirrored")
        }
    }
}

@Test func headFromTheFaceSlice() {
    #expect(NellBlock.head(faceSlice: face, mirrored: false) == CGPoint(x: 132, y: 107))
    #expect(NellBlock.head(faceSlice: face, mirrored: true) == CGPoint(x: 64 + 124, y: 107))
}

@Test func minimisedStripSharesTheBarRow() throws {
    for origin in [CGPoint(x: 1400, y: 16), CGPoint(x: 16, y: 16), CGPoint(x: 700, y: 500)] {
        let l = layout(LayoutInput(screen: screen, nellOrigin: origin, nellSize: NellBlock.size, columnSize: CGSize(width: 270, height: 320),
                                   console: .minimised, cell: CGSize(width: 10, height: 21), consoleChrome: CGSize(width: 8, height: 32),
                                   minimisedSize: CGSize(width: 340, height: NellBlock.barHeight)))
        let strip = try #require(l.minimisedFrame)
        let bar = NellBlock.bar(mirrored: l.faceRight) // y-down in the block; the block's bottom is nellFrame.minY on screen
        #expect(strip.minY == l.nellFrame.minY + (NellBlock.size.height - bar.maxY))
        #expect(strip.height == bar.height)
    }
}

// MARK: Tails

private func layoutWith(columnUp: Bool) -> Layout {
    Layout(panelFrame: .zero, nellFrame: .zero, columnFrame: .zero, consoleFrame: nil, minimisedFrame: nil, side: .left, columnUp: columnUp, faceRight: false)
}

@Test func tailEdgeFacesHer() {
    let b = CGRect(x: 0, y: 0, width: 200, height: 40)
    #expect(tailAnchor(bubble: b, layout: layoutWith(columnUp: true), headX: 50).edge == .bottom)
    #expect(tailAnchor(bubble: b, layout: layoutWith(columnUp: false), headX: 50).edge == .top)
}

@Test func tailPointsAtHerHeadWithinTheBubble() {
    let l = layoutWith(columnUp: true), b = CGRect(x: 40, y: 0, width: 200, height: 40)
    let mid = tailAnchor(bubble: b, layout: l, headX: 100)
    #expect(mid.leansLeft && mid.tipX == 60, "tip right under her head")
    let farLeft = tailAnchor(bubble: b, layout: l, headX: 0)
    #expect(farLeft.leansLeft && farLeft.tipX == TailRule.inset, "clamped 14 pt from the end")
    let farRight = tailAnchor(bubble: b, layout: l, headX: 900)
    #expect(!farRight.leansLeft && farRight.tipX == 200 - TailRule.inset, "leans right, tip 14 pt from the end")
    let nearRight = tailAnchor(bubble: b, layout: l, headX: 40 + 190)
    #expect(!nearRight.leansLeft && nearRight.tipX == 186)
    let narrow = tailAnchor(bubble: CGRect(x: 0, y: 0, width: 30, height: 20), layout: l, headX: 0)
    #expect(narrow.tipX >= 0 && narrow.tipX + TailRule.width <= 30, "a tiny bubble still holds its whole tail")
}

@Test func nellsBubblesSitOverHerHead() {
    #expect(bubbleX(width: 100, columnWidth: 270, headX: 132, mine: false) == 132 - TailRule.inset)
    #expect(bubbleX(width: 100, columnWidth: 270, headX: 5, mine: false) == 0)
    #expect(bubbleX(width: 100, columnWidth: 270, headX: 260, mine: false) == 170)
    #expect(bubbleX(width: 300, columnWidth: 270, headX: 132, mine: false) == 0)
}

@Test func yourBubblesStayOnTheFarSide() {
    #expect(bubbleX(width: 60, columnWidth: 270, headX: 82, mine: true) == 210, "head on the left: right-aligned")
    #expect(bubbleX(width: 60, columnWidth: 270, headX: 188, mine: true) == 0, "head on the right: left-aligned")
}

// MARK: Right-click on her pixels

@Test func spriteMaskHitsOnlyDrawnPixels() {
    var alpha = [UInt8](repeating: 0, count: 4 * 4); alpha[1 * 4 + 2] = 255 // art pixel (2, 1)
    let m = SpriteMask(width: 4, height: 4, alpha: alpha)
    #expect(m.opaque(at: CGPoint(x: 4.5, y: 2.5), scale: 2))
    #expect(!m.opaque(at: CGPoint(x: 3.9, y: 2.5), scale: 2))
    #expect(!m.opaque(at: CGPoint(x: -1, y: 2), scale: 2))
    #expect(!m.opaque(at: CGPoint(x: 100, y: 2), scale: 2))
}

@Test func spritePixelsTakeClicksWithoutOption() {
    let sprite = [CGRect(x: 100, y: 100, width: 40, height: 40)]
    let solid: (CGPoint) -> Bool = { $0.x < 20 } // local point: left half drawn
    #expect(isInteractive(CGPoint(x: 110, y: 110), rects: [], grabRects: sprite, optionHeld: false, opaqueAt: solid))
    #expect(!isInteractive(CGPoint(x: 130, y: 110), rects: [], grabRects: sprite, optionHeld: false, opaqueAt: solid), "a gap clicks through")
    #expect(isInteractive(CGPoint(x: 130, y: 110), rects: [], grabRects: sprite, optionHeld: true, opaqueAt: solid), "⌥ grabs the whole box")
    #expect(!isInteractive(CGPoint(x: 10, y: 10), rects: [], grabRects: sprite, optionHeld: true, opaqueAt: solid))
}
