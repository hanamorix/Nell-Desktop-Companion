import Foundation

public struct Paths: Sendable {
    public let support: URL
    public init(support: URL) { self.support = support }
    public static func standard() -> Paths {
        Paths(support: FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Application Support/Nell"))
    }
    public var nellSocket: URL { support.appending(path: "nell.sock") }
    public var kittyConf: URL { support.appending(path: "kitty.conf") }
    public var hookScript: URL { support.appending(path: "nell-hook.sh") }
    public var stateFile: URL { support.appending(path: "state.json") }
    public var chatDir: URL { support.appending(path: "chat") }
    public func hooksSettings(_ m: Mode) -> URL { support.appending(path: "hooks-\(m.rawValue).json") }
}

public let hookEvents = ["SessionStart", "UserPromptSubmit", "PreToolUse", "PostToolUse", "PostToolUseFailure",
                         "PermissionRequest", "Notification", "Stop", "StopFailure", "SubagentStop", "SessionEnd"]

public let chatSystemPrompt = "You are in a plain chat inside Nell, a desktop companion. You have no tools; never write tool-call markup."

func shellQuote(_ s: String) -> String { "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'" }

public func hooksSettingsJSON(script: String, socket: String, mode: Mode) -> Data {
    let command = "\(shellQuote(script)) \(mode.rawValue) \(shellQuote(socket))"
    var hooks: [String: Any] = [:]
    for e in hookEvents {
        let timeout = e == "PermissionRequest" ? Timings.hookTimeout : 5
        hooks[e] = [["hooks": [["type": "command", "command": command, "timeout": timeout]]]]
    }
    return try! JSONSerialization.data(withJSONObject: ["hooks": hooks], options: [.prettyPrinted, .sortedKeys])
}

public func claudeArgs(mode: Mode, sessionId: String, resume: Bool, settings: String) -> [String] {
    var a = resume ? ["--resume", sessionId] : ["--session-id", sessionId]
    a += ["--settings", settings]
    if mode == .chat {
        a += ["--tools", "", "--strict-mcp-config", "--no-chrome", "--setting-sources", "project",
              "--append-system-prompt", chatSystemPrompt]
    }
    return a
}

/// Claude Code's project folder name: every UTF-16 unit that isn't [A-Za-z0-9] becomes "-" (matches its JS regex).
public func transcriptPath(home: URL, cwd: String, sessionId: String) -> URL {
    let munged = String(cwd.utf16.map { u -> Character in
        (u >= 48 && u <= 57) || (u >= 65 && u <= 90) || (u >= 97 && u <= 122) ? Character(UnicodeScalar(u)!) : "-"
    })
    return home.appending(path: ".claude/projects/\(munged)/\(sessionId).jsonl")
}
