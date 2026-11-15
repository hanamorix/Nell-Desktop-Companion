import Foundation

public enum ApprovalAnswer: Sendable, Equatable { case allow, deny, none }

public enum NellState: String, CaseIterable, Sendable {
    case idle, thinking, typing, needsYou = "needs-you", question, alert, error, disconnected
}

/// One Claude session's state, driven by hook events. Pure: time comes in as `now`.
public struct SessionTracker: Sendable {
    private var base: NellState = .idle
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
    /// A `StopFailure` with `error == "rate_limit"` set this. `endsUsageLimit` events clear it (in both sessions, via
    /// `endUsageLimitAccountWide`); `SessionEnd` clears only this session's.
    public fileprivate(set) var usageLimited = false
    public var testRunning: Bool { !testIds.isEmpty }
    /// A turn is in flight (not finalized; a failed tool or a mid-turn alert doesn't end it).
    public var turnRunning: Bool { !finalized && [.thinking, .typing, .needsYou, .question, .alert].contains(state) }

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

    /// You said the question is gone (Esc on Claude's picker sends no event). Never on a timer: you may just be away.
    public mutating func dismissQuestion() { pendingQuestion = nil }

    public mutating func clearAlert() {
        lastAlert = nil
        if base == .alert { base = beforeAlert }
    }

    /// True when this `PostToolUse` ran a tool whose approval was answered in kitty (still pending here, or handed
    /// to the console). Call it before `handle`, which clears both.
    public func ranAfterKittyApproval(_ e: HookEvent) -> Bool {
        guard e.name == "PostToolUse", !finalized, let id = e.toolUseId else { return false }
        return hold?.toolUseId == id || pendingApprovals.values.contains(id)
    }

    /// Claude answered (a finished turn or a tool call) or the limit's wait ended. Limits are account-wide.
    public static func endsUsageLimit(_ e: HookEvent) -> Bool {
        e.name == "Stop" || e.name == "PreToolUse" || e.notificationType?.hasPrefix("quota_auto_resume_") == true
    }

    /// The turn is over: a new prompt, its end, or a fresh Claude (a relaunch or resume starts with no turn running).
    public static func endsTurn(_ e: HookEvent) -> Bool {
        ["UserPromptSubmit", "Stop", "StopFailure", "SessionEnd"].contains(e.name)
            || e.name == "SessionStart" && ["startup", "resume"].contains(e.source ?? "")
    }

    public mutating func settleApproval(_ id: String, answer: ApprovalAnswer, now: Date) {
        guard let toolUseId = pendingApprovals.removeValue(forKey: id) else { return }
        if answer == .none { hold = (toolUseId, now) } // Claude's own prompt is now open in kitty
        if answer == .deny, let toolUseId { testIds.remove(toolUseId) } // a denied tool never runs, so no Post ends it
    }

    /// Returns the approval request ids this event settled (answered in kitty, or the turn ended).
    @discardableResult
    public mutating func handle(_ e: HookEvent, requestId: String?, now: Date) -> [String] {
        lastEventAt = now
        let isQuestionTool = e.toolName == "AskUserQuestion"
        let isPost = e.name == "PostToolUse" || e.name == "PostToolUseFailure"
        let turnEnds = Self.endsTurn(e)
        // Only the tool that opened a prompt in kitty (or the end of the turn) closes it; parallel tools don't.
        if turnEnds || (isPost && hold != nil && (hold?.toolUseId == nil ? false : hold?.toolUseId == e.toolUseId)) { hold = nil }
        if turnEnds || (isPost && isQuestionTool) { pendingQuestion = nil }
        if turnEnds { testIds = []; openToolUses = [] }
        if Self.endsUsageLimit(e) || e.name == "SessionEnd" { usageLimited = false }
        if isPost { testIds.remove(e.toolUseId ?? "") }
        if isPost { openToolUses.removeAll { $0.id != nil && $0.id == e.toolUseId } }
        if e.name == "PreToolUse" { openToolUses.append((e.toolName ?? "", e.toolInput, e.toolUseId)) }
        if openToolUses.count > 32 { openToolUses.removeFirst() }

        // late tool events after the turn don't change her state; a PermissionRequest never is noise: its hook blocks,
        // so a prompt is open. The calls are still tracked, so that prompt's approval can settle on its own tool's Post.
        if finalized, e.name == "PreToolUse" { return [] }
        if finalized, isPost { return settleApprovals(of: e.toolUseId) }

        switch e.name {
        case "SessionStart":
            connected = true; sessionId = e.sessionId
            if e.source != "compact" { base = .idle } // auto-compaction can run mid-turn
            if turnEnds { finalized = true; return settleAll() }
        case "UserPromptSubmit":
            finalized = false; shownAlerts = []; lastAlert = nil
            base = .thinking
            return settleAll()
        case "PreToolUse":
            if e.toolName == "Bash", let c = e.toolInput?["command"]?.string, isTestCommand(c), !isBackground(e) { testIds.insert(e.toolUseId ?? "") }
            if isQuestionTool { pendingQuestion = firstQuestion(e.toolInput) ?? "Claude has a question" } else { base = .typing }
        case "PermissionRequest":
            guard let requestId, !isQuestionTool else { break }
            // PermissionRequest carries no tool_use_id: bind only when exactly one open call matches (claiming removes it,
            // so an answered or denied call is never matched again). With identical calls open, either could be this
            // one's, so it binds to none and settles only through its own hook: an answer, the hook closing, the deadline.
            let matches = openToolUses.indices.filter { openToolUses[$0].name == e.toolName && openToolUses[$0].input == e.toolInput }
            let id: String? = matches.count == 1 ? openToolUses.remove(at: matches[0]).id : nil
            pendingApprovals[requestId] = id
        case "PostToolUse", "PostToolUseFailure":
            // Esc: no Stop follows, but the turn may go on, so don't finalize
            base = e.isInterrupt == true ? .idle : .thinking
            return settleApprovals(of: e.toolUseId)
        case "Notification":
            if e.notificationType?.hasPrefix("quota_auto_resume_") == true { break } // the limit's wait ended: not an alert
            if e.notificationType == "permission_prompt", !pendingApprovals.isEmpty || pendingQuestion != nil || hold != nil { break }
            let msg = e.message ?? "Claude needs you"
            guard !shownAlerts.contains(msg) else { break }
            shownAlerts.insert(msg); lastAlert = msg
            beforeAlert = base == .alert ? beforeAlert : base
            base = .alert
        case "Stop":
            finalized = true; base = .idle
            return settleAll()
        case "StopFailure":
            finalized = true; base = .error
            if e.error == "rate_limit" { usageLimited = true }
            return settleAll()
        case "SessionEnd":
            finalized = true; base = .idle
            return settleAll()
        default:
            break // SubagentStop and anything new never change state
        }
        return []
    }

    /// True when the watchdog just ended a hold: no event says Claude's prompt closed, so it may still be open.
    @discardableResult
    public mutating func tick(now: Date) -> Bool {
        if let l = launchedAt, !connected, now.timeIntervalSince(l) >= Timings.hooksNotConnected { base = .disconnected }
        guard let last = lastEventAt else { return false }
        let quiet = now.timeIntervalSince(last)
        // Esc in kitty sends no event at all; a deadline hand-off comes long after the last event, so time the hold too
        var holdEnded = false
        if let h = hold, quiet >= Timings.typingWatchdog, now.timeIntervalSince(h.since) >= Timings.typingWatchdog { hold = nil; holdEnded = true }
        if pendingApprovals.isEmpty, pendingQuestion == nil, base == .typing || base == .thinking, quiet >= Timings.typingWatchdog { base = .idle }
        return holdEnded
    }

    /// The approvals bound to this tool call: it ran, so its prompt (answered in kitty) is closed.
    private mutating func settleApprovals(of toolUseId: String?) -> [String] {
        let settled = pendingApprovals.filter { $0.value != nil && $0.value == toolUseId }.map(\.key)
        for id in settled { pendingApprovals.removeValue(forKey: id) }
        return settled.sorted()
    }

    private mutating func settleAll() -> [String] {
        let ids = pendingApprovals.keys.sorted(); pendingApprovals = [:]; return ids
    }
    private func firstQuestion(_ input: [String: JSONValue]?) -> String? {
        guard case .array(let qs)? = input?["questions"], case .object(let q)? = qs.first else { return nil }
        return q["question"]?.string
    }
}

/// The prompt waiting on you in either mode, for the chime (an approval beats a question); nil when none is.
public func promptWaiting(code: SessionTracker, chat: SessionTracker) -> NellState? {
    [NellState.needsYou, .question].first { [code.state, chat.state].contains($0) }
}

/// Usage limits are per account, not per session: an event that ends one session's limit ends the other's too.
public func endUsageLimitAccountWide(_ e: HookEvent, _ trackers: inout [Mode: SessionTracker]) {
    guard SessionTracker.endsUsageLimit(e) else { return }
    for m in trackers.keys { trackers[m]?.usageLimited = false }
}
