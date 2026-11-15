import Testing
@testable import NellCore

@Test func firstCodePressFromChatOpensConsole() {
    var c = ConsoleState(); var selected = Mode.chat
    c.pressCodeChip(selected: &selected)
    #expect(selected == .code); #expect(c.phase == .open); #expect(c.tab == .code)
}

@Test func codePressTogglesOpenMinimised() {
    var c = ConsoleState(); var selected = Mode.code
    c.pressCodeChip(selected: &selected); #expect(c.phase == .open)
    c.pressCodeChip(selected: &selected); #expect(c.phase == .minimised)
    c.pressCodeChip(selected: &selected); #expect(c.phase == .open)
}

@Test func chatConnectedReturnsToCodeTabOnlyAfterTheTrustPrompt() {
    var c = ConsoleState()
    c.open(tab: .chat); #expect(c.tab == .chat); #expect(c.phase == .open)
    // a /clear or compaction while you answer a Chat approval there also starts a session: the tab stays
    c.chatConnected(afterTrustPrompt: false); #expect(c.tab == .chat)
    c.chatConnected(afterTrustPrompt: true); #expect(c.tab == .code)
}

@Test func codePressWithTheConsoleOnChatShowsCode() {
    var c = ConsoleState(); var selected = Mode.code
    c.open(tab: .chat); c.pressCodeChip(selected: &selected)
    #expect(c.tab == .code); #expect(c.phase == .open, "switches to Code rather than minimising")
    c.pressCodeChip(selected: &selected); #expect(c.phase == .minimised)
}

@Test func chatterHiddenOnlyForTheTabTheConsoleShows() {
    for k in [BubbleKind.reply, .status, .user] {
        #expect(!showsInColumn(k, mode: .code, consoleShowing: .code))
        #expect(showsInColumn(k, mode: .code, consoleShowing: nil))
        #expect(showsInColumn(k, mode: .chat, consoleShowing: .code))
        // answering a Chat approval in the console: Chat's chatter is there, Code's still needs the column
        #expect(!showsInColumn(k, mode: .chat, consoleShowing: .chat))
        #expect(showsInColumn(k, mode: .code, consoleShowing: .chat))
    }
    for k in [BubbleKind.approval(requestId: "r"), .question, .alert, .error, .consoleNeeded] {
        for m in Mode.allCases { #expect(showsInColumn(k, mode: m, consoleShowing: m)) }
    }
}

@Test func consoleNeededPinnedUntilSettled() {
    var b = BubbleStore()
    b.add(.consoleNeeded, mode: .code, text: "Claude needs you in the console", now: t0)
    b.tick(now: at(1000), userIdle: 0, hovered: nil)
    #expect(b.visible(now: at(1000)).first?.opacity == 1)
    b.settleConsoleNeeded(mode: .chat)
    #expect(b.bubbles.first?.settled == false)
    b.settleConsoleNeeded(mode: .code)
    #expect(b.bubbles.first?.settled == true)
}

@Test func noDecisionOffersConsoleOnlyWhenItIsNotAlreadyOpen() {
    var c = ConsoleState()
    #expect(offersConsoleAfterNoDecision(quiet: false, console: c, mode: .code))  // timed out, console closed
    #expect(!offersConsoleAfterNoDecision(quiet: true, console: c, mode: .code))  // answered in kitty / a question
    c.open(tab: .code)                                                             // you pressed Open terminal
    #expect(!offersConsoleAfterNoDecision(quiet: false, console: c, mode: .code))
    #expect(offersConsoleAfterNoDecision(quiet: false, console: c, mode: .chat))
}
