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

    /// When the next live brief emoji ends, so the caller can wake then.
    public func nextExpiry(now: Date) -> Date? {
        brief.map { $0.at + Self.briefDuration }.filter { $0 > now }.min()
    }

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

/// ⚠️ while an approval is pending, ❓ while a question is, 🔌 while Claude can't be heard or is usage-limited, in either mode.
public func heldEmoji(code: SessionTracker, chat: SessionTracker) -> Set<Emoji> {
    var s: Set<Emoji> = []
    for t in [code, chat] {
        if !t.pendingApprovals.isEmpty { s.insert(.warning) }
        if t.pendingQuestion != nil { s.insert(.question) }
        if t.usageLimited || t.state == .disconnected { s.insert(.plug) }
    }
    return s
}

/// The brief emoji a hook event earns. Test results react in Code only, and a piped or unclear result gets nothing
/// (never ❗). `approvedInKitty`: `SessionTracker.ranAfterKittyApproval`. `newAlert`: the tracker raised a new alert.
public func flash(for e: HookEvent, mode: Mode, approvedInKitty: Bool, newAlert: Bool) -> Emoji? {
    switch e.name {
    case "PostToolUse", "PostToolUseFailure":
        if e.toolName == "Bash", let c = e.toolInput?["command"]?.string, isTestCommand(c) {
            if mode == .code, let o = testOutcome(e) { return o == .pass ? .heart : .crying }
        } else if e.name == "PostToolUseFailure" {
            return e.isInterrupt == true ? nil : .alert
        }
        return e.name == "PostToolUse" && approvedInKitty ? .thumbsup : nil
    case "StopFailure": return e.error == "rate_limit" ? nil : .alert
    case "Notification": return newAlert ? .alert : nil
    default: return nil
    }
}

public enum ContextAction: Equatable, Sendable { case reset, read(transcriptPath: String) }

/// Paper stacks follow Code only: read the transcript when a turn ends, clear on /clear and compaction.
public func contextAction(for e: HookEvent, mode: Mode) -> ContextAction? {
    guard mode == .code else { return nil }
    switch e.name {
    case "PreCompact", "PostCompact": return .reset
    case "SessionStart":
        if e.source == "clear" { return .reset }
        // a relaunch or resume: show the stacks it already has instead of 0 until the first Stop
        return ["startup", "resume"].contains(e.source ?? "") ? e.transcriptPath.map { .read(transcriptPath: $0) } : nil
    case "Stop": return e.transcriptPath.map { .read(transcriptPath: $0) }
    default: return nil
    }
}

/// The sprite stops while the screen is locked or the display sleeps. The two are tracked apart, because the display
/// can wake on the lock screen.
public struct PauseState: Sendable {
    public var locked = false, asleep = false
    public init() {}
    public var paused: Bool { locked || asleep }
}

/// The bubble text for a `StopFailure`. A usage limit is a nap, not a failure, with the reset time when Claude gave one
/// ("You've hit your session limit · resets 3:45pm").
public func stopFailureMessage(_ e: HookEvent) -> String {
    guard e.error == "rate_limit" else { return e.error ?? "Something went wrong" }
    let base = "Usage limit reached — Nell's napping until it resets"
    guard let m = e.lastAssistantMessage, let r = m.range(of: #"resets\s+([^\n·]+?)\s*$"#, options: .regularExpression) else { return base }
    return base + " at " + m[r].replacingOccurrences(of: #"^resets\s+"#, with: "", options: .regularExpression)
}
