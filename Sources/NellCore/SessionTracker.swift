import Foundation

public enum ApprovalAnswer: Sendable, Equatable { case allow, deny, none }

public enum NellState: String, CaseIterable, Sendable {
    case idle, listening, thinking, typing, needsYou = "needs-you", question, oops, alert, done, error, disconnected
}

/// One Claude session's state, driven by hook events. Pure: time comes in as `now`.
public struct SessionTracker: Sendable {
    private var base: NellState = .idle
    private var transient: (until: Date, then: NellState)?
    private var finalized = false
    /// After Open terminal / a deadline, Claude's own prompt is open in kitty: hold until that tool finishes (id if known).
    private var hold: (toolUseId: String?, since: Date)?
    private var lastEventAt: Date?
    private var launchedAt: Date?
    private var connected = false
    private var openToolUses: [(name: String, input: [String: JSONValue]?, id: String?)] = []
    private var shownAlerts: Set<String> = []
    private var beforeAlert: NellState = .idle
    private var testIds: Set<String> = []

    /// requestId → tool_use_id of the PreToolUse it belongs to (PermissionRequest carries none).
    public private(set) var pendingApprovals: [String: String?] = [:]
    public private(set) var pendingQuestion: String?
    public private(set) var lastAlert: String?
    /// The live session id from SessionStart (it changes after /clear).
    public private(set) var sessionId: String?
    /// A `StopFailure` with `error == "rate_limit"` set this; the next `Stop`, tool call or `quota_auto_resume_*` notification clears it.
    public private(set) var usageLimited = false
    public var testRunning: Bool { !testIds.isEmpty }
    /// A turn is in flight (not finalized; a failed tool or a mid-turn alert doesn't end it).
    public var turnRunning: Bool { !finalized && [.thinking, .typing, .needsYou, .question, .oops, .alert].contains(state) }

    public init() {}

    public var state: NellState {
        if !pendingApprovals.isEmpty { return .needsYou }
        if pendingQuestion != nil { return .question }
        return base
    }

    public var inputHeld: Bool {
        !pendingApprovals.isEmpty || pendingQuestion != nil || hold != nil || (launchedAt != nil && !connected)
    }

    public mutating func markLaunched(now: Date) { launchedAt = now; connected = false }

    public mutating func clearAlert() {
        lastAlert = nil
        if base == .alert { base = beforeAlert; transient = nil }
    }

    /// True when this `PostToolUse` ran a tool whose approval was answered in kitty (still pending here, or handed
    /// to the console). Call it before `handle`, which clears both.
    public func ranAfterKittyApproval(_ e: HookEvent) -> Bool {
        guard e.name == "PostToolUse", !finalized, let id = e.toolUseId else { return false }
        return hold?.toolUseId == id || pendingApprovals.values.contains(id)
    }

    public mutating func settleApproval(_ id: String, answer: ApprovalAnswer) {
        guard let toolUseId = pendingApprovals.removeValue(forKey: id) else { return }
        if answer == .none { hold = (toolUseId, lastEventAt ?? .distantPast) } // Claude's own prompt is now open in kitty
    }

    /// Returns the approval request ids this event settled (answered in kitty, or the turn ended).
    @discardableResult
    public mutating func handle(_ e: HookEvent, requestId: String?, now: Date) -> [String] {
        if let t = transient, now >= t.until { base = t.then; transient = nil }
        lastEventAt = now
        let isQuestionTool = e.toolName == "AskUserQuestion"
        let isPost = e.name == "PostToolUse" || e.name == "PostToolUseFailure"
        let turnEnds = ["UserPromptSubmit", "Stop", "StopFailure", "SessionEnd"].contains(e.name)
        // Only the tool that opened a prompt in kitty (or the end of the turn) closes it; parallel tools don't.
        if turnEnds || (isPost && hold != nil && (hold?.toolUseId == nil ? false : hold?.toolUseId == e.toolUseId)) { hold = nil }
        if turnEnds || (isPost && isQuestionTool) { pendingQuestion = nil }
        if turnEnds { testIds = [] }
        if isPost { testIds.remove(e.toolUseId ?? "") }
        if isPost { openToolUses.removeAll { $0.id != nil && $0.id == e.toolUseId } }

        if finalized, ["PreToolUse", "PostToolUse", "PostToolUseFailure", "PermissionRequest"].contains(e.name) { return [] }

        switch e.name {
        case "SessionStart":
            connected = true; sessionId = e.sessionId
            set(.idle)
        case "UserPromptSubmit":
            finalized = false; shownAlerts = []; lastAlert = nil
            set(.thinking)
            return settleAll()
        case "PreToolUse":
            usageLimited = false // Claude answered, so the limit is over
            openToolUses.append((e.toolName ?? "", e.toolInput, e.toolUseId))
            if e.toolName == "Bash", let c = e.toolInput?["command"]?.string, isTestCommand(c) { testIds.insert(e.toolUseId ?? "") }
            if openToolUses.count > 32 { openToolUses.removeFirst() }
            if isQuestionTool { pendingQuestion = firstQuestion(e.toolInput) ?? "Claude has a question" } else { set(.typing) }
        case "PermissionRequest":
            guard let requestId, !isQuestionTool else { break }
            let claimed = Set(pendingApprovals.values.compactMap { $0 })
            let match = openToolUses.last { $0.name == e.toolName && $0.input == e.toolInput && !claimed.contains($0.id ?? "") }
            pendingApprovals[requestId] = match?.id
        case "PostToolUse", "PostToolUseFailure":
            let settled = pendingApprovals.filter { $0.value != nil && $0.value == e.toolUseId }.map(\.key)
            for id in settled { pendingApprovals.removeValue(forKey: id) }
            if e.name == "PostToolUse" { set(.thinking) } else { set(.oops, for: Timings.oopsBeat, then: .thinking, now: now) }
            return settled.sorted()
        case "Notification":
            if e.notificationType?.hasPrefix("quota_auto_resume_") == true { usageLimited = false; break } // the limit's wait ended
            if e.notificationType == "permission_prompt", !pendingApprovals.isEmpty || pendingQuestion != nil { break }
            let msg = e.message ?? "Claude needs you"
            guard !shownAlerts.contains(msg) else { break }
            shownAlerts.insert(msg); lastAlert = msg
            beforeAlert = base == .alert ? beforeAlert : base
            set(.alert)
        case "Stop":
            finalized = true; usageLimited = false
            set(.done, for: Timings.doneBeat, then: .idle, now: now)
            return settleAll()
        case "StopFailure":
            finalized = true; set(.error)
            if e.error == "rate_limit" { usageLimited = true }
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
        guard let last = lastEventAt else { return }
        let quiet = now.timeIntervalSince(last)
        if hold != nil, quiet >= Timings.typingWatchdog { hold = nil } // Esc in kitty sends no event at all
        guard pendingApprovals.isEmpty, pendingQuestion == nil else { return }
        if (base == .typing || base == .thinking), quiet >= Timings.typingWatchdog { base = .idle }
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
    return listening && mine == .idle ? .listening : mine
}
