import Foundation
import Testing
@testable import NellCore

func fixture(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
    return try Data(contentsOf: url)
}

@Test func decodesEveryFixture() throws {
    let dir = try #require(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
    let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        .filter { $0.pathExtension == "json" && !$0.lastPathComponent.hasPrefix("kitty-") && !$0.lastPathComponent.hasPrefix("sprite-") && $0.lastPathComponent != "statusline.json" }
    #expect(files.count >= 10)
    for f in files {
        let e = try HookEvent.decode(Data(contentsOf: f))
        #expect(!e.name.isEmpty, "\(f.lastPathComponent)")
        #expect(!e.sessionId.isEmpty, "\(f.lastPathComponent)")
    }
}

@Test func decodesPreToolUseBash() throws {
    let e = try HookEvent.decode(fixture("PreToolUse-Bash"))
    #expect(e.name == "PreToolUse")
    #expect(e.toolName == "Bash")
    #expect(e.toolUseId?.hasPrefix("toolu_") == true)
    guard case .string(let cmd)? = e.toolInput?["command"] else { Issue.record("no command"); return }
    #expect(cmd == "touch spike-a.txt")
}

@Test func decodesStopAndNotificationFields() throws {
    #expect(try HookEvent.decode(fixture("Stop")).lastAssistantMessage == "Hi there, friend!")
    let n = try HookEvent.decode(fixture("Notification-permission_prompt"))
    #expect(n.notificationType == "permission_prompt")
    #expect(n.message == "Claude needs your permission")
    #expect(try HookEvent.decode(fixture("UserPromptSubmit")).prompt == "say hi in three words")
}
