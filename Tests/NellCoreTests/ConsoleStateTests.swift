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

@Test func chatConnectedReturnsToCodeTab() {
    var c = ConsoleState()
    c.open(tab: .chat); #expect(c.tab == .chat); #expect(c.phase == .open)
    c.chatConnected(); #expect(c.tab == .code)
    var selected = Mode.code
    c.open(tab: .chat); c.pressCodeChip(selected: &selected)
    #expect(c.tab == .code)
}

@Test func codeChatterHiddenWhileConsoleOpen() {
    for k in [BubbleKind.reply, .status, .user] {
        #expect(!showsInColumn(k, mode: .code, consoleOpen: true))
        #expect(showsInColumn(k, mode: .code, consoleOpen: false))
        #expect(showsInColumn(k, mode: .chat, consoleOpen: true))
    }
    for k in [BubbleKind.approval(requestId: "r"), .question, .alert, .error, .consoleNeeded] {
        #expect(showsInColumn(k, mode: .code, consoleOpen: true))
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
