import Foundation
import Testing
@testable import NellCore

private let utc = TimeZone(identifier: "UTC")!
private func d(_ iso: String) -> Date { ISO8601DateFormatter().date(from: iso)! }
private let noon = d("2025-11-15T12:00:00Z")
private func json(_ s: String) -> UsageReading? { UsageReading.decode(Data(s.utf8)) }
private func five(_ reset: String) -> String { #"{"rate_limits":{"five_hour":{"used_percentage":10,"resets_at":\#(reset)}}}"# }

@Test func usageDecodesFixture() throws {
    let url = try #require(Bundle.module.url(forResource: "statusline", withExtension: "json", subdirectory: "Fixtures"))
    let r = try #require(UsageReading.decode(Data(contentsOf: url)))
    #expect(r.session == UsageWindow(used: 46, resetsAt: Date(timeIntervalSince1970: 1794760800)))
    #expect(r.weekly == UsageWindow(used: 31, resetsAt: Date(timeIntervalSince1970: 1795226400)))
}

@Test func usageDecodeWithoutRateLimitsIsNil() {
    #expect(json(#"{"model":{}}"#) == nil)
    #expect(json(#"{"rate_limits":{}}"#) == nil)
}

@Test func usageDecodesResetFormats() {
    let want = d("2025-11-15T15:45:00Z")
    #expect(json(five("1763221500"))?.session == UsageWindow(used: 10, resetsAt: want))
    #expect(json(five(#""2025-11-15T15:45:00Z""#))?.session == UsageWindow(used: 10, resetsAt: want))
    #expect(json(#"{"rate_limits":{"five_hour":{"used_percentage":10}}}"#)?.session == UsageWindow(used: 10, resetsAt: nil))
    #expect(json(five(#""soon""#))?.session == UsageWindow(used: 10, resetsAt: nil))
}

@Test func usageMergeKeepsMissingWindow() {
    let old = UsageReading(session: UsageWindow(used: 1), weekly: UsageWindow(used: 2))
    let new = UsageReading(session: UsageWindow(used: 9))
    #expect(old.merged(new, now: d("2025-11-15T12:00:00Z")) == UsageReading(session: UsageWindow(used: 9), weekly: UsageWindow(used: 2)))
}

@Test func usageLevels() {
    func lvl(_ u: Double) -> UsageLevel { gauge(UsageWindow(used: u), .session, now: noon, timeZone: utc).level }
    #expect(lvl(49.9) == .low); #expect(lvl(50) == .mid); #expect(lvl(80) == .mid); #expect(lvl(80.1) == .high)
    let none = gauge(nil, .weekly, now: noon, timeZone: utc)
    #expect(none.level == .none); #expect(none.fraction == nil)
}

@Test func usageGaugeClamps() {
    let hi = gauge(UsageWindow(used: 104), .session, now: noon, timeZone: utc)
    #expect(hi.fraction == 1); #expect(hi.tooltip == "Session 104%")
    #expect(gauge(UsageWindow(used: -3), .session, now: noon, timeZone: utc).fraction == 0)
    let withReset = gauge(UsageWindow(used: 104, resetsAt: d("2025-11-15T15:45:00Z")), .session, now: noon, timeZone: utc)
    #expect(withReset.tooltip == "Session 104% · resets 3:45pm")
}

@Test func usageTooltips() {
    func tip(_ w: UsageWindow?, _ k: UsageKind) -> String { gauge(w, k, now: noon, timeZone: utc).tooltip }
    #expect(tip(UsageWindow(used: 42, resetsAt: d("2025-11-15T15:45:00Z")), .session) == "Session 42% · resets 3:45pm")
    #expect(tip(UsageWindow(used: 81, resetsAt: d("2025-11-20T09:00:00Z")), .weekly) == "Weekly 81% · resets Thu 9:00am")
    #expect(tip(nil, .session) == "Session · no reading yet")
    let past = gauge(UsageWindow(used: 95, resetsAt: d("2025-11-15T11:00:00Z")), .session, now: noon, timeZone: utc)
    #expect(past.tooltip == "Session 0% · reset at 11:00am"); #expect(past.fraction == 0); #expect(past.level == .low)
}

@Test func usageTired() {
    let later = d("2025-11-15T15:00:00Z"), earlier = d("2025-11-15T11:00:00Z")
    #expect(tired(UsageReading(session: UsageWindow(used: 90.5, resetsAt: later)), now: noon))
    #expect(tired(UsageReading(weekly: UsageWindow(used: 90.5, resetsAt: later)), now: noon))
    #expect(!tired(UsageReading(session: UsageWindow(used: 90, resetsAt: later)), now: noon))
    #expect(!tired(UsageReading(session: UsageWindow(used: 95, resetsAt: earlier)), now: noon))
    #expect(!tired(nil, now: noon))
}

@Test func usageNextReset() {
    let a = d("2025-11-15T11:00:00Z"), b = d("2025-11-15T14:00:00Z"), c = d("2025-11-16T14:00:00Z")
    #expect(UsageReading(session: UsageWindow(used: 1, resetsAt: c), weekly: UsageWindow(used: 1, resetsAt: b)).nextReset(after: noon) == b)
    #expect(UsageReading(session: UsageWindow(used: 1, resetsAt: a)).nextReset(after: noon) == nil)
}

@Test func statusLineTextFormats() {
    #expect(statusLineText(UsageReading(session: UsageWindow(used: 42.4), weekly: UsageWindow(used: 80.6))) == "5h 42% · 7d 81%")
    #expect(statusLineText(UsageReading(session: UsageWindow(used: 42.4))) == "5h 42%")
    #expect(statusLineText(nil) == "")
}

private func used(_ v: String) -> String { #"{"rate_limits":{"five_hour":{"used_percentage":\#(v)}}}"# }

@Test func usageDecodeBoundsUsed() {
    let huge = json(used("1e30"))
    #expect(huge?.session?.used == 999)
    #expect(statusLineText(huge) == "5h 999%")
    #expect(gauge(huge?.session, .session, now: noon, timeZone: utc).tooltip == "Session 999%")
    let neg = json(used("-3"))
    #expect(neg?.session?.used == 0)
    #expect(gauge(neg?.session, .session, now: noon, timeZone: utc).tooltip == "Session 0%")
}

@Test func usageDecodeDropsBadUsed() {
    #expect(json(used("1e999")) == nil)
    #expect(json(used(#""42""#)) == nil)
    #expect(json(used("null")) == nil)
}

@Test func usageMergeIgnoresStaleWindow() {
    let old = UsageReading(session: UsageWindow(used: 50, resetsAt: d("2025-11-15T15:00:00Z")))
    let stale = UsageReading(session: UsageWindow(used: 10, resetsAt: d("2025-11-15T14:00:00Z")))
    #expect(old.merged(stale, now: d("2025-11-15T12:00:00Z")) == old)
}

@Test func usageMergeSameWindowKeepsHigher() {
    let r = d("2025-11-15T15:00:00Z")
    let a = UsageReading(session: UsageWindow(used: 60, resetsAt: r)), b = UsageReading(session: UsageWindow(used: 40, resetsAt: r))
    #expect(a.merged(b, now: d("2025-11-15T12:00:00Z")) == a); #expect(b.merged(a, now: d("2025-11-15T12:00:00Z")) == a)
}

@Test func usageMergeNewWindowWins() {
    let old = UsageReading(session: UsageWindow(used: 95, resetsAt: d("2025-11-15T15:00:00Z")))
    let new = UsageReading(session: UsageWindow(used: 10, resetsAt: d("2025-11-15T20:00:00Z")))
    #expect(old.merged(new, now: d("2025-11-15T12:00:00Z")) == new)
}
