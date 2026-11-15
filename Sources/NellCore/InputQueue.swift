/// Text typed in the bar waits here while Claude has a prompt open in kitty (typing would answer it instead).
public struct InputQueue: Sendable {
    private var queued: [String] = []
    public init() {}
    public var count: Int { queued.count }

    /// The text to send now, or nil if it was queued (or blank).
    public mutating func submit(_ text: String, held: Bool) -> String? {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        if held || !queued.isEmpty { queued.append(text); return nil }
        return text
    }

    /// Everything queued, once nothing holds it (`held: false` takes it all, for handing back to the bar).
    public mutating func release(held: Bool) -> [String] {
        guard !held else { return [] }
        defer { queued = [] }; return queued
    }
}

/// Queued text handed back to the bar unsent belongs to its mode: it joins the one draft only while that mode is
/// selected, so a single Enter never sends it to the other Claude.
public struct ReturnedText: Sendable {
    private var waiting: [Mode: [String]] = [:]
    public init() {}
    public mutating func add(_ texts: [String], for m: Mode) { waiting[m, default: []] += texts }
    /// Text for this mode is waiting to join the bar (its chip shows the news dot until you switch to it).
    public func isWaiting(for m: Mode) -> Bool { waiting[m] != nil }

    /// The draft with the selected mode's waiting text taken in, oldest first, ahead of what's typed there now.
    public mutating func draft(_ typed: String, selected: Mode) -> String {
        let back = waiting.removeValue(forKey: selected) ?? []
        return (back + [typed]).filter { !$0.isEmpty }.joined(separator: "\n")
    }
}

/// What checking a mode's kitty tab before a send found.
public enum TabCheck: Equatable, Sendable {
    /// That mode's Claude was already running.
    case ready
    /// These Claudes were just started: a kitty restart starts Code with it, so a Chat send can launch both.
    case launched([Mode])
    /// kitty is down (its restart failed, or is inside the cooldown) or the tab wouldn't start: nothing can take text.
    case unavailable

    public enum Delivery: Equatable, Sendable { case now, hold, giveBack }

    public var launched: [Mode] { if case .launched(let ms) = self { ms } else { [] } }

    /// Send now; hold until that Claude's SessionStart; or give the text back to the bar unsent.
    public func delivery(for m: Mode) -> Delivery {
        switch self {
        case .ready: .now
        case .launched(let ms): ms.contains(m) ? .hold : .giveBack
        case .unavailable: .giveBack
        }
    }
}
