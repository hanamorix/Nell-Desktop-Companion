import Foundation
import Testing
@testable import NellCore

let sock = "unix:/A/Nell/kitty-42.sock"

@Test func sendTextPipesTextOnStdinSoNoEscapesApply() {
    // kitten @ send-text applies Python escapes to an argv text (\n, \e, \x41…); --stdin sends it as-is.
    let a = KittyCommands.sendText(socket: sock, mode: .code)
    #expect(a.first == KittyCommands.kitten)
    #expect(Array(a.dropFirst()) == ["@", "--to", sock, "send-text", "--match", "env:NELL_MODE=code", "--bracketed-paste", "enable", "--stdin"])
}

@Test func showHideToggleUseEnvMatch() {
    #expect(KittyCommands.show(socket: sock, mode: .chat).suffix(4) == ["--match", "env:NELL_MODE=chat", "--action", "show"])
    #expect(KittyCommands.hide(socket: sock, mode: .chat).suffix(2) == ["--action", "hide"])
    #expect(KittyCommands.toggle(socket: sock, mode: .code).suffix(2) == ["--action", "toggle-visibility"])
    #expect(KittyCommands.focus(socket: sock, mode: .code).contains("focus-window"))
}

@Test func sessionFileQuotesArgs() {
    let line = KittyCommands.sessionFile(mode: .code, cwd: "/Users/x/My Proj", claude: "/c/claude", args: ["--tools", "", "--x", "it's"])
    #expect(line == "launch --env NELL_MODE=code --cwd '/Users/x/My Proj' '/c/claude' '--tools' '' '--x' 'it'\\''s'\n")
}

@Test func launchKittyArgs() {
    let p = Paths(support: URL(fileURLWithPath: "/A/Nell"))
    #expect(KittyCommands.launchKitty(paths: p) == [KittyCommands.kitty, "-c", "/A/Nell/kitty.conf", "-o", "allow_remote_control=socket-only",
        "--listen-on", "unix:/A/Nell/kitty-{kitty_pid}.sock", "--start-as", "hidden", "--session", "/A/Nell/kitty.session"])
}

@Test func launchWindowTagsMode() {
    let a = KittyCommands.launchWindow(socket: sock, mode: .chat, cwd: "/A/Nell/chat", claude: "/c/claude", args: ["--resume", "S"])
    #expect(Array(a.dropFirst()) == ["@", "--to", sock, "launch", "--type=os-window", "--keep-focus", "--env", "NELL_MODE=chat",
                                     "--cwd", "/A/Nell/chat", "/c/claude", "--resume", "S"])
}

@Test func cleanEnvironmentHasNoClaudeVars() {
    let env = KittyCommands.cleanEnvironment(home: "/Users/x", user: "x")
    #expect(Set(env.keys) == ["HOME", "USER", "LOGNAME", "SHELL", "LANG", "PATH"])
    #expect(env["PATH"]?.hasPrefix("/Users/x/.local/bin:") == true)
}

@Test func pickKittySocketSkipsDeadPids() {
    let paths = ["/A/kitty-10.sock", "/A/kitty-30.sock", "/A/kitty-20.sock", "/A/nell.sock", "/A/kitty-x.sock"]
    #expect(pickKittySocket(paths, isLive: { _, pid in pid != 30 }) == "/A/kitty-20.sock")
    #expect(pickKittySocket(paths, isLive: { _, _ in false }) == nil)
    // a pid that's alive but whose socket doesn't answer (pid reused by another process) is not kitty
    #expect(pickKittySocket(paths, isLive: { path, _ in path == "/A/kitty-10.sock" }) == "/A/kitty-10.sock")
    #expect(kittyPid(fromSocket: "unix:/A/kitty-42.sock") == 42)
}

@Test func windowExistsFindsModeInLsOutput() throws {
    let ls = try fixture("kitty-ls")
    #expect(windowExists(lsJSON: ls, mode: .chat))
    #expect(!windowExists(lsJSON: ls, mode: .code))
    #expect(!windowExists(lsJSON: Data("garbage".utf8), mode: .chat))
}
