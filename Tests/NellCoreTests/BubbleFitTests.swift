import CoreGraphics
import Foundation
import Testing
@testable import NellCore

// Heights are oldest first, as `NellModel.shown` lists them.

@Test func pinnedApprovalStaysUnderTallBubbles() {
    // red team D2's measured case: approval 118, long Chat reply 182, user 46, short reply 46 in the 320 pt column
    #expect(fitRows(heights: [118, 182, 46, 46], pinned: [true, false, false, false], budget: 320, spacing: 8)
            == [true, false, true, true])
    // three tall bubbles: the approval and the newest that still fits, the oldest others dropped
    #expect(fitRows(heights: [118, 150, 150, 150], pinned: [true, false, false, false], budget: 320, spacing: 8)
            == [true, false, false, true])
}

@Test func fittingStopsAtTheFirstBubbleThatDoesNotFit() {
    // an older short bubble never shows while a newer one is hidden
    #expect(fitRows(heights: [40, 300, 100], pinned: [false, false, false], budget: 320, spacing: 8) == [false, false, true])
}

@Test func everythingFitsWhenThereIsRoom() {
    #expect(fitRows(heights: [40, 40, 40], pinned: [false, true, false], budget: 320, spacing: 8) == [true, true, true])
    #expect(fitRows(heights: [], pinned: [], budget: 320, spacing: 8) == [])
}

@Test func pinnedRowsArePlacedEvenOverBudget() {
    #expect(fitRows(heights: [200, 200, 30], pinned: [true, true, false], budget: 320, spacing: 8) == [true, true, false])
}

@Test func theNewestBubbleShowsEvenIfTallerThanTheColumn() {
    // a column with a live bubble is never left empty: the column clips what doesn't fit
    #expect(fitRows(heights: [40, 400], pinned: [false, false], budget: 320, spacing: 8) == [false, true])
    #expect(fitRows(heights: [400], pinned: [false], budget: 100, spacing: 8) == [true])
}

@Test func pinnedFollowsTheStoreRule() {
    var s = BubbleStore()
    let now = Date()
    s.add(.approval(requestId: "r1"), mode: .code, text: "rm", now: now)
    s.add(.question, mode: .code, text: "q", now: now)
    s.add(.consoleNeeded, mode: .chat, text: "c", now: now)
    s.add(.reply, mode: .chat, text: "hi", now: now)
    #expect(s.bubbles.map(\.pinned) == [true, true, true, false])
    s.settle(requestId: "r1", as: "Allowed")
    #expect(!s.bubbles[0].pinned)
}
