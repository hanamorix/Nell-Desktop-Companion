import Foundation

/// argv arrays for kitty / kitten @ — never shell strings. Windows are found by their NELL_MODE env tag (Claude rewrites titles).
public enum KittyCommands {
    public static let kitty = "/Applications/kitty.app/Contents/MacOS/kitty"
    public static let kitten = "/Applications/kitty.app/Contents/MacOS/kitten"

    static func match(_ m: Mode) -> [String] { ["--match", "env:NELL_MODE=\(m.rawValue)"] }
    static func at(_ socket: String, _ rest: [String]) -> [String] { [kitten, "@", "--to", socket] + rest }

    public static func launchKitty(paths: Paths) -> [String] {
        [kitty, "-c", paths.kittyConf.path, "-o", "allow_remote_control=socket-only",
         "--listen-on", "unix:" + paths.support.appending(path: "kitty-{kitty_pid}.sock").path,
         "--start-as", "hidden", "--session", paths.kittySession.path]
    }

    /// One kitty session-file line that opens the window for `mode`.
    public static func sessionFile(mode: Mode, cwd: String, claude: String, args: [String]) -> String {
        "launch --env NELL_MODE=\(mode.rawValue) --cwd \(shellQuote(cwd)) " + ([claude] + args).map(shellQuote).joined(separator: " ") + "\n"
    }

    public static func launchWindow(socket: String, mode: Mode, cwd: String, claude: String, args: [String]) -> [String] {
        at(socket, ["launch", "--type=os-window", "--keep-focus", "--env", "NELL_MODE=\(mode.rawValue)", "--cwd", cwd, claude] + args)
    }
    public static func sendText(socket: String, mode: Mode, text: String) -> [String] {
        at(socket, ["send-text"] + match(mode) + ["--bracketed-paste", "enable", "--", text])
    }
    public static func sendEnter(socket: String, mode: Mode) -> [String] { at(socket, ["send-key"] + match(mode) + ["enter"]) }
    public static func show(socket: String, mode: Mode) -> [String] { at(socket, ["resize-os-window"] + match(mode) + ["--action", "show"]) }
    public static func hide(socket: String, mode: Mode) -> [String] { at(socket, ["resize-os-window"] + match(mode) + ["--action", "hide"]) }
    public static func toggle(socket: String, mode: Mode) -> [String] {
        at(socket, ["resize-os-window"] + match(mode) + ["--action", "toggle-visibility"])
    }
    public static func focus(socket: String, mode: Mode) -> [String] { at(socket, ["focus-window"] + match(mode)) }
    public static func closeWindow(socket: String, mode: Mode) -> [String] { at(socket, ["close-window"] + match(mode)) }
    public static func ls(socket: String) -> [String] { at(socket, ["ls"]) }

    /// kitty must not inherit a parent Claude Code's env (CLAUDECODE, ANTHROPIC_BASE_URL, …).
    public static func cleanEnvironment(home: String, user: String) -> [String: String] {
        ["HOME": home, "USER": user, "LOGNAME": user, "SHELL": "/bin/zsh", "LANG": "en_US.UTF-8",
         "PATH": "\(home)/.local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"]
    }
}

public func kittyPid(fromSocket s: String) -> Int32? {
    let name = (s as NSString).lastPathComponent
    guard name.hasPrefix("kitty-"), name.hasSuffix(".sock") else { return nil }
    return Int32(name.dropFirst(6).dropLast(5))
}

/// The live kitty socket with the newest pid, if any.
public func pickKittySocket(_ paths: [String], isAlive: (Int32) -> Bool) -> String? {
    paths.compactMap { p in kittyPid(fromSocket: p).map { (p, $0) } }
        .filter { isAlive($0.1) }.max { $0.1 < $1.1 }?.0
}

public func windowExists(lsJSON: Data, mode: Mode) -> Bool {
    guard let osWindows = try? JSONSerialization.jsonObject(with: lsJSON) as? [[String: Any]] else { return false }
    for o in osWindows {
        for t in o["tabs"] as? [[String: Any]] ?? [] {
            for w in t["windows"] as? [[String: Any]] ?? [] where (w["env"] as? [String: String])?["NELL_MODE"] == mode.rawValue {
                return true
            }
        }
    }
    return false
}
