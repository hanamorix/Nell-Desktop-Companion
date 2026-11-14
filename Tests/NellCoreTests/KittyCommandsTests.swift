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

@Test func focusUsesEnvMatch() {
    #expect(KittyCommands.focus(socket: sock, mode: .code).suffix(3) == ["focus-window", "--match", "env:NELL_MODE=code"])
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
