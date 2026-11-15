import Foundation
import Testing
@testable import NellCore

let sock = "unix:/A/Nell/kitty-42.sock"

@Test func sendTextPipesTextOnStdinSoNoEscapesApply() {
    // kitten @ send-text applies Python escapes to an argv text (\n, \e, \x41…); --stdin sends it as-is.
    let a = KittyCommands.sendText(socket: sock, mode: .code)
    #expect(a.first == KittyCommands.kitten)
    #expect(Array(a.dropFirst()) == ["@", "--to", sock, "send-text", "--match", "var:nell_mode=code", "--bracketed-paste", "enable", "--stdin"])
}

@Test func commandsMatchThePerWindowVarNotTheInheritedEnv() {
    // kitty gives the env tag to every new window (a ⌘T shell too); a user var stays on the window it was set on
    #expect(KittyCommands.focus(socket: sock, mode: .code).suffix(3) == ["focus-window", "--match", "var:nell_mode=code"])
    #expect(KittyCommands.sendEnter(socket: sock, mode: .chat).suffix(4) == ["send-key", "--match", "var:nell_mode=chat", "enter"])
    #expect(Array(KittyCommands.tagFirstWindow(socket: sock).dropFirst())
            == ["@", "--to", sock, "set-user-vars", "--match", "id:1", "nell_mode=code"])
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
    #expect(!windowExists(lsJSON: ls, mode: .code)) // window 1 has the inherited env tag but no var: a stray shell
    #expect(!windowExists(lsJSON: Data("garbage".utf8), mode: .chat))
}

@Test func setColorsCommandShape() {
    #expect(KittyCommands.setColors(socket: "unix:/x", conf: "/A/colors.conf")
            == [KittyCommands.kitten, "@", "--to", "unix:/x", "set-colors", "--all", "--configured", "/A/colors.conf"])
}
