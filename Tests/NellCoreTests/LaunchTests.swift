import Foundation
import Testing
@testable import NellCore

@Test func chatArgsDisableToolsAndMcp() {
    let a = claudeArgs(mode: .chat, sessionId: "S", resume: false, settings: "/s.json")
    let i = try! #require(a.firstIndex(of: "--tools"))
    #expect(a[i + 1] == "")
    for flag in ["--strict-mcp-config", "--no-chrome", "--append-system-prompt"] { #expect(a.contains(flag)) }
    let j = try! #require(a.firstIndex(of: "--setting-sources"))
    #expect(a[j + 1] == "project")
    for banned in ["--bare", "--safe-mode", "--continue"] { #expect(!a.contains(banned)) }
}

@Test func codeArgsResumeVsNew() {
    #expect(claudeArgs(mode: .code, sessionId: "S", resume: false, settings: "/s.json") == ["--session-id", "S", "--settings", "/s.json"])
    #expect(claudeArgs(mode: .code, sessionId: "S", resume: true, settings: "/s.json") == ["--resume", "S", "--settings", "/s.json"])
}

private func hooks(_ data: Data) throws -> [String: [[String: Any]]] {
    let obj = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    return try #require(obj["hooks"] as? [String: [[String: Any]]])
}

@Test func settingsJSONHasPermissionTimeout600() throws {
    let h = try hooks(hooksSettingsJSON(script: "/x/nell-hook.sh", socket: "/x/nell.sock", mode: .code))
    for e in ["SessionStart", "UserPromptSubmit", "PreToolUse", "PostToolUse", "PostToolUseFailure", "PermissionRequest",
              "Notification", "Stop", "StopFailure", "SubagentStop", "SessionEnd"] { #expect(h[e] != nil, "\(e)") }
    let perm = try #require((h["PermissionRequest"]?.first?["hooks"] as? [[String: Any]])?.first)
    #expect(perm["timeout"] as? Int == 600)
    let stop = try #require((h["Stop"]?.first?["hooks"] as? [[String: Any]])?.first)
    #expect(stop["timeout"] as? Int == 5)
}

@Test func settingsJSONQuotesPathsWithSpaces() throws {
    let script = "/Users/x/Library/Application Support/Nell/nell-hook.sh"
    let sock = "/Users/x/Library/Application Support/Nell/nell.sock"
    let h = try hooks(hooksSettingsJSON(script: script, socket: sock, mode: .chat))
    let cmd = try #require(((h["Stop"]?.first?["hooks"] as? [[String: Any]])?.first?["command"]) as? String)
    #expect(cmd == "'\(script)' chat '\(sock)'")
}

@Test func transcriptPathMungesSpacesAndUnicode() {
    let home = URL(fileURLWithPath: "/Users/x")
    #expect(transcriptPath(home: home, cwd: "/Users/x/My Projects/chat 日本", sessionId: "S").path
            == "/Users/x/.claude/projects/-Users-x-My-Projects-chat---/S.jsonl")
    #expect(transcriptPath(home: home, cwd: "/Users/x/.claude", sessionId: "S").path
            == "/Users/x/.claude/projects/-Users-x--claude/S.jsonl")
}

@Test func standardPathsLiveInApplicationSupport() {
    let p = Paths(support: URL(fileURLWithPath: "/A/Nell"))
    #expect(p.nellSocket.path == "/A/Nell/nell.sock")
    #expect(p.hooksSettings(.chat).path == "/A/Nell/hooks-chat.json")
    #expect(p.chatDir.path == "/A/Nell/chat")
}
