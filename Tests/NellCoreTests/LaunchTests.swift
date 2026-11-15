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
    // Code always starts in Auto mode, fresh or resumed; it's a launch flag, so ~/.claude settings stay untouched
    #expect(claudeArgs(mode: .code, sessionId: "S", resume: false, settings: "/s.json")
            == ["--session-id", "S", "--settings", "/s.json", "--permission-mode", "auto"])
    #expect(claudeArgs(mode: .code, sessionId: "S", resume: true, settings: "/s.json")
            == ["--resume", "S", "--settings", "/s.json", "--permission-mode", "auto"])
    #expect(!claudeArgs(mode: .chat, sessionId: "S", resume: true, settings: "/s.json").contains("--permission-mode"))
}

private func hooks(_ data: Data) throws -> [String: [[String: Any]]] {
    let obj = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    return try #require(obj["hooks"] as? [String: [[String: Any]]])
}

@Test func settingsJSONHasPermissionTimeout600() throws {
    let h = try hooks(hooksSettingsJSON(script: "/x/nell-hook.sh", statusScript: "/x/nell-status.sh", socket: "/x/nell.sock", mode: .code))
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
    let h = try hooks(hooksSettingsJSON(script: script, statusScript: "/x/nell-status.sh", socket: sock, mode: .chat))
    let cmd = try #require(((h["Stop"]?.first?["hooks"] as? [[String: Any]])?.first?["command"]) as? String)
    #expect(cmd == "'\(script)' chat '\(sock)' 'Stop'")
}

@Test func settingsCommandPassesEventName() throws {
    // the script reads the event from $3: jq isn't on macOS before 15
    let h = try hooks(hooksSettingsJSON(script: "/x/nell-hook.sh", statusScript: "/x/nell-status.sh", socket: "/x/nell.sock", mode: .code))
    for (e, entry) in h {
        let cmd = try #require((entry.first?["hooks"] as? [[String: Any]])?.first?["command"] as? String)
        #expect(cmd == "'/x/nell-hook.sh' code '/x/nell.sock' '\(e)'")
    }
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

@Test func settingsCarryStatusLine() throws {
    for m in Mode.allCases {
        let data = hooksSettingsJSON(script: "/x/nell-hook.sh", statusScript: "/A B/nell-status.sh", socket: "/A B/nell.sock", mode: m)
        let obj = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let s = try #require(obj["statusLine"] as? [String: Any])
        #expect(s["type"] as? String == "command")
        #expect(s["command"] as? String == "'/A B/nell-status.sh' '/A B/nell.sock'")
        #expect(s["padding"] as? Int == 0)
        let h = try hooks(data)
        #expect(h.count == hookEvents.count)
    }
}

@Test func statusScriptGivesUpQuietly() throws {
    let script = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appending(path: "Sources/Nell/Resources/nell-status.sh").path
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/bin/bash"); p.arguments = [script, "/nonexistent.sock"]
    let inp = Pipe(), out = Pipe(); p.standardInput = inp; p.standardOutput = out
    let t = Date(); try p.run()
    inp.fileHandleForWriting.write(try fixture("statusline")); try inp.fileHandleForWriting.close()
    p.waitUntilExit()
    #expect(p.terminationStatus == 0)
    #expect(out.fileHandleForReading.readDataToEndOfFile().isEmpty)
    #expect(Date().timeIntervalSince(t) < 1)
}
