import Foundation

public enum BubbleKind: Equatable, Sendable { case user, reply, status, approval(requestId: String), question, alert, error }

public struct Bubble: Identifiable, Equatable, Sendable {
    public let id = UUID()
    public var kind: BubbleKind
    public var mode: Mode
    public var text: String
    public var created: Date
    public var settled = false
    /// When the visible countdown started; nil until it may begin (approvals, or replies while you're away).
    public var clockStart: Date?
}

public struct BubbleStore: Sendable {
    public private(set) var bubbles: [Bubble] = []
    public init() {}

    public mutating func add(_ kind: BubbleKind, mode: Mode, text: String, now: Date) {
        var t = text
        if kind == .reply, mode == .code { t = truncated(text) }
        let startsNow = kind == .user || kind == .status
        bubbles.append(Bubble(kind: kind, mode: mode, text: t, created: now, clockStart: startsNow ? now : nil))
    }

    public mutating func setStatus(mode: Mode, text: String, now: Date) {
        clearStatus(mode: mode)
        add(.status, mode: mode, text: text, now: now)
    }

    public mutating func clearStatus(mode: Mode) { bubbles.removeAll { $0.kind == .status && $0.mode == mode } }

    public mutating func settle(requestId: String, as label: String) {
        for i in bubbles.indices where bubbles[i].kind == .approval(requestId: requestId) && !bubbles[i].settled {
            bubbles[i].settled = true
            bubbles[i].text += " — \(label)"
        }
    }

    public mutating func settleQuestions(mode: Mode) {
        for i in bubbles.indices where bubbles[i].kind == .question && bubbles[i].mode == mode { bubbles[i].settled = true }
    }

    /// Starts countdowns once allowed, restarts the hovered one (shortcut: hover restarts rather than pauses), drops faded bubbles.
    public mutating func tick(now: Date, userIdle: TimeInterval, hovered: UUID?) {
        for i in bubbles.indices {
            let b = bubbles[i]
            if b.id == hovered { bubbles[i].clockStart = now; continue }
            guard b.clockStart == nil else { continue }
            let pinned = (b.kind == .question || isApproval(b.kind)) && !b.settled
            if !pinned, userIdle < 5 { bubbles[i].clockStart = now }
        }
        let gone = Set(bubbles.filter { fadeFactor($0, now) <= 0 }.map(\.id))
        bubbles.removeAll { gone.contains($0.id) }
    }

    public func visible(now: Date) -> [(bubble: Bubble, opacity: Double)] {
        let live = bubbles.filter { fadeFactor($0, now) > 0 }.suffix(Timings.maxVisibleBubbles)
        let ranks = [1.0, 0.55, 0.3, 0.12]
        return live.reversed().enumerated().map { (i, b) in (b, ranks[i] * fadeFactor(b, now)) }.reversed()
    }

    private func duration(_ b: Bubble) -> TimeInterval {
        b.kind == .reply && b.mode == .chat ? Timings.chatReplyVisible : Timings.bubbleVisible
    }
    private func fadeFactor(_ b: Bubble, _ now: Date) -> Double {
        guard let start = b.clockStart else { return 1 }
        let over = now.timeIntervalSince(start) - duration(b)
        return over <= 0 ? 1 : max(0, 1 - over / Timings.bubbleFade)
    }
    private func isApproval(_ k: BubbleKind) -> Bool { if case .approval = k { true } else { false } }
    private func truncated(_ s: String) -> String {
        let lines = s.components(separatedBy: "\n")
        let head = lines.prefix(3).joined(separator: "\n")
        return lines.count > 3 || head.count > 240 ? String(head.prefix(240)) + "\n…more in ⌘" : s
    }
}
