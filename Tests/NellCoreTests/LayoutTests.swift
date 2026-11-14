import CoreGraphics
import Testing
@testable import NellCore

let screen = CGRect(x: 0, y: 0, width: 1800, height: 1130)

func input(_ origin: CGPoint, _ phase: ConsolePhase, screen s: CGRect = screen) -> LayoutInput {
    LayoutInput(screen: s, nellOrigin: origin, nellSize: CGSize(width: 160, height: 200), columnSize: CGSize(width: 270, height: 300),
                console: phase, cell: CGSize(width: 7, height: 14), consoleChrome: CGSize(width: 12, height: 34),
                minimisedSize: CGSize(width: 320, height: 34))
}

func inside(_ r: CGRect, _ s: CGRect) -> Bool { s.insetBy(dx: -0.5, dy: -0.5).contains(r) }

@Test func bottomRightOpensLeft() throws {
    let l = layout(input(CGPoint(x: 1620, y: 16), .open))
    let c = try #require(l.consoleFrame)
    #expect(l.side == .left)
    #expect(c.maxX <= l.columnFrame.minX - 12)
    #expect(c.maxX <= l.nellFrame.minX - 12)
    #expect(c.minY == 16)
    #expect(l.faceRight == false)
    #expect(l.columnUp)
}

@Test func bottomLeftOpensRight() throws {
    let l = layout(input(CGPoint(x: 16, y: 16), .open))
    let c = try #require(l.consoleFrame)
    #expect(l.side == .right)
    #expect(c.minX >= l.columnFrame.maxX + 12)
    #expect(c.minX >= l.nellFrame.maxX + 12)
    #expect(l.faceRight)
}

@Test func topHalfColumnGoesDown() {
    let l = layout(input(CGPoint(x: 1620, y: 900), .hidden))
    #expect(l.columnUp == false)
    #expect(l.columnFrame.maxY <= l.nellFrame.minY + 0.5)
}

@Test func consoleCappedAt55x70() throws {
    var i = input(CGPoint(x: 820, y: 16), .open, screen: CGRect(x: 0, y: 0, width: 1000, height: 700))
    i.cell = CGSize(width: 20, height: 40) // wants 2012 x 1234
    let c = try #require(layout(i).consoleFrame)
    #expect(c.width <= 550)
    #expect(c.height <= 490)
}

@Test func narrowScreenShrinksNeverOverlaps() throws {
    let s = CGRect(x: 0, y: 0, width: 700, height: 700)
    let l = layout(input(CGPoint(x: 524, y: 16), .open, screen: s))
    let c = try #require(l.consoleFrame)
    #expect(!c.intersects(l.nellFrame))
    #expect(!c.intersects(l.columnFrame))
    #expect(inside(c, s))
}

@Test func minimisedOnlyWhenMinimised() throws {
    let open = layout(input(CGPoint(x: 1620, y: 16), .open))
    #expect(open.minimisedFrame == nil)
    let mini = layout(input(CGPoint(x: 1620, y: 16), .minimised))
    #expect(mini.consoleFrame == nil)
    let m = try #require(mini.minimisedFrame)
    #expect(m.maxX <= mini.columnFrame.minX - 12)
    #expect(layout(input(CGPoint(x: 1620, y: 16), .hidden)).minimisedFrame == nil)
}

@Test func allFramesInsideScreenAcrossGrid() {
    for phase in [ConsolePhase.hidden, .open, .minimised] {
        for x in stride(from: 0.0, through: 1800, by: 50) {
            for y in stride(from: 0.0, through: 1130, by: 50) {
                let l = layout(input(CGPoint(x: x, y: y), phase))
                for r in [l.nellFrame, l.columnFrame] + [l.consoleFrame, l.minimisedFrame].compactMap({ $0 }) {
                    #expect(inside(r, screen), "\(phase) at \(x),\(y): \(r)")
                }
                for c in [l.consoleFrame, l.minimisedFrame].compactMap({ $0 }) {
                    #expect(!c.intersects(l.nellFrame), "\(phase) at \(x),\(y)")
                    #expect(!c.intersects(l.columnFrame), "\(phase) at \(x),\(y)")
                }
                #expect(l.panelFrame.contains(l.nellFrame))
            }
        }
    }
}

@Test func pendingApprovalVisibleWithConsoleOpen() {
    let l = layout(input(CGPoint(x: 1620, y: 16), .open))
    #expect(l.columnFrame.height >= 80)
}
