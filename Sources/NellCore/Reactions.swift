import Foundation

public enum Body: String, Sendable { case idle, typing, yawning, sleeping }
public enum Face: String, Sendable { case idle, intent, exhausted, happy, smile, sad, scared }

/// Declaration order is the priority (warning highest).
public enum Emoji: String, Sendable, Comparable, CaseIterable {
    case warning, question, plug, alert, crying, heart, thumbsup
    public static func < (a: Emoji, b: Emoji) -> Bool { a.order < b.order }
    private var order: Int { Emoji.allCases.firstIndex(of: self)! }
}

public struct ReactionState: Sendable {
    public static let briefDuration: TimeInterval = 2.5
    private var held: Set<Emoji> = []
    private var brief: [(emoji: Emoji, at: Date)] = []
    public init() {}

    public mutating func flash(_ e: Emoji, now: Date) {
        brief.removeAll { now.timeIntervalSince($0.at) >= Self.briefDuration }
        brief.append((e, now))
    }
    public mutating func setHeld(_ e: Emoji, _ on: Bool) { if on { held.insert(e) } else { held.remove(e) } }

    /// The highest-priority held emoji, else the highest-priority brief one still live.
    public func current(now: Date) -> Emoji? {
        if let h = held.min() { return h }
        return brief.filter { now.timeIntervalSince($0.at) < Self.briefDuration }.map(\.emoji).min()
    }
}

public func body(code: SessionTracker, chat: SessionTracker, selected: Mode) -> Body {
    if code.usageLimited || chat.usageLimited { return .sleeping }
    if code.testRunning { return .yawning }
    return (selected == .code ? code : chat).turnRunning ? .typing : .idle
}

public func face(body: Body, emoji: Emoji?) -> Face {
    switch emoji {
    case .heart: return .happy
    case .thumbsup: return .smile
    case .crying: return .sad
    case .warning: return .scared
    default:
        switch body {
        case .idle: return .idle
        case .typing: return .intent
        case .yawning, .sleeping: return .exhausted
        }
    }
}
