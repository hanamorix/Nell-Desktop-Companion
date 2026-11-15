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

/// Queued text handed back to the bar unsent, oldest first, ahead of whatever you're typing there now.
public func mergedDraft(returned: [String], typed: String) -> String {
    (returned + [typed]).filter { !$0.isEmpty }.joined(separator: "\n")
}
