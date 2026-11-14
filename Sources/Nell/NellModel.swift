import AppKit
import NellCore

struct ShownBubble: Identifiable, Equatable { let bubble: Bubble; let opacity: Double; var id: UUID { bubble.id } }

/// Nell's brain on the main actor: routes hook events into trackers + bubbles, and UI actions into kitty + approvals.
@MainActor final class NellModel: ObservableObject {
    @Published var selected: Mode = .chat
    @Published private(set) var body: NellState = .idle
    @Published private(set) var shown: [ShownBubble] = []
    @Published var draft = ""
    @Published var paused = false
    var hovered: UUID?

    let kitty: KittyController
    let registry: ApprovalRegistry
    let paths: Paths
    var state: SavedState
    var onNeedsYou: (() -> Void)?
    var onOpenProject: (() -> Void)?
    var onHide: (() -> Void)?
    var onQuit: (() -> Void)?

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
        bubbles.add(.user, mode: m, text: text, now: Date())
        if let now = queues[m]?.submit(text, held: trackers[m]?.inputHeld ?? false) { send(now, m) }
        refresh()
    }

    /// First click selects the mode; clicking the selected chip shows/hides its kitty window.
    func chip(_ m: Mode) {
        if selected == m { kitty.toggle(m) } else { selected = m }
        refresh()
    }

    func answer(_ requestId: String, _ a: ApprovalAnswer) { registry.answer(id: requestId, a) }

    func openTerminal(_ m: Mode, requestId: String?) {
        if let requestId { registry.answer(id: requestId, .none) }
        kitty.show(m)
    }

    // MARK: Hook events

    func handle(_ m: Mode, _ e: HookEvent, requestId: String?) {
        let now = Date()
        let alertBefore = trackers[m]?.lastAlert
        let settled = trackers[m]?.handle(e, requestId: requestId, now: now) ?? []
        for id in settled {   // answered in kitty, or the turn ended: release the hanging hook too
            settledInKitty.insert(id)
            bubbles.settle(requestId: id, as: "Answered in terminal")
            registry.answer(id: id, .none)
        }
        switch e.name {
        case "UserPromptSubmit":
            bubbles.clearStatus(mode: m)
            if let p = e.prompt {
                if let i = sentByNell[m]?.firstIndex(of: p) { sentByNell[m]?.remove(at: i) } // already shown when typed in the bar
                else { bubbles.add(.user, mode: m, text: p, now: now) }
            }
        case "PreToolUse":
            if e.toolName != "AskUserQuestion" { bubbles.setStatus(mode: m, text: toolSummary(name: e.toolName ?? "", input: e.toolInput), now: now) }
        case "PermissionRequest":
            guard let id = requestId else { break }
            if e.toolName == "AskUserQuestion" {
                questionIds.insert(id)
                registry.answer(id: id, .none) // the picker is already open in kitty
                bubbles.add(.question, mode: m, text: trackers[m]?.pendingQuestion ?? "Claude has a question", now: now)
            } else {
                bubbles.add(.approval(requestId: id), mode: m, text: approvalSummary(name: e.toolName ?? "", input: e.toolInput), now: now)
            }
        case "PostToolUse", "PostToolUseFailure":
            if e.toolName == "AskUserQuestion" { bubbles.settleQuestions(mode: m) }
            if e.name == "PostToolUseFailure" {
                bubbles.setStatus(mode: m, text: toolSummary(name: e.toolName ?? "", input: e.toolInput) + " failed", now: now)
            }
        case "Notification":
            if let a = trackers[m]?.lastAlert, a != alertBefore { bubbles.add(.alert, mode: m, text: a, now: now) }
        case "Stop":
            bubbles.clearStatus(mode: m)
            if let r = e.lastAssistantMessage, !r.isEmpty { bubbles.add(.reply, mode: m, text: r, now: now) }
        case "StopFailure":
            bubbles.clearStatus(mode: m)
            bubbles.add(.error, mode: m, text: e.error ?? "Something went wrong", now: now)
        case "SessionEnd":
            bubbles.clearStatus(mode: m)
            kitty.ensureWindow(m, cwd: cwd(m), state: &state)
        default: break
        }
        flushQueue(m)
        refresh()
    }

    func requestSettled(_ m: Mode, _ id: String, _ a: ApprovalAnswer) {
        trackers[m]?.settleApproval(id, answer: a)
        let quiet = questionIds.remove(id) != nil || settledInKitty.remove(id) != nil
        bubbles.settle(requestId: id, as: a == .allow ? "Allowed" : a == .deny ? "Denied" : "Answer in terminal")
        if a == .none, !quiet { kitty.show(m) } // Open terminal, deadline, or hook died: Claude asks in kitty
        flushQueue(m)
        refresh()
    }

    /// 1 Hz: timers in the trackers, bubble fades, the disconnected nudge.
    func tick(userIdle: TimeInterval) {
        let now = Date()
        for m in Mode.allCases {
            trackers[m]?.tick(now: now)
            let disc = trackers[m]?.state == .disconnected
            if disc, !wasDisconnected.contains(m) { wasDisconnected.insert(m); kitty.show(m) } // e.g. the folder-trust dialog
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
        let nextShown = bubbles.visible(now: Date()).map { ShownBubble(bubble: $0.bubble, opacity: $0.opacity) }
        if nextShown != shown { shown = nextShown } // don't re-render the view every tick
    }

    private func send(_ text: String, _ m: Mode) {
        sentByNell[m, default: []].append(text)
        kitty.ensureWindow(m, cwd: cwd(m), state: &state)
        kitty.send(text, to: m)
    }

    private func flushQueue(_ m: Mode) {
        guard trackers[m]?.inputHeld == false else { return }
        for t in queues[m]?.release() ?? [] { send(t, m) }
    }
}
