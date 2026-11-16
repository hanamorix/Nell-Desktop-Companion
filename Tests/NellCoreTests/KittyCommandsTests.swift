import Foundation
import Testing
@testable import NellCore

let sock = "unix:/A/Nell/kitty-42.sock"

@Test func sendTextPipesTextOnStdinSoNoEscapesApply() {
    // kitten @ send-text applies Python escapes to an argv text (\n, \e, \x41…); --stdin sends it as-is.
    let a = KittyCommands().sendText(socket: sock, mode: .code)
    #expect(a.first == KittyCommands().kitten)
    #expect(Array(a.dropFirst()) == ["@", "--to", sock, "send-text", "--match", "var:nell_mode=code", "--bracketed-paste", "enable", "--stdin"])
}

@Test func commandsMatchThePerWindowVarNotTheInheritedEnv() {
    // kitty gives the env tag to every new window (a ⌘T shell too); a user var stays on the window it was set on
    #expect(KittyCommands().focus(socket: sock, mode: .code).suffix(3) == ["focus-window", "--match", "var:nell_mode=code"])
    #expect(KittyCommands().sendEnter(socket: sock, mode: .chat).suffix(4) == ["send-key", "--match", "var:nell_mode=chat", "enter"])
    #expect(Array(KittyCommands().tagFirstWindow(socket: sock).dropFirst())
            == ["@", "--to", sock, "set-user-vars", "--match", "id:1", "nell_mode=code"])
}

@Test func cleanEnvironmentHasNoClaudeVars() {
    let env = KittyCommands.cleanEnvironment(home: "/Users/x", user: "x", shell: "/opt/homebrew/bin/fish",
                                             session: ["TMPDIR": "/var/folders/T/", "SSH_AUTH_SOCK": ""])
    // no LANG: kitty sets it from your macOS language and region, as a terminal does
    #expect(Set(env.keys) == ["HOME", "USER", "LOGNAME", "SHELL", "PATH", "TMPDIR"], "an empty value is left out")
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
    // the folder comes first, so an rc file that cds can't move Claude, and the cd runs your chpwd hooks (direnv, mise)
    #expect(KittyCommands.viaLoginShell("/bin/zsh", cwd: "/p", ["/c/claude", "--resume", "S"])
            == ["/bin/zsh", "-l", "-i", "-c", #"cd "$0"; [ "$PWD" -ef "$0" ] || builtin cd -- "$0"; export SHLVL=$((SHLVL+1)); exec "$@""#, "/p", "/c/claude", "--resume", "S"])
    #expect(KittyCommands.viaLoginShell("/bin/bash", cwd: "/p", ["/c/claude"])
            == ["/bin/bash", "-l", "-i", "-c", #"cd "$0"; [ "$PWD" -ef "$0" ] || builtin cd -- "$0"; eval "${PROMPT_COMMAND:-}"; export SHLVL=$((SHLVL+1)); exec "$@""#, "/p", "/c/claude"])
    #expect(KittyCommands.viaLoginShell("/bin/sh", cwd: "/p", ["/c/claude"])
            == ["/bin/sh", "-l", "-i", "-c", #"cd "$0"; [ "$PWD" -ef "$0" ] || command \cd -- "$0"; eval "${PROMPT_COMMAND:-}"; export SHLVL=$((SHLVL+1)); exec "$@""#, "/p", "/c/claude"], "sh may be dash")
    #expect(KittyCommands.viaLoginShell("/bin/ksh", cwd: "/p", ["/c/claude"]) // ksh and dash leave SHLVL as a terminal does
            == ["/bin/ksh", "-l", "-i", "-c", #"cd "$0"; [ "$PWD" -ef "$0" ] || command \cd -- "$0"; exec "$@""#, "/p", "/c/claude"])
    // fish has no $0/$@: everything after the command is $argv
    #expect(KittyCommands.viaLoginShell("/opt/homebrew/bin/fish", cwd: "/p", ["/c/claude", "--resume", "S"])
            == ["/opt/homebrew/bin/fish", "-l", "-i", "-c", #"cd $argv[1]; test "$PWD" = $argv[1]; or builtin cd $argv[1]; exec $argv[2..-1]"#, "/p", "/c/claude", "--resume", "S"])
}

/// Runs `program` through the real shell from the clean base, in `home` as both HOME and the folder; returns its stdout.
private func throughShell(_ shell: String, home: URL, folder: URL, _ program: [String]) throws -> (out: String, status: Int32) {
    let p = Process()
    let argv = KittyCommands.viaLoginShell(shell, cwd: folder.path, program)
    p.executableURL = URL(fileURLWithPath: argv[0]); p.arguments = Array(argv.dropFirst())
    p.environment = KittyCommands.cleanEnvironment(home: home.path, user: "nobody", shell: shell, session: [:])
    p.currentDirectoryURL = folder
    let out = Pipe(); p.standardOutput = out; p.standardError = FileHandle.nullDevice; p.standardInput = FileHandle.nullDevice
    try p.run()
    let data = out.fileHandleForReading.readDataToEndOfFile(); p.waitUntilExit()
    return (String(decoding: data, as: UTF8.self), p.terminationStatus)
}

/// The real zsh and bash, from the clean base and an empty home: every argument arrives intact and the shell is gone.
@Test func loginShellPassesArgumentsThroughExactly() throws {
    let home = FileManager.default.temporaryDirectory.appending(path: "nell-shell-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: home) }
    let args = ["[%s]", "two words", "it's", "", "$HOME", "-c", "\"q\""]
    for shell in ["/bin/zsh", "/bin/bash"] {
        let r = try throughShell(shell, home: home, folder: home, ["/usr/bin/printf"] + args)
        #expect(r.out == "[two words][it's][][$HOME][-c][\"q\"]", "\(shell)")
        #expect(r.status == 0, "\(shell)")
    }
}

/// rc files that end in `cd /`: Claude still starts in its folder, with the folder's chpwd / PROMPT_COMMAND hooks run
/// (where direnv and mise load a project's environment) and SHLVL 1, as at a terminal prompt.
@Test func loginShellStartsInItsFolderWithYourFolderHooks() throws {
    let home = FileManager.default.temporaryDirectory.appending(path: "nell-shell-\(UUID().uuidString)")
    let folder = home.appending(path: "my project")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: home) }
    try #"chpwd() { export NELL_HOOK="$PWD"; }; cd /"#.write(to: home.appending(path: ".zshrc"), atomically: true, encoding: .utf8)
    try "cd /\nPROMPT_COMMAND='export NELL_HOOK=\"$PWD\"'\n".write(to: home.appending(path: ".bash_profile"), atomically: true, encoding: .utf8)
    for shell in ["/bin/zsh", "/bin/bash"] {
        let env = try throughShell(shell, home: home, folder: folder, ["/usr/bin/env"]).out.split(separator: "\n").map(String.init)
        #expect(env.contains("PWD=\(folder.path)"), "\(shell): in its folder")
        #expect(env.contains("NELL_HOOK=\(folder.path)"), "\(shell): its folder hook ran there")
        #expect(env.contains("SHLVL=1"), "\(shell)")
    }
}

/// Your own `cd` runs first, as at a terminal (nvm's `alias cd=cdnvm`, autoenv and rvm load a folder's environment in
/// it), but whatever it does, Claude starts in its folder: `cd() { builtin cd "$1"; }` with `cd -- dir` would be home.
@Test func loginShellStartsInItsFolderPastYourCdWrappers() throws {
    // CD is the rc's own way past its wrapper: zsh's `command` skips builtins, and dash has no `builtin`
    let loads = [#"cd() { CD "$@" && export NELL_ENTERED="$PWD"; }"#, "cdnvm() { CD \"$@\" && export NELL_ENTERED=\"$PWD\"; }\nalias cd=cdnvm"]
    let hostile = [#"cd() { builtin cd "$1"; }"#, "cd /\ncd() { echo nope; return 1; }", "cd /\nalias cd='echo nope'"]
    for rc in loads + hostile {
        let home = FileManager.default.temporaryDirectory.appending(path: "nell-shell-\(UUID().uuidString)")
        let folder = home.appending(path: "my project")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }
        for (f, cd) in [(".zshrc", "builtin cd"), (".bash_profile", "builtin cd"), (".profile", "command cd")] {
            try (rc.replacingOccurrences(of: "CD", with: cd) + "\n").write(to: home.appending(path: f), atomically: true, encoding: .utf8)
        }
        // /bin/sh can be bash, dash or zsh (/private/var/select/sh): an `sh` named link to each
        var shells = ["/bin/zsh", "/bin/bash", "/bin/ksh", "/bin/dash"]
        for real in ["/bin/bash", "/bin/dash", "/bin/zsh"] {
            let link = home.appending(path: ".as-sh/\((real as NSString).lastPathComponent)/sh")
            try FileManager.default.createDirectory(at: link.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: real)
            shells.append(link.path)
        }
        for shell in shells {
            let env = try throughShell(shell, home: home, folder: folder, ["/usr/bin/env"]).out.split(separator: "\n")
            // the same folder, though a shell that never had to cd again may spell it physically (/private/var/…)
            func at(_ key: String) -> Bool {
                env.contains { $0.hasPrefix(key + "=") && URL(fileURLWithPath: String($0.dropFirst(key.count + 1))).resolvingSymlinksInPath() == folder.resolvingSymlinksInPath() }
            }
            #expect(at("PWD"), "\(shell) with \(rc)")
            if loads.contains(rc) { #expect(at("NELL_ENTERED"), "\(shell) ran your cd with \(rc)") }
        }
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
    #expect(KittyCommands().setColors(socket: "unix:/x", conf: "/A/colors.conf")
            == [KittyCommands().kitten, "@", "--to", "unix:/x", "set-colors", "--all", "--configured", "/A/colors.conf"])
}

@Test func everyKittyPathFollowsTheLocatedApp() {
    let k = KittyCommands(app: "/Users/x/Applications/kitty.app")
    #expect(k.kitty == "/Users/x/Applications/kitty.app/Contents/MacOS/kitty")
    #expect(k.kitten == "/Users/x/Applications/kitty.app/Contents/MacOS/kitten")
    #expect(k.ls(socket: "unix:/s").first == k.kitten)
    #expect(KittyCommands().kitten == "/Applications/kitty.app/Contents/MacOS/kitten", "the default")
    // the hook script raises kitty with this kitten when Nell is down; kitty passes its env to every window
    let a = k.launchPanel(paths: Paths(support: URL(fileURLWithPath: "/A")), request: PanelRequest(marginLeft: 0, marginTop: 0, widthPx: 1, heightPx: 1),
                          cwd: "/p", shell: "/bin/zsh", claude: "/c", args: [])
    #expect(a.first == k.kitten)
    #expect(a.joined(separator: " ").contains("-o env=NELL_KITTEN=/Users/x/Applications/kitty.app/Contents/MacOS/kitten"))
}
