import AppKit
import NellCore

struct ShownBubble: Identifiable, Equatable { let bubble: Bubble; let opacity: Double; var id: UUID { bubble.id } }

/// The console frame Nell draws around kitty: a border and a title strip.
enum ConsoleChrome { static let border: CGFloat = 4; static let title: CGFloat = 24 }

/// Nell's brain on the main actor: routes hook events into trackers + bubbles, and UI actions into kitty + approvals.
@MainActor final class NellModel: ObservableObject {
    @Published var selected: Mode = .chat
    @Published private(set) var shown: [ShownBubble] = []
    @Published var draft = ""
    /// The screen is locked or asleep: the sprite stops entirely.
    var paused = false { didSet { sprite.paused = paused } }
    /// The bar is holding text because Claude has a prompt open in kitty (or is still starting).
    @Published private(set) var barHeld = false
    @Published private(set) var console = ConsoleState()
    @Published private(set) var layout: NellCore.Layout?
    /// What Claude Code is doing right now, for the minimised console bubble.
    @Published private(set) var codeStatus: String?
    /// The latest usage from Claude's status line (nil until the first reading; not persisted).
    @Published private(set) var usage: UsageReading?
    /// Published separately so the view redraws when a reset passes, though `usage` itself doesn't change.
    @Published private(set) var weeklyGauge = gauge(nil, .weekly, now: Date())
    @Published private(set) var sessionGauge = gauge(nil, .session, now: Date())
    var hovered: UUID?
    /// Recomputes where everything goes for a console phase and moves Nell's window (set by the app delegate).
    var relayout: ((ConsolePhase) -> NellCore.Layout)?
    var displayFrame: () -> CGRect = { NSScreen.main?.frame ?? .zero }

    let kitty: KittyController
    let sprite: SpriteDriver
    let registry: ApprovalRegistry
    let paths: Paths
    var state: SavedState
    var onNeedsYou: (() -> Void)?
    var onOpenProject: (() -> Void)?
    var onHide: (() -> Void)?
    var onQuit: (() -> Void)?
    var onStateChanged: (() -> Void)?

    private var trackers: [Mode: SessionTracker] = [.code: SessionTracker(), .chat: SessionTracker()]
    private var bubbles = BubbleStore()
    private var queues: [Mode: InputQueue] = [.code: InputQueue(), .chat: InputQueue()]
    private var sentByNell: [Mode: [String]] = [.code: [], .chat: []]
    private var questionIds: Set<String> = []
    private var settledInKitty: Set<String> = []
    private var wasDisconnected: Set<Mode> = []
    /// v2's needs-you priority, kept for the sound and bringing her forward.
    private var needsYouState: NellState = .idle
    private var reactions = ReactionState()
    private var context = ContextMeter()
    private var expiry: (at: Date, timer: Timer)?
    /// What the sprite was last asked to show (the showcase checks its steps against it).
    private(set) var pose: (body: Body, face: Face, emoji: Emoji?, stacks: Int) = (.idle, .idle, nil, 0)

    init(kitty: KittyController, registry: ApprovalRegistry, paths: Paths, state: SavedState, sprite: SpriteDriver) {
        self.kitty = kitty; self.registry = registry; self.paths = paths; self.state = state; self.sprite = sprite
    }

    func cwd(_ m: Mode) -> String { m == .code ? (state.projectDir ?? paths.chatDir.path) : paths.chatDir.path }
    func markLaunched(_ modes: [Mode]) { let now = Date(); for m in modes { trackers[m]?.markLaunched(now: now) }; refresh() }

    // MARK: UI actions

    func submit() {
        let text = draft; draft = ""
        let m = selected
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        addBubble(.user, m, text, Date())
        if let now = queues[m]?.submit(text, held: trackers[m]?.inputHeld ?? false) { send(now, m) }
        refresh()
    }

    func chatChip() { selected = .chat; refresh() }

    /// ⌘: from Chat, select Code and open the console; in Code, toggle open ↔ minimised.
    func codeChip() { console.pressCodeChip(selected: &selected); applyConsole() }

    /// Every console open comes from a click: ⌘, the minimised bubble, Open console, Answer in the console.
    func openConsole(tab: Mode = .code) { console.open(tab: tab); applyConsole() }
    func minimiseConsole() { console.minimise(); applyConsole() }

    func relayoutNow() { if let l = relayout?(console.phase) { layout = l; sprite.mirrored = l.faceRight } }

    /// Drag with ⌥: the console hides so the two windows never drift apart, and comes back where Nell lands.
    func dragBegan() { if console.phase == .open { kitty.hideConsole() } }
    func dragEnded() { applyConsole() }

    private func applyConsole() {
        relayoutNow()
        if console.phase == .open {
            bubbles.settleConsoleNeeded(mode: console.tab)
            placeKitty()
            if let cal = kitty.showConsole(tab: console.tab) { // first show: measure kitty's real frame and re-place
                state.calibration = cal; onStateChanged?(); placeKitty()
            }
        } else {
            kitty.hideConsole()
        }
        refresh()
    }

    /// After a display change: re-lay everything out and move kitty with it, without taking the keyboard.
    func refreshPlacement() { relayoutNow(); if console.phase == .open { placeKitty() } }

    /// kitty fills the console frame minus its border and title strip.
    private func placeKitty() {
        guard let c = layout?.consoleFrame else { return }
        let b = ConsoleChrome.border, t = ConsoleChrome.title
        let content = CGRect(x: c.minX + b, y: c.minY + b, width: c.width - 2 * b, height: c.height - 2 * b - t)
        kitty.place(content: content, display: displayFrame(), cal: state.calibration ?? .spike)
    }

    /// While the console is open it shows Code's chatter itself; while minimised, Code's status lives in that bubble.
    private func columnAllows(_ kind: BubbleKind, _ m: Mode) -> Bool {
        if m == .code, kind == .status, console.phase == .minimised { return false }
        return showsInColumn(kind, mode: m, consoleOpen: console.phase == .open)
    }
    private func addBubble(_ kind: BubbleKind, _ m: Mode, _ text: String, _ now: Date) {
        if columnAllows(kind, m) { bubbles.add(kind, mode: m, text: text, now: now) }
    }
    private func setStatus(_ m: Mode, _ text: String, _ now: Date) {
        if m == .code { codeStatus = text }
        if columnAllows(.status, m) { bubbles.setStatus(mode: m, text: text, now: now) }
    }

    func answer(_ requestId: String, _ a: ApprovalAnswer) { registry.answer(id: requestId, a) }

    func openTerminal(_ m: Mode, requestId: String?) {
        if let requestId { registry.answer(id: requestId, .none) }
        openConsole(tab: m)
    }

    // MARK: Hook events

    func handle(_ m: Mode, _ e: HookEvent, requestId: String?) {
        let now = Date()
        let alertBefore = trackers[m]?.lastAlert
        let approvedInKitty = trackers[m]?.ranAfterKittyApproval(e) ?? false
        let settled = trackers[m]?.handle(e, requestId: requestId, now: now) ?? []
        endUsageLimitAccountWide(e, &trackers)
        let newAlert = e.name == "Notification" && trackers[m]?.lastAlert != nil && trackers[m]?.lastAlert != alertBefore
        if let emoji = flash(for: e, mode: m, approvedInKitty: approvedInKitty, newAlert: newAlert) { reactions.flash(emoji, now: now) }
        switch contextAction(for: e, mode: m) {
        case .reset: context.reset()
        case .read(let path):
            // shortcut: assumes the transcript is flushed when Stop fires (unverified); a stale read is corrected next turn
            if let tail = ContextMeter.tail(of: URL(fileURLWithPath: path), maxBytes: 1 << 20),
               let tokens = ContextMeter.tokens(fromTranscriptTail: tail) { context.update(tokens: tokens) }
        case nil: break
        }
        sprite.eventArrived()
        for id in settled {   // answered in kitty, or the turn ended: release the hanging hook too
            settledInKitty.insert(id)
            bubbles.settle(requestId: id, as: "Answered in console")
            registry.answer(id: id, .none)
        }
        switch e.name {
        case "SessionStart":
            if m == .code, state.codeSessionId != e.sessionId { state.codeSessionId = e.sessionId; onStateChanged?() }
            if m == .chat, state.chatSessionId != e.sessionId { state.chatSessionId = e.sessionId; onStateChanged?() }
            bubbles.settleConsoleNeeded(mode: m)
            if m == .chat, console.tab == .chat { // Chat's one-time trust prompt is done: back to Code
                console.chatConnected()
                if console.phase == .open { kitty.selectTab(.code) }
            }
        case "UserPromptSubmit":
            bubbles.clearStatus(mode: m)
            if let p = e.prompt {
                if let i = sentByNell[m]?.firstIndex(of: p) { sentByNell[m]?.remove(at: i) } // already shown when typed in the bar
                else { addBubble(.user, m, p, now) }
            }
        case "PreToolUse":
            if e.toolName != "AskUserQuestion" { setStatus(m, toolSummary(name: e.toolName ?? "", input: e.toolInput), now) }
        case "PermissionRequest":
            guard let id = requestId else { break }
            if e.toolName == "AskUserQuestion" {
                questionIds.insert(id)
                registry.answer(id: id, .none) // the picker is already open in kitty
                addBubble(.question, m, trackers[m]?.pendingQuestion ?? "Claude has a question", now)
            } else {
                addBubble(.approval(requestId: id), m, approvalSummary(name: e.toolName ?? "", input: e.toolInput), now)
            }
        case "PostToolUse", "PostToolUseFailure":
            if e.toolName == "AskUserQuestion" { bubbles.settleQuestions(mode: m) }
            if e.name == "PostToolUseFailure" {
                setStatus(m, toolSummary(name: e.toolName ?? "", input: e.toolInput) + " failed", now)
            }
        case "Notification":
            if let a = trackers[m]?.lastAlert, a != alertBefore { addBubble(.alert, m, a, now) }
        case "Stop":
            bubbles.clearStatus(mode: m); if m == .code { codeStatus = nil }
            if let r = e.lastAssistantMessage, !r.isEmpty { addBubble(.reply, m, r, now) }
        case "StopFailure":
            bubbles.clearStatus(mode: m); if m == .code { codeStatus = nil }
            addBubble(e.error == "rate_limit" ? .alert : .error, m, stopFailureMessage(e), now) // a limit is a nap, not a failure
        case "SessionEnd":
            bubbles.clearStatus(mode: m)
            if kitty.ensureTab(m, cwd: cwd(m), state: &state) { trackers[m]?.markLaunched(now: now); onStateChanged?() }
        default: break
        }
        flushQueue(m)
        refresh()
    }

    func requestSettled(_ m: Mode, _ id: String, _ a: ApprovalAnswer) {
        trackers[m]?.settleApproval(id, answer: a)
        if a == .allow { reactions.flash(.thumbsup, now: Date()) }
        let quiet = questionIds.remove(id) != nil || settledInKitty.remove(id) != nil
        bubbles.settle(requestId: id, as: a == .allow ? "Allowed" : a == .deny ? "Denied" : "Answer in the console")
        // a deadline or a dead hook: Claude now asks in the console, which only opens when you click
        if a == .none, offersConsoleAfterNoDecision(quiet: quiet, console: console, mode: m) { addBubble(.consoleNeeded, m, "Answer in the console", Date()) }
        flushQueue(m)
        refresh()
    }

    /// 1 Hz: timers in the trackers, bubble fades, the disconnected nudge.
    func tick(userIdle: TimeInterval) {
        let now = Date()
        for m in Mode.allCases {
            trackers[m]?.tick(now: now)
            let disc = trackers[m]?.state == .disconnected
            if disc, !wasDisconnected.contains(m) { // e.g. the folder-trust dialog: offer the console, don't open it
                wasDisconnected.insert(m)
                addBubble(.consoleNeeded, m, m == .chat ? "Chat needs a one-time OK" : "Claude needs you in the console", now)
            }
            if !disc { wasDisconnected.remove(m) }
        }
        bubbles.tick(now: now, userIdle: userIdle, hovered: hovered)
        for m in Mode.allCases where trackers[m]?.lastAlert != nil && !bubbles.bubbles.contains(where: { $0.kind == .alert && $0.mode == m }) {
            trackers[m]?.clearAlert()
        }
        refresh()
    }

    /// Showcase only: start a scene from a fresh Nell. No real path clears every session, bubble and the console at once.
    func resetForShowcase() {
        trackers = [.code: SessionTracker(), .chat: SessionTracker()]
        bubbles = BubbleStore()
        queues = [.code: InputQueue(), .chat: InputQueue()]
        sentByNell = [.code: [], .chat: []]
        questionIds = []; settledInKitty = []; wasDisconnected = []
        reactions = ReactionState(); context = ContextMeter()
        console = ConsoleState(); selected = .chat; draft = ""; codeStatus = nil
        usage = nil
        relayoutNow()
        refresh()
    }

    func usageUpdated(_ r: UsageReading) {
        let merged = usage?.merged(r) ?? r
        if merged != usage { usage = merged }
        refresh()
    }

    func refresh() {
        guard let code = trackers[.code], let chat = trackers[.chat] else { return }
        let now = Date()
        let next = bodyState(selected: selected, code: code, chat: chat, listening: !draft.isEmpty)
        if (next == .needsYou || next == .question), needsYouState != next { onNeedsYou?() }
        needsYouState = next
        let holding = heldEmoji(code: code, chat: chat)
        for e in [Emoji.warning, .question, .plug] { reactions.setHeld(e, holding.contains(e)) }
        let emoji = reactions.current(now: now)
        let b = NellCore.body(code: code, chat: chat, selected: selected)
        pose = (b, face(body: b, emoji: emoji, tired: tired(usage, now: now)), emoji, context.stacks)
        sprite.show(body: b, face: pose.face, emoji: emoji, stacks: context.stacks)
        let w = gauge(usage?.weekly, .weekly, now: now), s = gauge(usage?.session, .session, now: now)
        if w != weeklyGauge { weeklyGauge = w }
        if s != sessionGauge { sessionGauge = s }
        wakeAtExpiry(now)
        let held = trackers[selected]?.inputHeld ?? false
        if barHeld != held { barHeld = held }
        let nextShown = bubbles.visible(now: Date()).map { ShownBubble(bubble: $0.bubble, opacity: $0.opacity) }
        if nextShown != shown { shown = nextShown } // don't re-render the view every tick
    }

    /// A brief emoji ends on time (2.5 s), and a passed usage reset empties its chip, both without waiting for the next 1 Hz tick or event.
    private func wakeAtExpiry(_ now: Date) {
        let at = [reactions.nextExpiry(now: now), usage?.nextReset(after: now)].compactMap { $0 }.min()
        guard at != expiry?.at else { return }
        expiry?.timer.invalidate(); expiry = nil
        guard let at else { return }
        expiry = (at, Timer.scheduledTimer(withTimeInterval: at.timeIntervalSince(now), repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        })
    }

    private func send(_ text: String, _ m: Mode) {
        if kitty.ensureTab(m, cwd: cwd(m), state: &state) {
            // Claude was gone and is starting again: keep the text until its SessionStart
            trackers[m]?.markLaunched(now: Date()); onStateChanged?()
            _ = queues[m]?.submit(text, held: true)
            return
        }
        sentByNell[m, default: []].append(text)
        kitty.send(text, to: m)
    }

    private func flushQueue(_ m: Mode) {
        guard trackers[m]?.inputHeld == false else { return }
        for t in queues[m]?.release() ?? [] { send(t, m) }
    }
}
