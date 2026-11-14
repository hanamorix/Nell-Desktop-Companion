import Foundation

public enum ApprovalAnswer: Sendable, Equatable { case allow, deny, none }

public enum NellState: String, CaseIterable, Sendable {
    case idle, listening, thinking, typing, needsYou = "needs-you", question, oops, alert, done, sleepy, error, disconnected
}

/// One Claude session's state, driven by hook events. Pure: time comes in as `now`.
public struct SessionTracker: Sendable {
    private var base: NellState = .idle
    private var transient: (until: Date, then: NellState)?
    private var finalized = false
    private var holdUntilNextEvent = false
    private var lastEventAt: Date?
    private var launchedAt: Date?
    private var connected = false
    private var lastPreToolUse: (name: String, input: [String: JSONValue]?, id: String?)?
    private var shownAlerts: Set<String> = []
    private var beforeAlert: NellState = .idle

    /// requestId → tool_use_id of the PreToolUse it belongs to (PermissionRequest carries none).
    public private(set) var pendingApprovals: [String: String?] = [:]
    public private(set) var pendingQuestion: String?
    public private(set) var lastAlert: String?

    public init() {}

    public var state: NellState {
        if !pendingApprovals.isEmpty { return .needsYou }
        if pendingQuestion != nil { return .question }
        return base
    }

    public var inputHeld: Bool { !pendingApprovals.isEmpty || pendingQuestion != nil || holdUntilNextEvent }

    public mutating func markLaunched(now: Date) { launchedAt = now; connected = false }

    public mutating func clearAlert() {
        lastAlert = nil
        if base == .alert { base = beforeAlert; transient = nil }
    }

    public mutating func settleApproval(_ id: String, answer: ApprovalAnswer) {
        guard pendingApprovals.removeValue(forKey: id) != nil else { return }
        if answer == .none { holdUntilNextEvent = true } // Claude's own prompt is now open in kitty
    }

    /// Returns the approval request ids this event settled (answered in kitty, or the turn ended).
    @discardableResult
    public mutating func handle(_ e: HookEvent, requestId: String?, now: Date) -> [String] {
        if let t = transient, now >= t.until { base = t.then; transient = nil }
        connected = true
        lastEventAt = now
        let isQuestionTool = e.toolName == "AskUserQuestion"
        let passive = e.name == "Notification" || e.name == "SubagentStop"
            || (isQuestionTool && (e.name == "PreToolUse" || e.name == "PermissionRequest"))
        if !passive { holdUntilNextEvent = false; pendingQuestion = nil }

        if finalized, ["PreToolUse", "PostToolUse", "PostToolUseFailure", "PermissionRequest"].contains(e.name) { return [] }

        switch e.name {
        case "SessionStart":
            set(.idle)
        case "UserPromptSubmit":
            finalized = false; shownAlerts = []; lastAlert = nil
            set(.thinking)
            return settleAll()
        case "PreToolUse":
            lastPreToolUse = (e.toolName ?? "", e.toolInput, e.toolUseId)
            if isQuestionTool { pendingQuestion = firstQuestion(e.toolInput) ?? "Claude has a question" } else { set(.typing) }
        case "PermissionRequest":
            guard let requestId, !isQuestionTool else { break }
            let p = lastPreToolUse
            pendingApprovals[requestId] = (p?.name == e.toolName && p?.input == e.toolInput) ? p?.id : nil
        case "PostToolUse", "PostToolUseFailure":
            let settled = pendingApprovals.filter { $0.value != nil && $0.value == e.toolUseId }.map(\.key)
            for id in settled { pendingApprovals.removeValue(forKey: id) }
            if e.name == "PostToolUse" { set(.thinking) } else { set(.oops, for: Timings.oopsBeat, then: .thinking, now: now) }
            return settled.sorted()
        case "Notification":
            if e.notificationType == "permission_prompt", !pendingApprovals.isEmpty || pendingQuestion != nil { break }
            let msg = e.message ?? "Claude needs you"
            guard !shownAlerts.contains(msg) else { break }
            shownAlerts.insert(msg); lastAlert = msg
            beforeAlert = base == .alert ? beforeAlert : base
            set(.alert)
        case "Stop":
            finalized = true
            set(.done, for: Timings.doneBeat, then: .idle, now: now)
            return settleAll()
        case "StopFailure":
            finalized = true; set(.error)
            return settleAll()
        case "SessionEnd":
            finalized = true; set(.idle)
            return settleAll()
        default:
            break // SubagentStop and anything new never change state
        }
        return []
    }

    public mutating func tick(now: Date) {
        if let t = transient, now >= t.until { base = t.then; transient = nil }
        if let l = launchedAt, !connected, now.timeIntervalSince(l) >= Timings.hooksNotConnected { base = .disconnected }
        guard let last = lastEventAt, pendingApprovals.isEmpty, pendingQuestion == nil else { return }
        let quiet = now.timeIntervalSince(last)
        if (base == .typing || base == .thinking), quiet >= Timings.typingWatchdog { base = .idle }
        if base == .idle, quiet >= Timings.sleepyAfter { base = .sleepy }
    }

    private mutating func set(_ s: NellState) { base = s; transient = nil }
    private mutating func set(_ s: NellState, for d: TimeInterval, then: NellState, now: Date) {
        base = s; transient = (now.addingTimeInterval(d), then)
    }
    private mutating func settleAll() -> [String] {
        let ids = pendingApprovals.keys.sorted(); pendingApprovals = [:]; return ids
    }
    private func firstQuestion(_ input: [String: JSONValue]?) -> String? {
        guard case .array(let qs)? = input?["questions"], case .object(let q)? = qs.first else { return nil }
        return q["question"]?.string
    }
}

/// Which state Nell's body shows: needs-you/question anywhere > error/alert/disconnected anywhere > the selected mode.
public func bodyState(selected: Mode, code: SessionTracker, chat: SessionTracker, listening: Bool) -> NellState {
    let both = [code.state, chat.state]
    for s in [NellState.needsYou, .question] where both.contains(s) { return s }
    for s in [NellState.error, .alert, .disconnected] where both.contains(s) { return s }
    let mine = selected == .code ? code.state : chat.state
    return listening && (mine == .idle || mine == .sleepy) ? .listening : mine
}
