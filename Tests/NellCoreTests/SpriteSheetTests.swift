import CoreGraphics
import Foundation
import Testing
@testable import NellCore

func realSheet() throws -> SpriteSheet {
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appending(path: "../../Sources/Nell/Resources/sprites/nell.json")
    return try SpriteSheet.parse(Data(contentsOf: url))
}

/// The committed export of artwork/sprites/nell-master.aseprite (scripts/export-sprite.sh).
@Test func parsesRealExport() throws {
    let s = try realSheet()
    #expect(s.frames.count == 64)
    #expect(s.frames.allSatisfy { $0.rect.size == CGSize(width: 128, height: 128) })
    #expect(s.frames[9].rect.origin == CGPoint(x: 128, y: 128), "8 frames per row")
    for (i, f) in ["idle", "intent", "exhausted", "happy", "smile", "sad", "scared", "awe"].enumerated() { #expect(s.tag("face:\(f)") == i...i) }
    #expect(s.tag("eyes:closed") == 8...8)
    #expect(s.tag("body:idle") == 9...16)
    #expect(s.tag("body:typing") == 17...24)
    #expect(s.tag("body:yawning") == 25...32)
    #expect(s.tag("body:sleeping") == 37...41)
    #expect(s.tag("between:typing-yawning") == 33...34)
    #expect(s.tag("between:yawning-typing") == 35...36)
    #expect(s.tag("between:idle-sleeping") == 42...44)
    #expect(s.tag("between:typing-sleeping") == 45...47)
    #expect(s.tag("between:sleeping-idle") == 48...51)
    #expect(s.tag("between:idle-typing") == nil, "resting frames are identical: direct switch")
    for n in 1...5 { #expect(s.tag("paper:\(n)") == (51 + n)...(51 + n)) }
    for (i, e) in Emoji.allCases.enumerated() { #expect(s.tag("emoji:\(e.rawValue)") == (57 + i)...(57 + i)) }
    #expect(s.restingFrames(body: .idle) == [9, 13])
    #expect(s.restingFrames(body: .typing) == [17, 19])
    #expect(s.restingFrames(body: .yawning) == [25, 29])
    #expect(s.restingFrames(body: .sleeping) == [37, 41])
    #expect(s.slice("paper", frame: 0) == CGRect(x: 90, y: 74, width: 34, height: 34))
    #expect(s.slice("face", frame: 0) == CGRect(x: 42, y: 36, width: 48, height: 35))
    #expect(s.slice("face", frame: 11) == CGRect(x: 42, y: 35, width: 48, height: 35), "follows her breathing")
    #expect(s.slice("eyes", frame: 11) == CGRect(x: 44, y: 43, width: 45, height: 19))
    #expect(s.slice("emoji", frame: 37) == CGRect(x: 28, y: 38, width: 16, height: 16), "moves down while sleeping")
    #expect(s.layers == ["chair", "body", "desk", "laptop", "head", "face", "eyes", "props"])
}

@Test func faceDrawnFromTagData() throws {
    let s = try realSheet()
    for f in 0...24 { #expect(!s.faceDrawn(frame: f), "\(f)") }
    for f in 25...51 { #expect(s.faceDrawn(frame: f), "\(f)") }  // yawning, sleeping and all their in-betweens
    #expect(!s.faceDrawn(frame: 52))
    #expect(!s.faceDrawn(frame: 999))
    let json = #"{"frames":[{"frame":{"x":0,"y":0,"w":8,"h":8},"duration":100}],"meta":{"frameTags":[{"name":"body:idle","from":0,"to":0,"data":"face=drawnish rest=0"}]}}"#
    #expect(!(try SpriteSheet.parse(Data(json.utf8))).faceDrawn(frame: 0), "whole tokens only")
}

@Test func buttonsAlwaysInteractive() {
    let rects = [CGRect(x: 0, y: 0, width: 10, height: 10), CGRect(x: 50, y: 50, width: 5, height: 5)]
    #expect(isInteractive(CGPoint(x: 5, y: 5), rects: rects, grabRects: [], optionHeld: false, opaqueAt: { _ in false }))
    #expect(isInteractive(CGPoint(x: 52, y: 52), rects: rects, grabRects: [], optionHeld: true, opaqueAt: { _ in false }))
    #expect(!isInteractive(CGPoint(x: 20, y: 20), rects: rects, grabRects: [], optionHeld: true, opaqueAt: { _ in false }))
}

@Test func spriteOnlyInteractiveWithOption() {
    let sprite = [CGRect(x: 100, y: 100, width: 40, height: 40)]
    #expect(!isInteractive(CGPoint(x: 110, y: 110), rects: [], grabRects: sprite, optionHeld: false, opaqueAt: { _ in false }))
    #expect(isInteractive(CGPoint(x: 110, y: 110), rects: [], grabRects: sprite, optionHeld: true, opaqueAt: { _ in false }))
    #expect(!isInteractive(CGPoint(x: 10, y: 10), rects: [], grabRects: sprite, optionHeld: true, opaqueAt: { _ in false }))
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
}

@Test func restingFramesFromTagData() throws {
    let s = try v3Sheet()
    #expect(s.restingFrames(body: .idle) == [1, 4])      // body:idle 1...6, rest=0,3
    #expect(s.restingFrames(body: .typing) == [8, 10])   // body:typing 7...10, rest=1,3
    #expect(s.restingFrames(body: .yawning) == [11])     // no data: first frame only
    #expect(s.restingFrames(body: .sleeping) == [13])
}
