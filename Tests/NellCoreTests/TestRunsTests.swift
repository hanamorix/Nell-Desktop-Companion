import Foundation
import Testing
@testable import NellCore

private func fixture(_ name: String) throws -> HookEvent {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
    return try HookEvent.decode(Data(contentsOf: url))
}

private func post(_ command: String, stdout: String, tool: String = "Bash") -> HookEvent {
    HookEvent(name: "PostToolUse", sessionId: "S", toolName: tool, toolInput: ["command": .string(command)],
              toolResponse: .object(["stdout": .string(stdout), "stderr": .string("")]))
}

private func failure(_ command: String, error: String) -> HookEvent {
    HookEvent(name: "PostToolUseFailure", sessionId: "S", toolName: "Bash",
              toolInput: ["command": .string(command)], error: error)
}

@Test func recognisesTestCommands() {
    for c in ["npm test", "cd app && pytest -q", "swift test --filter X", "scripts/test.sh",
              "python3 -m unittest test_ok -v", "yarn test; echo hi", "cargo test", "npm run test", "npx vitest"] {
        #expect(isTestCommand(c), "\(c)")
    }
    for c in ["npm install", "cat test.txt", "grep test", "echo pytest", "npm testing", "ls && cat test"] {
        #expect(!isTestCommand(c), "\(c)")
    }
}

@Test func pipeDetectionIgnoresQuotedAndOr() {
    #expect(isPiped("pytest | tail"))
    #expect(!isPiped("echo \"a|b\""))
    #expect(!isPiped("echo 'a|b'"))
    #expect(!isPiped("pytest || true"))
}

@Test func passAndFailFromSpikeFixtures() throws {
    #expect(testOutcome(try fixture("PostToolUse-Bash-testpass")) == .pass)
    #expect(testOutcome(try fixture("PostToolUseFailure-Bash-testfail")) == .fail)
    #expect(testOutcome(try fixture("PostToolUse-Bash")) == nil)
}

@Test func pipedTestCommandGivesNoReaction() throws {
    #expect(testOutcome(post("pytest | tail -5", stdout: "some output\n")) == nil)
    #expect(testOutcome(post("pytest | tail -5", stdout: "=== 2 failed in 0.1s ===")) == .fail)
    #expect(testOutcome(post("pytest | tail -5", stdout: "=== 2 passed in 0.1s ===")) == .pass)
    #expect(testOutcome(try fixture("PostToolUse-Bash-testfail-piped")) == .fail)
}

@Test func summaryLinesOverrideCleanExitAndFailureAlwaysFails() {
    #expect(testOutcome(post("pytest; true", stdout: "1 failed, 3 passed")) == .fail)
    #expect(testOutcome(post("npm test", stdout: "Tests:       1 failed, 2 passed, 3 total")) == .fail)
    #expect(testOutcome(post("npm test", stdout: "Tests:       3 passed, 3 total")) == .pass)
    #expect(testOutcome(post("swift test", stdout: "✔ Test run with 5 tests passed after 0.1 seconds.")) == .pass)
    #expect(testOutcome(post("swift test", stdout: "✘ Test run with 5 tests failed after 0.1 seconds.")) == .fail)
    #expect(testOutcome(post("cargo test", stdout: "test result: FAILED. 0 passed; 1 failed")) == .fail)
    #expect(testOutcome(post("go test ./...", stdout: "FAIL\tpkg\t0.1s")) == .fail)
    #expect(testOutcome(post("go test ./...", stdout: "ok  \tpkg\t0.1s")) == .pass)
    #expect(testOutcome(failure("pytest", error: "Exit code 1\n5 passed")) == .fail)
    #expect(testOutcome(failure("pytest", error: "Exit code 2\nno output")) == .fail)
}

@Test func nonTestCommandGivesNil() {
    #expect(testOutcome(post("ls", stdout: "2 failed")) == nil)
    #expect(testOutcome(post("npm test", stdout: "OK", tool: "Read")) == nil)
    #expect(testOutcome(failure("cat missing.txt", error: "Exit code 1\n")) == nil)
    #expect(testOutcome(HookEvent(name: "PreToolUse", sessionId: "S", toolName: "Bash",
                                  toolInput: ["command": .string("npm test")])) == nil)
}
