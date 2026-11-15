/// Settles the bubbles a hook event answered: approvals the tracker `settled` (answered in kitty, or the turn ended),
/// a question when its tool finishes, and at a turn end every question and console prompt still pinned for that mode.
public func settleBubbles(after e: HookEvent, mode: Mode, settled: [String], in bubbles: inout BubbleStore) {
    for id in settled { bubbles.settle(requestId: id, as: "Answered in console") }
    let turnEnds = SessionTracker.endsTurn(e)
    let questionDone = e.toolName == "AskUserQuestion" && (e.name == "PostToolUse" || e.name == "PostToolUseFailure")
    if turnEnds || questionDone { bubbles.settleQuestions(mode: mode) }
    if turnEnds || e.name == "SessionStart" { bubbles.settleConsoleNeeded(mode: mode) } // Claude is answering again
}
