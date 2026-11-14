/// The console bubble: hidden until you first open it, then open or minimised. It only changes on your clicks
/// (plus switching back to the Code tab once Chat's one-time trust prompt is done).
public struct ConsoleState: Equatable, Sendable {
    public private(set) var phase: ConsolePhase = .hidden
    public private(set) var tab: Mode = .code
    public init() {}

    /// ⌘: from Chat it selects Code and opens the console; in Code it toggles open ↔ minimised.
    public mutating func pressCodeChip(selected: inout Mode) {
        tab = .code
        if selected != .code { selected = .code; phase = .open; return }
        phase = phase == .open ? .minimised : .open
    }

    public mutating func open(tab: Mode = .code) { self.tab = tab; phase = .open }
    public mutating func minimise() { phase = .minimised; tab = .code }
    public mutating func chatConnected() { if tab == .chat { tab = .code } }
}

/// While the console is open it already shows Code's progress, replies and your prompts, so those skip the column.
public func showsInColumn(_ kind: BubbleKind, mode: Mode, consoleOpen: Bool) -> Bool {
    guard mode == .code, consoleOpen else { return true }
    return !(kind == .status || kind == .reply || kind == .user)
}

/// After an approval ends with no decision, offer "Answer in the console" unless that's already moot:
/// it was answered in kitty or was a question (`quiet`), or the console is already open on that tab (Open terminal).
public func offersConsoleAfterNoDecision(quiet: Bool, console: ConsoleState, mode: Mode) -> Bool {
    !quiet && !(console.phase == .open && console.tab == mode)
}
