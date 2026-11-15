import Foundation

public enum BubbleKind: Equatable, Sendable { case user, reply, status, approval(requestId: String), question, alert, error, consoleNeeded }

public struct Bubble: Identifiable, Equatable, Sendable {
    public let id = UUID()
    public var kind: BubbleKind
    public var mode: Mode
    public var text: String
    public var created: Date
    public var settled = false
    /// When the visible countdown started; nil until it may begin (approvals, or replies while you're away).
    public var clockStart: Date?

    /// A pending approval or question (or a "needs you in the console"): never fades, and always keeps its place on screen.
    public var pinned: Bool {
        guard !settled else { return false }
        if case .approval = kind { return true }
        return kind == .question || kind == .consoleNeeded
    }
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

    /// Opening the console answers its "needs you in the console" bubbles.
    public mutating func settleConsoleNeeded(mode: Mode) {
        for i in bubbles.indices where bubbles[i].kind == .consoleNeeded && bubbles[i].mode == mode { bubbles[i].settled = true }
    }

    public mutating func settleQuestions(mode: Mode) {
        for i in bubbles.indices where bubbles[i].kind == .question && bubbles[i].mode == mode { bubbles[i].settled = true }
    }

    /// Text handed back to the bar was never sent: drop the bubble it got when typed (the newest one with that text).
    public mutating func removeUser(mode: Mode, text: String) {
        if let i = bubbles.lastIndex(where: { $0.kind == .user && $0.mode == mode && $0.text == text }) { bubbles.remove(at: i) }
    }

    /// Starts countdowns once allowed, restarts the hovered one (shortcut: hover restarts rather than pauses), drops faded bubbles.
    public mutating func tick(now: Date, userIdle: TimeInterval, hovered: UUID?) {
        for i in bubbles.indices {
            let b = bubbles[i]
            if b.pinned { continue } // a pending approval or question never fades
            if b.id == hovered { bubbles[i].clockStart = now; continue }
            if b.clockStart == nil, userIdle < 5 { bubbles[i].clockStart = now }
        }
        let gone = Set(bubbles.filter { fadeFactor($0, now) <= 0 }.map(\.id))
        bubbles.removeAll { gone.contains($0.id) }
    }

    /// Pending approvals/questions always show at full strength; the rest fill the remaining slots, newest brightest.
    public func visible(now: Date) -> [(bubble: Bubble, opacity: Double)] {
        let pinned = Set(bubbles.filter(\.pinned).map(\.id))
        let others = bubbles.filter { !pinned.contains($0.id) && fadeFactor($0, now) > 0 }
            .suffix(max(1, Timings.maxVisibleBubbles - pinned.count))
        let ranks = [1.0, 0.55, 0.3, 0.12]
        var opacity: [UUID: Double] = [:]
        for (i, b) in others.reversed().enumerated() { opacity[b.id] = ranks[min(i, 3)] * fadeFactor(b, now) }
        return bubbles.compactMap { b in pinned.contains(b.id) ? (b, 1) : opacity[b.id].map { (b, $0) } }
    }

    private func duration(_ b: Bubble) -> TimeInterval {
        b.kind == .reply && b.mode == .chat ? Timings.chatReplyVisible : Timings.bubbleVisible
    }
    private func fadeFactor(_ b: Bubble, _ now: Date) -> Double {
        guard let start = b.clockStart else { return 1 }
        let over = now.timeIntervalSince(start) - duration(b)
        return over <= 0 ? 1 : max(0, 1 - over / Timings.bubbleFade)
    }
    private func truncated(_ s: String) -> String {
        let lines = s.components(separatedBy: "\n")
        let head = lines.prefix(3).joined(separator: "\n")
        return lines.count > 3 || head.count > 240 ? String(head.prefix(240)) + "\n…more in ⌘" : s
    }
}
