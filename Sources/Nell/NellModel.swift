import AppKit
import NellCore

struct ShownBubble: Identifiable, Equatable { let bubble: Bubble; let opacity: Double; var id: UUID { bubble.id } }

/// The console frame Nell draws around kitty: a border and a title strip.
enum ConsoleChrome { static let border: CGFloat = 4; static let title: CGFloat = 24 }

/// Nell's brain on the main actor: routes hook events into trackers + bubbles, and UI actions into kitty + approvals.
@MainActor final class NellModel: ObservableObject {
    @Published var selected: Mode = .chat
    @Published private(set) var body: NellState = .idle
    @Published private(set) var shown: [ShownBubble] = []
    @Published var draft = ""
    @Published var paused = false
    /// The bar is holding text because Claude has a prompt open in kitty (or is still starting).
    @Published private(set) var barHeld = false
    @Published private(set) var console = ConsoleState()
    @Published private(set) var layout: NellCore.Layout?
    /// What Claude Code is doing right now, for the minimised console bubble.
    @Published private(set) var codeStatus: String?
    var hovered: UUID?
    /// Recomputes where everything goes for a console phase and moves Nell's window (set by the app delegate).
    var relayout: ((ConsolePhase) -> NellCore.Layout)?
    var displayFrame: () -> CGRect = { NSScreen.main?.frame ?? .zero }

    let kitty: KittyController
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

    init(kitty: KittyController, registry: ApprovalRegistry, paths: Paths, state: SavedState) {
        self.kitty = kitty; self.registry = registry; self.paths = paths; self.state = state
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

    /// Every console open comes from a click: ⌘, the minimised bubble, Open console, Answer in console.
    func openConsole(tab: Mode = .code) { console.open(tab: tab); applyConsole() }
    func minimiseConsole() { console.minimise(); applyConsole() }

    func relayoutNow() { if let l = relayout?(console.phase) { layout = l } }

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
        let settled = trackers[m]?.handle(e, requestId: requestId, now: now) ?? []
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
            addBubble(.error, m, e.error ?? "Something went wrong", now)
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

    func refresh() {
        guard let code = trackers[.code], let chat = trackers[.chat] else { return }
        let next = bodyState(selected: selected, code: code, chat: chat, listening: !draft.isEmpty)
        if (next == .needsYou || next == .question), body != next { onNeedsYou?() }
        if body != next { body = next }
        let held = trackers[selected]?.inputHeld ?? false
        if barHeld != held { barHeld = held }
        let nextShown = bubbles.visible(now: Date()).map { ShownBubble(bubble: $0.bubble, opacity: $0.opacity) }
        if nextShown != shown { shown = nextShown } // don't re-render the view every tick
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
