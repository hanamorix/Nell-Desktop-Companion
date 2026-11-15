import Foundation

/// argv arrays for kitty / kitten @ — never shell strings (the login shell's fixed script gets Claude's argv as its
/// arguments). Windows are found by their `nell_mode` user var (Claude rewrites titles). The NELL_MODE env tag stays
/// for nell-hook.sh, but kitty copies env into every new window, so Nell never matches it.
/// Every path comes from `app`, the kitty.app Nell found (or installed).
public struct KittyCommands: Sendable {
    public let app: String
    public init(app: String = "/Applications/kitty.app") { self.app = app }
    public var kitty: String { app + "/Contents/MacOS/kitty" }
    public var kitten: String { app + "/Contents/MacOS/kitten" }

    func match(_ m: Mode) -> [String] { ["--match", "var:nell_mode=\(m.rawValue)"] }
    func at(_ socket: String, _ rest: [String]) -> [String] { [kitten, "@", "--to", socket] + rest }

    /// The text goes on stdin: as an argument kitten would apply Python escapes to it (\n, \e, \x41…).
    public func sendText(socket: String, mode: Mode) -> [String] {
        at(socket, ["send-text"] + match(mode) + ["--bracketed-paste", "enable", "--stdin"])
    }
    // MARK: v2 panel

    public func launchPanel(paths: Paths, request r: PanelRequest, cwd: String, shell: String, claude: String, args: [String]) -> [String] {
        [kitten, "panel", "--edge", "none", "--margin-left", "\(r.marginLeft)", "--margin-top", "\(r.marginTop)",
         "--columns", "\(r.widthPx)px", "--lines", "\(r.heightPx)px", "--layer", "overlay",
         "-o", "macos_ns_window_layer=NSScreenSaverWindowLevel", "--focus-policy", "on-demand", "--start-as-hidden",
         "-c", paths.kittyConf.path, "-o", "allow_remote_control=socket-only", "-o", "tab_bar_style=hidden",
         "-o", "env=NELL_MODE=code", // a /usr/bin/env wrapper is invisible to kitty's env matching
         "-o", "env=NELL_KITTEN=" + kitten, // nell-hook.sh raises kitty with it when Nell is down
         "--listen-on", "unix:" + paths.support.appending(path: "kitty-{kitty_pid}.sock").path] + Self.viaLoginShell(shell, cwd: cwd, [claude] + args)
    }
    public func launchTab(socket: String, mode: Mode, cwd: String, shell: String, claude: String, args: [String]) -> [String] {
        at(socket, ["launch", "--type=tab", "--keep-focus", "--var", "nell_mode=\(mode.rawValue)", "--env", "NELL_MODE=\(mode.rawValue)",
                    "--cwd", cwd] + Self.viaLoginShell(shell, cwd: cwd, [claude] + args))
    }

    /// Runs `argv` in `cwd` as the last act of an interactive login shell, so it gets exactly your terminal's environment
    /// (your profile and rc files, PATH and exports). `exec` replaces the shell: the window's process is Claude itself, so
    /// its pid, cwd, hooks and SIGTERM are unchanged.
    /// - The folder is the first argument and the script cds into it: an rc file that cds can't move Claude, and the cd
    ///   runs your chpwd hooks (zsh; fish's PWD handlers), where direnv and mise load the folder's environment. `;`, not
    ///   `&&`: a folder it can't enter shows the error and still starts Claude, never a dead tab.
    /// - bash's own per-prompt hooks live in PROMPT_COMMAND, which `-c` never runs, so it runs once here.
    ///   shortcut: an array PROMPT_COMMAND (bash 5.1+) runs only its first entry; loop over it if someone needs more.
    /// - zsh and bash lower SHLVL on exec, so it's raised first: Claude sees 1, as from a terminal prompt.
    public static func viaLoginShell(_ shell: String, cwd: String, _ argv: [String]) -> [String] {
        let script = switch (shell as NSString).lastPathComponent {
        case "fish": "cd $argv[1]; exec $argv[2..-1]"
        case "zsh": #"cd -- "$0"; export SHLVL=$((SHLVL+1)); exec "$@""#
        case "bash", "sh": #"cd -- "$0"; eval "${PROMPT_COMMAND:-}"; export SHLVL=$((SHLVL+1)); exec "$@""# // macOS's sh is bash
        default: #"cd -- "$0"; exec "$@""#
        }
        return [shell, "-l", "-i", "-c", script, cwd] + argv
    }

    /// Your login shell (from the user record, not $SHELL), if it's one `viaLoginShell` can drive; otherwise zsh.
    /// shortcut: csh/tcsh (can't combine -l with -c), nu, xonsh and the like start Claude from zsh instead; add a form per shell if asked.
    public static func loginShell(_ pwShell: String?, isExecutable: (String) -> Bool = FileManager.default.isExecutableFile(atPath:)) -> String {
        let known = ["zsh", "bash", "sh", "ksh", "mksh", "dash", "fish"]
        guard let s = pwShell, known.contains((s as NSString).lastPathComponent), isExecutable(s) else { return "/bin/zsh" }
        return s
    }
    public static func userLoginShell() -> String { loginShell(getpwuid(getuid()).flatMap { $0.pointee.pw_shell.map { String(cString: $0) } }) }
    /// `kitten panel` has no --var, so the panel's first window (Code, id 1 in a fresh kitty) is tagged once kitty answers.
    public func tagFirstWindow(socket: String) -> [String] { at(socket, ["set-user-vars", "--match", "id:1", "nell_mode=code"]) }
    public func placePanel(socket: String, request r: PanelRequest) -> [String] {
        at(socket, ["resize-os-window", "--action", "os-panel", "--incremental", "margin-left=\(r.marginLeft)",
                    "margin-top=\(r.marginTop)", "columns=\(r.widthPx)px", "lines=\(r.heightPx)px"])
    }
    public func showPanel(socket: String) -> [String] { at(socket, ["resize-os-window", "--action", "show"]) }
    public func hidePanel(socket: String) -> [String] { at(socket, ["resize-os-window", "--action", "hide"]) }
    public func focusTab(socket: String, mode: Mode) -> [String] { at(socket, ["focus-tab"] + match(mode)) }
    public func closeTab(socket: String, mode: Mode) -> [String] { at(socket, ["close-tab"] + match(mode)) }

    public func sendEnter(socket: String, mode: Mode) -> [String] { at(socket, ["send-key"] + match(mode) + ["enter"]) }
    public func focus(socket: String, mode: Mode) -> [String] { at(socket, ["focus-window"] + match(mode)) }
    /// Recolours every window of Nell's kitty from a colour file, both existing and future ones.
    public func setColors(socket: String, conf: String) -> [String] { at(socket, ["set-colors", "--all", "--configured", conf]) }
    public func ls(socket: String) -> [String] { at(socket, ["ls"]) }

    /// kitty must not inherit a parent Claude Code's env (CLAUDECODE, ANTHROPIC_BASE_URL, …), or anything else of Nell's.
    /// It starts the way a terminal does, from launchd's: its PATH, and `session` (TMPDIR, SSH_AUTH_SOCK) read from the
    /// system rather than Nell. Your login shell builds the rest on top.
    public static func cleanEnvironment(home: String, user: String, shell: String, session: [String: String]) -> [String: String] {
        // no LANG: kitty sets it from your macOS language and region when it's missing, as a terminal does
        ["HOME": home, "USER": user, "LOGNAME": user, "SHELL": shell, "PATH": "/usr/bin:/bin:/usr/sbin:/sbin"]
            .merging(session.filter { !$0.value.isEmpty }) { a, _ in a }
    }
}

public func kittyPid(fromSocket s: String) -> Int32? {
    let name = (s as NSString).lastPathComponent
    guard name.hasPrefix("kitty-"), name.hasSuffix(".sock") else { return nil }
    return Int32(name.dropFirst(6).dropLast(5))
}

/// The live kitty socket with the newest pid, if any. `isLive` should check the socket answers, not just that the pid exists.
public func pickKittySocket(_ paths: [String], isLive: (String, Int32) -> Bool) -> String? {
    paths.compactMap { p in kittyPid(fromSocket: p).map { (p, $0) } }
        .sorted { $0.1 > $1.1 }.first { isLive($0.0, $0.1) }?.0
}

/// The working directory kitty reports for the window tagged with this mode, if there is one.
public func windowCwd(lsJSON: Data, mode: Mode) -> String? { taggedWindow(lsJSON, mode)?["cwd"] as? String }

public func windowExists(lsJSON: Data, mode: Mode) -> Bool { taggedWindow(lsJSON, mode) != nil }

private func taggedWindow(_ lsJSON: Data, _ mode: Mode) -> [String: Any]? {
    guard let osWindows = try? JSONSerialization.jsonObject(with: lsJSON) as? [[String: Any]] else { return nil }
    for o in osWindows {
        for t in o["tabs"] as? [[String: Any]] ?? [] {
            for w in t["windows"] as? [[String: Any]] ?? [] where (w["user_vars"] as? [String: String])?["nell_mode"] == mode.rawValue {
                return w
            }
        }
    }
    return nil
}
