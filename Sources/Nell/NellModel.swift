import AppKit
import NellCore

struct ShownBubble: Identifiable, Equatable { let bubble: Bubble; let opacity: Double; var id: UUID { bubble.id } }

/// The console frame Nell draws around kitty: a border and a title strip.
enum ConsoleChrome { static let border: CGFloat = 4; static let title: CGFloat = 24 }

/// Nell's brain on the main actor: routes hook events into trackers + bubbles, and UI actions into kitty + approvals.
@MainActor final class NellModel: ObservableObject {
    @Published var selected: Mode = .chat { didSet { pullReturned() } }
    @Published private(set) var shown: [ShownBubble] = []
    @Published var draft = ""
    /// The screen is locked or asleep, or Nell is hidden: the sprite stops entirely.
    var paused = false { didSet { sprite.paused = paused } }
    /// "Minimise" put her away: every new approval or question brings her back.
    var hidden = false
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
    /// The colour theme; `PN` reads the same one, and the root view rebuilds when this changes.
    @Published private(set) var theme: Theme
    var hovered: UUID?
    /// Recomputes where everything goes for a console phase and moves Nell's window (set by the app delegate).
    var relayout: ((ConsolePhase) -> NellCore.Layout?)?
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
    @Published private var returned = ReturnedText() // published: a mode's chip shows a dot while its text waits
    private var sentByNell: [Mode: [String]] = [.code: [], .chat: []]
    private var questionIds: Set<String> = []
    private var settledInKitty: Set<String> = []
    private var wasDisconnected: Set<Mode> = []
    /// v2's needs-you priority, kept for the sound and bringing her forward.
    private var needsYouState: NellState?
    /// An approval or question arrived since the last refresh (one call to onNeedsYou per prompt).
    private var promptArrived = false
    private var reactions = ReactionState()
    private var context = ContextMeter()
    private var expiry: (at: Date, timer: Timer)?
    /// What the sprite was last asked to show (the showcase checks its steps against it).
    private(set) var pose: (body: Body, face: Face, emoji: Emoji?, stacks: Int) = (.idle, .idle, nil, 0)

    init(kitty: KittyController, registry: ApprovalRegistry, paths: Paths, state: SavedState, sprite: SpriteDriver) {
        self.kitty = kitty; self.registry = registry; self.paths = paths; self.state = state; self.sprite = sprite
        theme = Themes.named(state.theme); PN.theme = theme
        kitty.onFellBackToChatFolder = { [weak self] dir in
            self?.addBubble(.error, .code, "Couldn't open \((dir as NSString).lastPathComponent) — Code is in the chat folder; choose a project folder from the menu", Date())
        }
    }

    /// The same folder kitty's restart uses: one that's gone or can't be entered falls back to the chat folder.
    func cwd(_ m: Mode) -> String { m == .code ? (state.usableProjectDir ?? paths.chatDir.path) : paths.chatDir.path }
    /// Text handed back for this mode waits to join the bar until you switch to it.
    func hasReturnedText(_ m: Mode) -> Bool { returned.isWaiting(for: m) }
    func markLaunched(_ modes: [Mode]) { markStarting(modes); refresh() }
    private func markStarting(_ modes: [Mode]) { let now = Date(); for m in modes { trackers[m]?.markLaunched(now: now) } }

    // MARK: UI actions

    func submit() {
        let text = draft; draft = ""
        let m = selected
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        addBubble(.user, m, text, Date())
        enqueue(text, m)
        refresh()
    }

    func chatChip() { selected = .chat; refresh() }

    /// ⌘: from Chat, select Code and open the console; in Code, toggle open ↔ minimised.
    func codeChip() { let was = console; console.pressCodeChip(selected: &selected); applyConsole(was) }

    /// Every console open comes from a click: ⌘, the minimised bubble, Open console, Answer in the console.
    func openConsole(tab: Mode = .code) { let was = console; console.open(tab: tab); applyConsole(was) }
    func minimiseConsole() { console.minimise(); applyConsole(console) }

    func relayoutNow() { if let l = relayout?(console.phase) { layout = l; sprite.mirrored = l.faceRight } }

    /// Drag with ⌥: the console hides so the two windows never drift apart, and comes back where Nell lands.
    func dragBegan() { if console.phase == .open { kitty.hideConsole() } }
    func dragEnded() { applyConsole(console) }

    /// `was` is the console before this click: if kitty can't be brought up, it goes back to that (never an open frame
    /// with nothing in it; minimised if it was already open).
    private func applyConsole(_ was: ConsoleState) {
        if console.phase == .open, !consoleTabRunning() {
            console = was
            if console.phase == .open { console.minimise() }
        }
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

    /// Opening the console restarts kitty or its tab's Claude if they're gone, as a send does. False when nothing could start.
    private func consoleTabRunning() -> Bool {
        let tab = kitty.ensureTab(console.tab, cwd: cwd(console.tab), state: &state)
        if !tab.launched.isEmpty { markStarting(tab.launched); onStateChanged?() }
        guard tab == .unavailable else { return true }
        addBubble(.error, console.tab, "Claude's console couldn't start. Try again in a moment.", Date())
        return false
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

    /// The question was dismissed in kitty (Esc sends no event): drop it, its bubble, and the bar's hold.
    func dismissQuestion(mode m: Mode) {
        trackers[m]?.dismissQuestion()
        bubbles.settleQuestions(mode: m)
        returnQueueToBar(m) // nothing confirms the picker closed
        refresh()
    }

    /// A hold ended with no event saying Claude's prompt closed, so Enter could still answer it: queued text goes back
    /// into the bar unsent, even if something else still holds this mode (a later Allow would flush it into that prompt).
    private func returnQueueToBar(_ m: Mode) {
        let back = queues[m]?.release(held: false) ?? []
        guard !back.isEmpty else { return }
        giveBack(back, m)
    }

    /// Unsent text goes back to its mode's bar. For a mode you're not on, its chip lights and a bubble says where it went.
    private func giveBack(_ texts: [String], _ m: Mode) {
        for t in texts { bubbles.removeUser(mode: m, text: t) } // shown when typed, never sent
        returned.add(texts, for: m)
        pullReturned()
        if m != selected {
            let name = m == .code ? "Code" : "Chat"
            addBubble(.alert, m, "Your message to \(name) is back in the bar — switch to \(name) to send it", Date())
        }
    }

    /// The selected mode's returned text joins the draft; another mode's waits until you switch to it.
    private func pullReturned() {
        let d = returned.draft(draft, selected: selected)
        if d != draft { draft = d }
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
        settleBubbles(after: e, mode: m, settled: settled, in: &bubbles)
        for id in settled {   // answered in kitty, or the turn ended: release the hanging hook too
            settledInKitty.insert(id)
            registry.answer(id: id, .none)
        }
        switch e.name {
        case "SessionStart":
            if m == .code, state.codeSessionId != e.sessionId { state.codeSessionId = e.sessionId; onStateChanged?() }
            if m == .chat, state.chatSessionId != e.sessionId { state.chatSessionId = e.sessionId; onStateChanged?() }
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
            promptArrived = true
        case "PostToolUseFailure":
            if e.isInterrupt == true { bubbles.clearStatus(mode: m); if m == .code { codeStatus = nil } } // you pressed Esc: not a failure
            else { setStatus(m, toolSummary(name: e.toolName ?? "", input: e.toolInput) + " failed", now) }
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
            let started = kitty.ensureTab(m, cwd: cwd(m), state: &state).launched
            if !started.isEmpty { markStarting(started); onStateChanged?() }
        default: break
        }
        flushQueue(m)
        refresh()
    }

    func requestSettled(_ m: Mode, _ id: String, _ a: ApprovalAnswer) {
        trackers[m]?.settleApproval(id, answer: a, now: Date())
        if a == .allow { reactions.flash(.thumbsup, now: Date()) }
        let quiet = questionIds.remove(id) != nil || settledInKitty.remove(id) != nil
        bubbles.settle(requestId: id, as: a == .allow ? "Allowed" : a == .deny ? "Denied" : "Answer in the console")
        // a deadline or a dead hook: Claude now asks in the console, which only opens when you click
        if a == .none, offersConsoleAfterNoDecision(quiet: quiet, console: console, mode: m) { addBubble(.consoleNeeded, m, "Answer in the console", Date()) }
        flushQueue(m)
        refresh()
    }

    /// 1 Hz: timers in the trackers, bubble fades, the disconnected nudge.
    /// `onScreen`: the bubbles the column placed (one it parked keeps its countdown until it's shown).
    func tick(userIdle: TimeInterval, onScreen: Set<UUID>? = nil) {
        let now = Date()
        for m in Mode.allCases {
            if trackers[m]?.tick(now: now) == true { returnQueueToBar(m) } // the watchdog gave up: never send unattended
            let disc = trackers[m]?.state == .disconnected
            if disc, !wasDisconnected.contains(m) { // e.g. the folder-trust dialog: offer the console, don't open it
                wasDisconnected.insert(m)
                addBubble(.consoleNeeded, m, m == .chat ? "Chat needs a one-time OK" : "Claude needs you in the console", now)
            }
            if !disc { wasDisconnected.remove(m) }
        }
        bubbles.tick(now: now, userIdle: userIdle, hovered: hovered, onScreen: onScreen)
        for m in Mode.allCases where trackers[m]?.lastAlert != nil && !bubbles.bubbles.contains(where: { $0.kind == .alert && $0.mode == m }) {
            trackers[m]?.clearAlert()
        }
        refresh()
    }

    /// Switches the interface and any running console to this theme, and saves the choice.
    func setTheme(_ name: String) {
        let t = Themes.named(name)
        PN.theme = t; theme = t; state.theme = t.id; onStateChanged?()
        kitty.applyTheme(t)
    }

    /// Showcase only: start a scene from a fresh Nell. No real path clears every session, bubble and the console at once.
    func resetForShowcase() {
        setTheme(Themes.plumNight.id)
        trackers = [.code: SessionTracker(), .chat: SessionTracker()]
        bubbles = BubbleStore()
        queues = [.code: InputQueue(), .chat: InputQueue()]; returned = ReturnedText()
        sentByNell = [.code: [], .chat: []]
        questionIds = []; settledInKitty = []; wasDisconnected = []
        reactions = ReactionState(); context = ContextMeter()
        console = ConsoleState(); selected = .chat; draft = ""; codeStatus = nil
        usage = nil
        relayoutNow()
        refresh()
    }

    func usageUpdated(_ r: UsageReading) {
        let merged = usage?.merged(r, now: Date()) ?? r
        if merged != usage { usage = merged }
        refresh()
    }

    func refresh() {
        guard let code = trackers[.code], let chat = trackers[.chat] else { return }
        let now = Date()
        let next = promptWaiting(code: code, chat: chat)
        // a new kind of prompt brings her forward; while she's hidden, so does every new one
        if next != nil, needsYouState != next || promptArrived && hidden { onNeedsYou?() }
        needsYouState = next; promptArrived = false
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

    /// A brief emoji ends on time (2.5 s) without waiting for the next 1 Hz tick or event.
    private func wakeAtExpiry(_ now: Date) {
        let at = reactions.nextExpiry(now: now)
        guard at != expiry?.at else { return }
        expiry?.timer.invalidate(); expiry = nil
        guard let at else { return }
        expiry = (at, Timer.scheduledTimer(withTimeInterval: at.timeIntervalSince(now), repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        })
    }

    private func send(_ text: String, _ m: Mode) {
        let tab = kitty.ensureTab(m, cwd: cwd(m), state: &state)
        if !tab.launched.isEmpty { markStarting(tab.launched); onStateChanged?() } // a restart starts Code too
        switch tab.delivery(for: m) {
        case .now:
            sentByNell[m, default: []].append(text)
            kitty.send(text, to: m)
        case .hold: // Claude was gone and is starting again: keep the text until its SessionStart
            _ = queues[m]?.submit(text, held: true)
        case .giveBack: // kitty is down: writing to its socket would lose the text
            giveBack([text], m)
            addBubble(.error, m, "Claude's console isn't running. Your message is back in the bar.", Date())
        }
    }

    private func flushQueue(_ m: Mode) {
        for t in queues[m]?.release(held: trackers[m]?.inputHeld ?? true) ?? [] { enqueue(t, m) }
    }

    /// Sends now, or queues behind what's waiting. Asks `inputHeld` each time: a send that relaunches Claude holds the rest.
    private func enqueue(_ text: String, _ m: Mode) {
        if let now = queues[m]?.submit(text, held: trackers[m]?.inputHeld ?? false) { send(now, m) }
    }
}
