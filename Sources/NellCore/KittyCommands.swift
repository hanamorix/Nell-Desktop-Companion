import Foundation

/// argv arrays for kitty / kitten @ — never shell strings (the login shell's fixed `exec` script gets Claude's argv as arguments). Windows are found by their `nell_mode` user var (Claude rewrites
/// titles). The NELL_MODE env tag stays for nell-hook.sh, but kitty copies env into every new window, so Nell never matches it.
public enum KittyCommands {
    public static let kitty = "/Applications/kitty.app/Contents/MacOS/kitty"
    public static let kitten = "/Applications/kitty.app/Contents/MacOS/kitten"

    static func match(_ m: Mode) -> [String] { ["--match", "var:nell_mode=\(m.rawValue)"] }
    static func at(_ socket: String, _ rest: [String]) -> [String] { [kitten, "@", "--to", socket] + rest }

    /// The text goes on stdin: as an argument kitten would apply Python escapes to it (\n, \e, \x41…).
    public static func sendText(socket: String, mode: Mode) -> [String] {
        at(socket, ["send-text"] + match(mode) + ["--bracketed-paste", "enable", "--stdin"])
    }
    // MARK: v2 panel

    public static func launchPanel(paths: Paths, request r: PanelRequest, shell: String, claude: String, args: [String]) -> [String] {
        [kitten, "panel", "--edge", "none", "--margin-left", "\(r.marginLeft)", "--margin-top", "\(r.marginTop)",
         "--columns", "\(r.widthPx)px", "--lines", "\(r.heightPx)px", "--layer", "overlay",
         "-o", "macos_ns_window_layer=NSScreenSaverWindowLevel", "--focus-policy", "on-demand", "--start-as-hidden",
         "-c", paths.kittyConf.path, "-o", "allow_remote_control=socket-only", "-o", "tab_bar_style=hidden",
         "-o", "env=NELL_MODE=code", // a /usr/bin/env wrapper is invisible to kitty's env matching
         "--listen-on", "unix:" + paths.support.appending(path: "kitty-{kitty_pid}.sock").path] + viaLoginShell(shell, [claude] + args)
    }
    public static func launchTab(socket: String, mode: Mode, cwd: String, shell: String, claude: String, args: [String]) -> [String] {
        at(socket, ["launch", "--type=tab", "--keep-focus", "--var", "nell_mode=\(mode.rawValue)", "--env", "NELL_MODE=\(mode.rawValue)",
                    "--cwd", cwd] + viaLoginShell(shell, [claude] + args))
    }

    /// Runs `argv` as the last act of an interactive login shell, so it gets exactly your terminal's environment (your
    /// profile and rc files, PATH and exports). `exec` replaces the shell: the window's process is Claude itself, so its
    /// pid, cwd, hooks and SIGTERM are unchanged.
    public static func viaLoginShell(_ shell: String, _ argv: [String]) -> [String] {
        let script = (shell as NSString).lastPathComponent == "fish" ? "exec $argv" : #"exec "$0" "$@""#
        return [shell, "-l", "-i", "-c", script] + argv
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
    public static func tagFirstWindow(socket: String) -> [String] { at(socket, ["set-user-vars", "--match", "id:1", "nell_mode=code"]) }
    public static func placePanel(socket: String, request r: PanelRequest) -> [String] {
        at(socket, ["resize-os-window", "--action", "os-panel", "--incremental", "margin-left=\(r.marginLeft)",
                    "margin-top=\(r.marginTop)", "columns=\(r.widthPx)px", "lines=\(r.heightPx)px"])
    }
    public static func showPanel(socket: String) -> [String] { at(socket, ["resize-os-window", "--action", "show"]) }
    public static func hidePanel(socket: String) -> [String] { at(socket, ["resize-os-window", "--action", "hide"]) }
    public static func focusTab(socket: String, mode: Mode) -> [String] { at(socket, ["focus-tab"] + match(mode)) }
    public static func closeTab(socket: String, mode: Mode) -> [String] { at(socket, ["close-tab"] + match(mode)) }

    public static func sendEnter(socket: String, mode: Mode) -> [String] { at(socket, ["send-key"] + match(mode) + ["enter"]) }
    public static func focus(socket: String, mode: Mode) -> [String] { at(socket, ["focus-window"] + match(mode)) }
    /// Recolours every window of Nell's kitty from a colour file, both existing and future ones.
    public static func setColors(socket: String, conf: String) -> [String] { at(socket, ["set-colors", "--all", "--configured", conf]) }
    public static func ls(socket: String) -> [String] { at(socket, ["ls"]) }

    /// kitty must not inherit a parent Claude Code's env (CLAUDECODE, ANTHROPIC_BASE_URL, …), or anything else of Nell's.
    /// It starts the way a terminal does, from launchd's: its PATH, and `session` (TMPDIR, SSH_AUTH_SOCK) read from the
    /// system rather than Nell. Your login shell builds the rest on top.
    public static func cleanEnvironment(home: String, user: String, shell: String, session: [String: String]) -> [String: String] {
        ["HOME": home, "USER": user, "LOGNAME": user, "SHELL": shell, "LANG": "en_US.UTF-8", "PATH": "/usr/bin:/bin:/usr/sbin:/sbin"]
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
