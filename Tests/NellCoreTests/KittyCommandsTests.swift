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
    let env = KittyCommands.cleanEnvironment(home: "/Users/x", user: "x", shell: "/opt/homebrew/bin/fish",
                                             session: ["TMPDIR": "/var/folders/T/", "SSH_AUTH_SOCK": ""])
    #expect(Set(env.keys) == ["HOME", "USER", "LOGNAME", "SHELL", "LANG", "PATH", "TMPDIR"], "an empty value is left out")
    #expect(env["SHELL"] == "/opt/homebrew/bin/fish")
    // launchd's default, as a terminal starts with: your login shell builds the rest, so nothing extra is left in it
    #expect(env["PATH"] == "/usr/bin:/bin:/usr/sbin:/sbin")
}

@Test func loginShellComesFromTheUserRecordOrFallsBackToZsh() {
    let all: (String) -> Bool = { _ in true }
    #expect(KittyCommands.loginShell("/bin/zsh", isExecutable: all) == "/bin/zsh")
    #expect(KittyCommands.loginShell("/bin/bash", isExecutable: all) == "/bin/bash")
    #expect(KittyCommands.loginShell("/opt/homebrew/bin/fish", isExecutable: all) == "/opt/homebrew/bin/fish")
    #expect(KittyCommands.loginShell("/bin/sh", isExecutable: all) == "/bin/sh")
    #expect(KittyCommands.loginShell(nil, isExecutable: all) == "/bin/zsh")
    #expect(KittyCommands.loginShell("", isExecutable: all) == "/bin/zsh")
    #expect(KittyCommands.loginShell("/bin/tcsh", isExecutable: all) == "/bin/zsh", "csh can't take -l with -c")
    #expect(KittyCommands.loginShell("/opt/homebrew/bin/fish", isExecutable: { _ in false }) == "/bin/zsh", "uninstalled")
}

@Test func loginShellArgvPerShell() {
    let posix = #"exec "$0" "$@""#
    #expect(KittyCommands.viaLoginShell("/bin/zsh", ["/c/claude", "--resume", "S"])
            == ["/bin/zsh", "-l", "-i", "-c", posix, "/c/claude", "--resume", "S"])
    #expect(KittyCommands.viaLoginShell("/bin/bash", ["/c/claude"]) == ["/bin/bash", "-l", "-i", "-c", posix, "/c/claude"])
    // fish has no $0/$@: everything after the command is $argv
    #expect(KittyCommands.viaLoginShell("/opt/homebrew/bin/fish", ["/c/claude", "--resume", "S"])
            == ["/opt/homebrew/bin/fish", "-l", "-i", "-c", "exec $argv", "/c/claude", "--resume", "S"])
}

/// The real zsh and bash, from the clean base and an empty home: every argument arrives intact and the shell is gone.
@Test func loginShellPassesArgumentsThroughExactly() throws {
    let home = FileManager.default.temporaryDirectory.appending(path: "nell-shell-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: home) }
    let args = ["[%s]", "two words", "it's", "", "$HOME", "-c", "\"q\""]
    for shell in ["/bin/zsh", "/bin/bash"] {
        let p = Process()
        let argv = KittyCommands.viaLoginShell(shell, ["/usr/bin/printf"] + args)
        p.executableURL = URL(fileURLWithPath: argv[0]); p.arguments = Array(argv.dropFirst())
        p.environment = KittyCommands.cleanEnvironment(home: home.path, user: "nobody", shell: shell, session: [:])
        p.currentDirectoryURL = home
        let out = Pipe(); p.standardOutput = out; p.standardError = FileHandle.nullDevice; p.standardInput = FileHandle.nullDevice
        try p.run()
        let data = out.fileHandleForReading.readDataToEndOfFile(); p.waitUntilExit()
        #expect(String(decoding: data, as: UTF8.self) == "[two words][it's][][$HOME][-c][\"q\"]", "\(shell)")
        #expect(p.terminationStatus == 0, "\(shell)")
    }
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
