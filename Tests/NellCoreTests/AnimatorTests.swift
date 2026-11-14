import CoreGraphics
import Foundation
import Testing
@testable import NellCore

// Fixture frame indices: body:idle 1...6 (rest 1, 4), body:typing 7...10, body:yawning 11...12,
// between:idle-typing 15...16, face:idle 17, face:happy 19, face:sad 20.
private func at(_ ms: Int) -> Date { Date(timeIntervalSinceReferenceDate: Double(ms) / 1000) }
private typealias Run = [(ms: Int, f: Animator.Frame)]

/// Ticks every 10 ms over [from, to) and keeps the frames that were returned.
private func run(_ a: inout Animator, _ from: Int, _ to: Int, quiet: Bool = false) -> Run {
    stride(from: from, to: to, by: 10).compactMap { ms in a.tick(now: at(ms), quiet: quiet).map { (ms, $0) } }
}

/// Body frames in the order they appeared.
private func bodies(_ r: Run) -> [Int] {
    r.map(\.f.body).reduce(into: []) { if $0.last != $1 { $0.append($1) } }
}

/// Milliseconds from each reopen to the next blink.
private func blinkGaps(_ r: Run) -> [Int] {
    var gaps: [Int] = [], opened: Int?
    for (p, c) in zip(r, r.dropFirst()) {
        if p.f.eyesClosed && !c.f.eyesClosed { opened = c.ms }
        if !p.f.eyesClosed && c.f.eyesClosed, let o = opened { gaps.append(c.ms - o) }
    }
    return gaps
}

@Test func faceSwapsOnlyBehindBlink() throws {
    var a = Animator(sheet: try v3Sheet(), seed: 1)
    let first = a.tick(now: at(0), quiet: false)
    var prev = try #require(first)
    #expect(prev.face == 17 && !prev.eyesClosed)

    a.request(body: .idle, face: .happy, now: at(1000))
    let swapped = a.tick(now: at(1000), quiet: false)
    let swap = try #require(swapped)
    #expect(swap.face == 19 && swap.eyesClosed, "a pending face starts a blink straight away")
    #expect(a.tick(now: at(1110), quiet: false) == nil)
    let reopened = a.tick(now: at(1120), quiet: false)
    #expect(reopened?.eyesClosed == false && reopened?.face == 19, "the blink lasts 120 ms")
    prev = try #require(reopened)

    let faces: [Face] = [.sad, .idle, .intent, .happy]
    var swaps = 0
    for ms in stride(from: 1130, to: 30_000, by: 10) {
        if ms % 700 == 0 { a.request(body: .idle, face: faces[(ms / 700) % 4], now: at(ms)) }
        guard let f = a.tick(now: at(ms), quiet: false) else { continue }
        if f.face != prev.face { swaps += 1; #expect(f.eyesClosed, "face changed with eyes open at \(ms) ms") }
        prev = f
    }
    #expect(swaps > 30)
}

@Test func latestFaceRequestWins() throws {
    var a = Animator(sheet: try v3Sheet(), seed: 1)
    _ = a.tick(now: at(0), quiet: false)
    a.request(body: .idle, face: .happy, now: at(500))
    a.request(body: .idle, face: .sad, now: at(510))
    let r = run(&a, 520, 2000)
    #expect(r.first?.f.face == 20 && r.first?.f.eyesClosed == true)
    #expect(!r.contains { $0.f.face == 19 }, "the superseded face never shows")

    a.request(body: .idle, face: .happy, now: at(2000))
    a.request(body: .idle, face: .sad, now: at(2005))  // back to the current face: nothing pending
    #expect(!run(&a, 2010, 2500).contains { $0.f.eyesClosed })
}

@Test func bodyChangeWaitsForRestingFrameThenInBetween() throws {
    var a = Animator(sheet: try v3Sheet(), seed: 1)
    let before = run(&a, 0, 250)
    #expect(before.map(\.f.body) == [1, 2])
    #expect(before.map(\.f.faceAt.minY) == [30, 31], "the face slice follows the breath")
    a.request(body: .typing, face: .idle, now: at(250))  // on frame 2, which is not a resting frame
    #expect(Array(bodies(run(&a, 250, 1500)).prefix(7)) == [3, 4, 15, 16, 7, 8, 9])
}

@Test func missingInBetweenCutsAtRestingFrame() throws {
    var a = Animator(sheet: try v3Sheet(), seed: 1)
    _ = run(&a, 0, 250)
    a.request(body: .yawning, face: .exhausted, now: at(250))
    // Frame 2 shows again first: the new face's blink is drawn on it.
    #expect(Array(bodies(run(&a, 250, 2000)).prefix(6)) == [2, 3, 4, 11, 12, 11])
}

@Test func quietStopsBreathingAndSlowsBlinks() throws {
    let sheet = try v3Sheet()
    var a = Animator(sheet: sheet, seed: 7)
    _ = run(&a, 0, 250)
    let quiet = run(&a, 250, 120_000, quiet: true)
    #expect(bodies(quiet) == [3, 4], "plays on to the resting frame, then holds it")
    let slow = blinkGaps(quiet)
    #expect(slow.count >= 6)
    for g in slow { #expect((8000...15_010).contains(g), "quiet blink gap \(g) ms") }
    #expect(bodies(run(&a, 120_000, 121_000)).count > 1, "breathing resumes when quiet ends")

    var b = Animator(sheet: sheet, seed: 7)
    let busy = run(&b, 0, 60_000)
    let fast = blinkGaps(busy)
    #expect(fast.count >= 8)
    for g in fast { #expect((3000...6010).contains(g), "blink gap \(g) ms") }
    var c = Animator(sheet: sheet, seed: 7)
    let again = run(&c, 0, 60_000)
    #expect(again.map(\.ms) == busy.map(\.ms) && again.map(\.f) == busy.map(\.f), "same seed, same blinks")
}

@Test func tickReturnsNilWhenNothingChanges() throws {
    var a = Animator(sheet: try v3Sheet(), seed: 1)
    #expect(a.tick(now: at(0), quiet: false) != nil)
    #expect(a.tick(now: at(0), quiet: false) == nil)
    #expect(a.tick(now: at(100), quiet: false) == nil, "mid-frame")
    a.request(body: .idle, face: .idle, now: at(150))  // repeats the current state
    #expect(a.tick(now: at(150), quiet: false) == nil)
    #expect(a.nextChange == at(200))
    #expect(a.tick(now: at(200), quiet: false)?.body == 2)

    // Holding the resting frame, the next change is the next blink, not the next body frame.
    _ = run(&a, 210, 2000, quiet: true)
    let due = a.nextChange
    #expect(due.timeIntervalSince(at(2000)) > 1)
    #expect(a.tick(now: due - 0.001, quiet: true) == nil)
    #expect(a.tick(now: due, quiet: true)?.eyesClosed == true)
}
