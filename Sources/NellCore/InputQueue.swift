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

    public mutating func release() -> [String] { defer { queued = [] }; return queued }
}
