import CoreGraphics
import CoreText
import Foundation
import Testing
@testable import NellCore

let screen = CGRect(x: 0, y: 0, width: 1800, height: 1130)

/// AppDelegate's `consoleCell()`: one Departure Mono cell at kitty's 16.5 pt, from the bundled font.
let realCell: CGSize = {
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appending(path: "../../Sources/Nell/Resources/fonts/DepartureMono-Regular.otf")
    let d = (CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor])!.first!
    let f = CTFontCreateWithFontDescriptor(d, 16.5, nil)
    var g = CGGlyph(0), m = UniChar(77) // "M"
    CTFontGetGlyphsForCharacters(f, &m, &g, 1)
    let w = CTFontGetAdvancesForGlyphs(f, .horizontal, &g, nil, 1)
    return CGSize(width: ceil(w), height: ceil(CTFontGetAscent(f) + CTFontGetDescent(f) + CTFontGetLeading(f)))
}()

/// The app's real geometry: Nell's block, the bubble column, the console cell and chrome (ConsoleChrome 4 pt border, 24 pt title).
func input(_ origin: CGPoint, _ phase: ConsolePhase, screen s: CGRect = screen) -> LayoutInput {
    LayoutInput(screen: s, nellOrigin: origin, nellSize: NellBlock.size, columnSize: NellBlock.column,
                console: phase, cell: realCell, consoleChrome: CGSize(width: 8, height: 32), minimisedSize: NellBlock.minimised)
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

@Test func realCellIsDepartureMonoAt16_5() {
    #expect(realCell == CGSize(width: 11, height: 22), "the cell the red team measured in the app")
}

@Test func allFramesInsideScreenAcrossGrid() {
    // the laptop screen, a Dock-left screen, a Dock-bottom one, and a second display left of the primary
    let screens = [screen, CGRect(x: 80, y: 0, width: 1360, height: 875), CGRect(x: 0, y: 70, width: 1280, height: 705),
                   CGRect(x: -1920, y: 0, width: 1920, height: 1055)]
    for sc in screens {
      for phase in [ConsolePhase.hidden, .open, .minimised] {
        for x in stride(from: sc.minX - 100, through: sc.maxX, by: 50) {
            for y in stride(from: sc.minY - 100, through: sc.maxY, by: 50) {
                let l = layout(input(CGPoint(x: x, y: y), phase, screen: sc))
                for r in [l.nellFrame, l.columnFrame] + [l.consoleFrame, l.minimisedFrame].compactMap({ $0 }) {
                    #expect(inside(r, sc), "\(phase) at \(x),\(y): \(r)")
                }
                for c in [l.consoleFrame, l.minimisedFrame].compactMap({ $0 }) {
                    #expect(!c.intersects(l.nellFrame), "\(phase) at \(x),\(y)")
                    #expect(!c.intersects(l.columnFrame), "\(phase) at \(x),\(y)")
                }
                #expect(l.panelFrame.contains(l.nellFrame))
                #expect(l.columnFrame.height >= 80, "room for a pending approval")
                if phase == .open { #expect(l.consoleFrame != nil, "\(sc) at \(x),\(y): the console fits beside her") }
            }
        }
      }
    }
}

@Test func pendingApprovalVisibleWithConsoleOpen() {
    let l = layout(input(CGPoint(x: 1620, y: 16), .open))
    #expect(l.columnFrame.height >= 80)
}
