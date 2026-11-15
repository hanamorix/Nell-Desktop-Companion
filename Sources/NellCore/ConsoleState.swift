/// The console bubble: hidden until you first open it, then open or minimised. It only changes on your clicks
/// (plus switching back to the Code tab once Chat's one-time trust prompt is done).
public struct ConsoleState: Equatable, Sendable {
    public private(set) var phase: ConsolePhase = .hidden
    public private(set) var tab: Mode = .code
    public init() {}

    /// ⌘: from Chat, or with the console on Chat's tab, it selects Code and opens the console on Code; otherwise it
    /// toggles open ↔ minimised.
    public mutating func pressCodeChip(selected: inout Mode) {
        let onCode = selected == .code && tab == .code
        tab = .code
        if !onCode { selected = .code; phase = .open; return }
        phase = phase == .open ? .minimised : .open
    }

    public mutating func open(tab: Mode = .code) { self.tab = tab; phase = .open }
    public mutating func minimise() { phase = .minimised; tab = .code }
    /// Chat's session started. Back to Code only if it was stuck before its first connect (the trust prompt): a /clear
    /// or compaction while you answer a Chat approval in the console also starts one, and must not pull the tab away.
    public mutating func chatConnected(afterTrustPrompt: Bool) { if afterTrustPrompt, tab == .chat { tab = .code } }
}

/// The tab the open console shows already has its progress, replies and your prompts, so those skip the column.
/// `consoleShowing`: that tab, or nil while the console isn't open.
public func showsInColumn(_ kind: BubbleKind, mode: Mode, consoleShowing: Mode?) -> Bool {
    guard mode == consoleShowing else { return true }
    return !(kind == .status || kind == .reply || kind == .user)
}

/// After an approval ends with no decision, offer "Answer in the console" unless that's already moot:
/// it was answered in kitty or was a question (`quiet`), or the console is already open on that tab (Open terminal).
public func offersConsoleAfterNoDecision(quiet: Bool, console: ConsoleState, mode: Mode) -> Bool {
    !quiet && !(console.phase == .open && console.tab == mode)
}
