import Testing
@testable import NellCore

@Test func summaries() {
    #expect(toolSummary(name: "Bash", input: ["command": .string("npm test")]) == "Running `npm test`")
    #expect(toolSummary(name: "Edit", input: ["file_path": .string("/a/b/auth.ts")]) == "Editing auth.ts")
    #expect(toolSummary(name: "Write", input: ["file_path": .string("/a/b/auth.ts")]) == "Editing auth.ts")
    #expect(toolSummary(name: "MultiEdit", input: ["file_path": .string("auth.ts")]) == "Editing auth.ts")
    #expect(toolSummary(name: "Read", input: ["file_path": .string("/x/auth.ts")]) == "Reading auth.ts")
    #expect(toolSummary(name: "Grep", input: ["pattern": .string("TODO")]) == "Searching for TODO")
    #expect(toolSummary(name: "Glob", input: ["pattern": .string("**/*.swift")]) == "Searching for **/*.swift")
    #expect(toolSummary(name: "WebFetch", input: ["url": .string("https://example.com/a/b")]) == "Looking up example.com")
    #expect(toolSummary(name: "WebSearch", input: ["query": .string("kitty remote control")]) == "Looking up kitty remote control")
    #expect(toolSummary(name: "Task", input: ["description": .string("find bugs")]) == "Delegating: find bugs")
    #expect(toolSummary(name: "Agent", input: ["description": .string("find bugs")]) == "Delegating: find bugs")
    #expect(toolSummary(name: "TodoWrite", input: nil) == "Using TodoWrite")
}

@Test func longCommandCutTo40() {
    let cmd = String(repeating: "a", count: 100)
    #expect(toolSummary(name: "Bash", input: ["command": .string(cmd)]) == "Running `\(String(repeating: "a", count: 40))…`")
}

@Test func hugeWriteStaysShort() {
    let s = toolSummary(name: "Write", input: ["file_path": .string("/x/" + String(repeating: "f", count: 200)), "content": .string(String(repeating: "x", count: 1_000_000))])
    #expect(s.count < 60)
}
