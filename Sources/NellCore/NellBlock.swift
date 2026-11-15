import CoreGraphics

/// Nell's block (sprite, bar and chips), in block-local points with y down. Option A from the user's review:
/// the bar spans her desk under the sprite; the Chat and Code chips stack in the corner on the chair side.
public enum NellBlock {
    public static let size = CGSize(width: 320, height: 296)
    /// The 128 px sprite at exactly 2×.
    public static let sprite: CGFloat = 256
    /// One 14 pt Departure Mono line + 6 + 10 padding + 4 frame.
    public static let barHeight: CGFloat = 34
    /// Her desk in sprite points: on the idle frame's desk-top rows (104–117) the desk runs from art x 2 to 125.
    public static let desk: ClosedRange<CGFloat> = 4...252
    public static let chipGap: CGFloat = 8

    /// The sprite sits against the laptop side; the free strip on the chair side holds the chips.
    public static func spriteX(mirrored: Bool) -> CGFloat { mirrored ? size.width - sprite : 0 }

    public static func bar(mirrored: Bool) -> CGRect {
        let lo = mirrored ? sprite - desk.upperBound : desk.lowerBound
        return CGRect(x: spriteX(mirrored: mirrored) + lo, y: size.height - barHeight, width: desk.upperBound - desk.lowerBound, height: barHeight)
    }

    /// Code chip's bottom on the bar row, Chat chip above it, both centred in the strip beside her (behind her chair).
    public static func chips(_ chip: CGSize, mirrored: Bool) -> (chat: CGRect, code: CGRect) {
        let strip = mirrored ? 0...spriteX(mirrored: true) : sprite...size.width
        let x = ((strip.lowerBound + strip.upperBound - chip.width) / 2).rounded()
        let code = CGRect(x: x, y: size.height - chip.height, width: chip.width, height: chip.height)
        return (code.offsetBy(dx: 0, dy: -chip.height - chipGap), code)
    }

    /// Her head: the face slice's centre at 2×, mirrored with the sprite.
    public static func head(faceSlice f: CGRect, mirrored: Bool) -> CGPoint {
        let x = f.midX * 2
        return CGPoint(x: spriteX(mirrored: mirrored) + (mirrored ? sprite - x : x), y: f.midY * 2)
    }
}

public enum TailRule {
    /// The tail stays this far from either end of its bubble.
    public static let inset: CGFloat = 14
    /// The tail art is 6 px at 2×; its tip is its outer column.
    public static let width: CGFloat = 12
    /// Room kept on the tail's edge so the column never clips it.
    public static let room: CGFloat = 10
}

public struct TailAnchor: Equatable, Sendable {
    public enum Edge: Sendable { case top, bottom }
    public var edge: Edge
    /// The tip's x from the bubble's left edge. The tail spans tipX…tipX+width when it leans left, else tipX−width…tipX.
    public var tipX: CGFloat
    public var leansLeft: Bool
}

/// Where a bubble's tail goes so it points at her head: the edge facing her, the tip as near her head's x as the bubble
/// allows. `bubble` and `headX` share one horizontal coordinate space (the column's).
public func tailAnchor(bubble: CGRect, layout: Layout, headX: CGFloat) -> TailAnchor {
    let leansLeft = headX < bubble.midX
    let w = TailRule.width, lo = TailRule.inset + (leansLeft ? 0 : w), hi = bubble.width - TailRule.inset - (leansLeft ? w : 0)
    let tip = lo <= hi ? min(max(headX - bubble.minX, lo), hi)
        : (bubble.width + (leansLeft ? -w : w)) / 2 // too narrow for the insets: centre the tail
    return TailAnchor(edge: layout.columnUp ? .bottom : .top, tipX: tip, leansLeft: leansLeft)
}

/// A bubble's leading x in the column. Nell's sit so their tail can land over her head; yours stay on the far side.
public func bubbleX(width: CGFloat, columnWidth: CGFloat, headX: CGFloat, mine: Bool) -> CGFloat {
    let room = max(0, columnWidth - width)
    if mine { return headX < columnWidth / 2 ? room : 0 }
    return min(max(headX - TailRule.inset, 0), room)
}

/// The composited frame's alpha, so only her drawn pixels take clicks.
public struct SpriteMask: Sendable {
    public let width: Int, height: Int
    public let alpha: [UInt8]
    public init(width: Int, height: Int, alpha: [UInt8]) { self.width = width; self.height = height; self.alpha = alpha }

    /// `p` in points from the sprite's top-left, `scale` points per art pixel.
    public func opaque(at p: CGPoint, scale: CGFloat) -> Bool {
        guard p.x >= 0, p.y >= 0 else { return false }
        let x = Int(p.x / scale), y = Int(p.y / scale)
        return x < width && y < height && alpha[y * width + x] > 0
    }
}
