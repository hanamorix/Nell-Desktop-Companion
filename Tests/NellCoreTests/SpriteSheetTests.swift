import CoreGraphics
import Foundation
import Testing
@testable import NellCore

func placeholderSheet() throws -> SpriteSheet {
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appending(path: "../../Sources/Nell/Resources/sprites/nell.json")
    return try SpriteSheet.parse(Data(contentsOf: url))
}

@Test func parsesPlaceholderSheet() throws {
    let s = try placeholderSheet()
    #expect(s.frames.count == 4)
    #expect(s.tags["typing"] == 0...3)
    #expect(s.frames[2].rect == CGRect(x: 780, y: 0, width: 390, height: 395))
    #expect(s.frames[0].duration == 0.15)
    #expect(s.frames(for: .typing).count == 4)
    #expect(s.frames(for: .needsYou).count == 1)
    for st in NellState.allCases { #expect(s.tags[st.rawValue] != nil, "\(st)") }
}

@Test func missingTagFallsBackToIdle() throws {
    let json = #"{"frames":[{"frame":{"x":0,"y":0,"w":8,"h":8},"duration":100},{"frame":{"x":8,"y":0,"w":8,"h":8},"duration":100}],"meta":{"frameTags":[{"name":"idle","from":1,"to":1}]}}"#
    let s = try SpriteSheet.parse(Data(json.utf8))
    #expect(s.frames(for: .error).map(\.rect.minX) == [8])
    #expect(s.isPlaceholder == false)
    #expect(try placeholderSheet().isPlaceholder)
}

@Test func buttonsAlwaysInteractive() {
    let rects = [CGRect(x: 0, y: 0, width: 10, height: 10), CGRect(x: 50, y: 50, width: 5, height: 5)]
    #expect(isInteractive(CGPoint(x: 5, y: 5), rects: rects, grabRects: [], optionHeld: false))
    #expect(isInteractive(CGPoint(x: 52, y: 52), rects: rects, grabRects: [], optionHeld: true))
    #expect(!isInteractive(CGPoint(x: 20, y: 20), rects: rects, grabRects: [], optionHeld: true))
}

@Test func spriteOnlyInteractiveWithOption() {
    let sprite = [CGRect(x: 100, y: 100, width: 40, height: 40)]
    #expect(!isInteractive(CGPoint(x: 110, y: 110), rects: [], grabRects: sprite, optionHeld: false))
    #expect(isInteractive(CGPoint(x: 110, y: 110), rects: [], grabRects: sprite, optionHeld: true))
    #expect(!isInteractive(CGPoint(x: 10, y: 10), rects: [], grabRects: sprite, optionHeld: true))
}
