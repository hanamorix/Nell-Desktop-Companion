import Foundation

public struct Paths: Sendable {
    public let support: URL
    public init(support: URL) { self.support = support }
    public static func standard() -> Paths {
        Paths(support: FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Application Support/Nell"))
    }
    public var nellSocket: URL { support.appending(path: "nell.sock") }
    public var kittyConf: URL { support.appending(path: "kitty.conf") }
    public var kittyColors: URL { support.appending(path: "kitty-colors.conf") }
    public var hookScript: URL { support.appending(path: "nell-hook.sh") }
    public var statusScript: URL { support.appending(path: "nell-status.sh") }
    public var stateFile: URL { support.appending(path: "state.json") }
    public var chatDir: URL { support.appending(path: "chat") }
    public func hooksSettings(_ m: Mode) -> URL { support.appending(path: "hooks-\(m.rawValue).json") }
}

public let hookEvents = ["SessionStart", "UserPromptSubmit", "PreToolUse", "PostToolUse", "PostToolUseFailure",
                         "PermissionRequest", "Notification", "Stop", "StopFailure", "SubagentStop", "SessionEnd",
                         "PreCompact", "PostCompact"]

func shellQuote(_ s: String) -> String { "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'" }

/// Your own status line from ~/.claude/settings.json. Nell's `--settings` replaces it, so her status script runs it for you.
public struct UserStatusLine: Equatable, Sendable {
    public let command: String
    public let padding: Int?
    public init(command: String, padding: Int?) { self.command = command; self.padding = padding }
}

public func userStatusLine(fromSettings data: Data) -> UserStatusLine? {
    guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let s = obj["statusLine"] as? [String: Any],
          s["type"] as? String == "command", let c = s["command"] as? String,
          !c.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
    return UserStatusLine(command: c, padding: s["padding"] as? Int)
}

public func hooksSettingsJSON(script: String, statusScript: String, socket: String, mode: Mode, userStatusLine: UserStatusLine? = nil) -> Data {
    var hooks: [String: Any] = [:]
    for e in hookEvents {
        let timeout = e == "PermissionRequest" ? Timings.hookTimeout : 5
        // the event name as $3, so the script needs no jq (not on macOS before 15)
        let command = "\(shellQuote(script)) \(mode.rawValue) \(shellQuote(socket)) \(shellQuote(e))"
        hooks[e] = [["hooks": [["type": "command", "command": command, "timeout": timeout]]]]
    }
    let status = ([statusScript, socket] + (userStatusLine.map { [$0.command] } ?? [])).map(shellQuote).joined(separator: " ")
    let statusLine: [String: Any] = ["type": "command", "command": status, "padding": userStatusLine?.padding ?? 0]
    return try! JSONSerialization.data(withJSONObject: ["hooks": hooks, "statusLine": statusLine], options: [.prettyPrinted, .sortedKeys])
}

public func claudeArgs(mode: Mode, sessionId: String, resume: Bool, settings: String) -> [String] {
    var a = resume ? ["--resume", sessionId] : ["--session-id", sessionId]
    a += ["--settings", settings]
    // the user's choice: Code always starts in Auto. Chat is full Claude Code in its default permission mode.
    if mode == .code { a += ["--permission-mode", "auto"] }
    return a
}

/// Claude Code's project folder name: every UTF-16 unit that isn't [A-Za-z0-9] becomes "-" (matches its JS regex).
public func transcriptPath(home: URL, cwd: String, sessionId: String) -> URL {
    let munged = String(cwd.utf16.map { u -> Character in
        (u >= 48 && u <= 57) || (u >= 65 && u <= 90) || (u >= 97 && u <= 122) ? Character(UnicodeScalar(u)!) : "-"
    })
    return home.appending(path: ".claude/projects/\(munged)/\(sessionId).jsonl")
}
