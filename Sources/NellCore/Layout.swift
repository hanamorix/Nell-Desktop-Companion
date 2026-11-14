import CoreGraphics

public enum ConsolePhase: Equatable, Sendable { case hidden, open, minimised }
public enum Side: Equatable, Sendable { case left, right }

/// Everything in AppKit screen coordinates (y up).
public struct LayoutInput: Sendable {
    public var screen: CGRect          // the display's visibleFrame
    public var nellOrigin: CGPoint     // bottom-left of the sprite + chips + bar block
    public var nellSize: CGSize
    public var columnSize: CGSize      // the bubble column at its tallest
    public var console: ConsolePhase
    public var cell: CGSize            // one console cell, in points
    public var consoleChrome: CGSize   // title strip + borders added around the cells
    public var minimisedSize: CGSize
    public init(screen: CGRect, nellOrigin: CGPoint, nellSize: CGSize, columnSize: CGSize, console: ConsolePhase,
                cell: CGSize, consoleChrome: CGSize, minimisedSize: CGSize) {
        self.screen = screen; self.nellOrigin = nellOrigin; self.nellSize = nellSize; self.columnSize = columnSize
        self.console = console; self.cell = cell; self.consoleChrome = consoleChrome; self.minimisedSize = minimisedSize
    }
}

public struct Layout: Equatable, Sendable {
    public var panelFrame: CGRect      // Nell's window: everything below plus room for tails
    public var nellFrame: CGRect
    public var columnFrame: CGRect
    public var consoleFrame: CGRect?
    public var minimisedFrame: CGRect?
    public var side: Side
    public var columnUp: Bool
    public var faceRight: Bool
}

enum LayoutRule {
    static let margin: CGFloat = 16, gap: CGFloat = 12, tail: CGFloat = 6
    static let cells = CGSize(width: 100, height: 30)
    static let maxWidth: CGFloat = 0.55, maxHeight: CGFloat = 0.70
}

/// Places Nell, her bubble column and the console so nothing overlaps and everything stays on screen.
public func layout(_ i: LayoutInput) -> Layout {
    let m = LayoutRule.margin, gap = LayoutRule.gap
    let s = i.screen.insetBy(dx: m, dy: m)

    var nell = CGRect(origin: i.nellOrigin, size: i.nellSize)
    nell.origin.x = min(max(nell.minX, s.minX), s.maxX - nell.width)
    nell.origin.y = min(max(nell.minY, s.minY), s.maxY - nell.height)

    let side: Side = nell.midX - i.screen.minX > i.screen.maxX - nell.midX ? .left : .right
    let columnUp = nell.midY < i.screen.midY

    // The column hangs off Nell's edge facing away from the console, and stays on screen.
    let cw = min(i.columnSize.width, s.width)
    var cx = side == .left ? nell.maxX - cw : nell.minX
    cx = min(max(cx, s.minX), s.maxX - cw)
    let room = columnUp ? s.maxY - nell.maxY : nell.minY - s.minY
    let ch = max(0, min(i.columnSize.height, room))
    let column = CGRect(x: cx, y: columnUp ? nell.maxY : nell.minY - ch, width: cw, height: ch)

    // The free strip beside Nell and her column, on the console's side.
    let leftLimit = side == .left ? s.minX : max(nell.maxX, column.maxX) + gap
    let rightLimit = side == .left ? min(nell.minX, column.minX) - gap : s.maxX
    func beside(_ size: CGSize) -> CGRect? {
        let w = min(size.width, rightLimit - leftLimit), h = min(size.height, s.height)
        guard w >= 1, h >= 1 else { return nil }
        let x = side == .left ? rightLimit - w : leftLimit
        let y = min(max(nell.minY, s.minY), s.maxY - h)
        return CGRect(x: x, y: y, width: w, height: h)
    }

    var console: CGRect?, minimised: CGRect?
    switch i.console {
    case .open:
        let want = CGSize(width: LayoutRule.cells.width * i.cell.width + i.consoleChrome.width,
                          height: LayoutRule.cells.height * i.cell.height + i.consoleChrome.height)
        console = beside(CGSize(width: min(want.width, i.screen.width * LayoutRule.maxWidth),
                                height: min(want.height, i.screen.height * LayoutRule.maxHeight)))
    case .minimised:
        minimised = beside(i.minimisedSize)
    case .hidden:
        break
    }

    let all = [nell, column] + [console, minimised].compactMap { $0 }
    let panel = all.dropFirst().reduce(all[0]) { $0.union($1) }.insetBy(dx: -LayoutRule.tail, dy: -LayoutRule.tail)
    return Layout(panelFrame: panel, nellFrame: nell, columnFrame: column, consoleFrame: console, minimisedFrame: minimised,
                  side: side, columnUp: columnUp, faceRight: side == .right)
}
