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

func v3Sheet() throws -> SpriteSheet {
    let url = try #require(Bundle.module.url(forResource: "sprite-v3-sample", withExtension: "json", subdirectory: "Fixtures"))
    return try SpriteSheet.parse(Data(contentsOf: url))
}

@Test func parsesSlicesWithPerFrameKeys() throws {
    let s = try v3Sheet()
    let still = CGRect(x: 40, y: 30, width: 48, height: 32), breath = CGRect(x: 40, y: 31, width: 48, height: 32)
    #expect(s.slices["face"]?.count == 5)
    #expect(s.slices["face"]?[2] == breath)
    #expect(s.slice("face", frame: 1) == still)
    #expect(s.slice("face", frame: 3) == breath, "latest key at or before the frame")
    #expect(s.slice("face", frame: 4) == still)
    #expect(s.slice("eyes", frame: 9) == CGRect(x: 44, y: 40, width: 40, height: 8))
    #expect(s.slice("emoji", frame: 22) == CGRect(x: 100, y: 4, width: 24, height: 24))
    #expect(s.slice("paper", frame: 21) == CGRect(x: 2, y: 96, width: 30, height: 30))
    #expect(s.slice("nope", frame: 0) == nil)
    #expect(s.tag("between:idle-typing") == 15...16)
    #expect(s.tag("eyes:closed") == 0...0)
    #expect(s.tag("face:happy") == 19...19)
    #expect(s.tag("paper:1") == 21...21)
    #expect(s.tag("emoji:heart") == 22...22)
    #expect(s.tag("between:typing-idle") == nil)
    #expect(s.layers == ["body", "face", "eyes", "paper", "emoji"])
    #expect(s.frames[1].duration == 0.2)
    #expect(!s.isPlaceholder)
    #expect(try placeholderSheet().slices.isEmpty)
}

@Test func restingFramesFromTagData() throws {
    let s = try v3Sheet()
    #expect(s.restingFrames(body: .idle) == [1, 4])      // body:idle 1...6, rest=0,3
    #expect(s.restingFrames(body: .typing) == [8, 10])   // body:typing 7...10, rest=1,3
    #expect(s.restingFrames(body: .yawning) == [11])     // no data: first frame only
    #expect(s.restingFrames(body: .sleeping) == [13])
    #expect(try placeholderSheet().restingFrames(body: .idle) == [])
}
