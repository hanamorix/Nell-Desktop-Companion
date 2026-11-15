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
    // Piped, only whole-run summaries with their failure count may cheer (final ruling).
    #expect(testOutcome(post("npm test 2>&1 | tail -6", stdout: "ok 3 - adds\nnot ok 4 - subtracts\n# tests 4\n# pass 3\n# fail 1")) == .fail)
    #expect(testOutcome(post("npm test 2>&1 | tail -3", stdout: "ok 1 - adds\nok 2 - subtracts\n# pass 2")) == nil, "node:test ok lines alone")
    #expect(testOutcome(post("swift test 2>&1 | tail -1", stdout: "✔ Test run with 5 tests passed after 0.1 seconds.")) == nil,
            "XCTest failures may sit above Swift Testing's line")
    #expect(testOutcome(post("python3 -m unittest 2>&1 | tail -1", stdout: "OK")) == nil)
    #expect(testOutcome(post("pytest -q | tail -1", stdout: "5 passed in 0.12s")) == .pass)
    #expect(testOutcome(post("npm test | tail -5", stdout: "Tests:       3 passed, 3 total")) == .pass)
    #expect(testOutcome(post("cargo test | tail -3", stdout: "test result: ok. 12 passed; 0 failed; 0 ignored")) == .pass)
    #expect(testOutcome(post("swift test 2>&1 | tail -2", stdout: "Executed 9 tests, with 0 failures (0 unexpected) in 0.2 (0.3) seconds")) == .pass)
    #expect(testOutcome(post("swift test 2>&1 | tail -2", stdout: "Executed 9 tests, with 2 failures (0 unexpected) in 0.2 (0.3) seconds")) == .fail)
    #expect(testOutcome(post("npm test", stdout: "ok 1 - adds\nnot ok 2 - subtracts")) == .fail, "not ok fails unpiped too")
}

@Test func backgroundTestRunGetsNoReaction() {
    var bg = post("swift test", stdout: "")
    bg.toolInput?["run_in_background"] = .bool(true)
    #expect(testOutcome(bg) == nil, "the result isn't known yet")
    var t = SessionTracker()
    t.handle(HookEvent(name: "UserPromptSubmit", sessionId: "S"), requestId: nil, now: Date())
    t.handle(HookEvent(name: "PreToolUse", sessionId: "S", toolName: "Bash",
                       toolInput: ["command": .string("swift test"), "run_in_background": .bool(true)], toolUseId: "b"), requestId: nil, now: Date())
    #expect(!t.testRunning, "no yawn for a background run")
}

@Test func interruptedOrTimedOutTestGetsNoReaction() {
    var interrupted = failure("pytest", error: "Exit code 1\n2 passed")
    interrupted.isInterrupt = true
    #expect(testOutcome(interrupted) == nil)
    #expect(testOutcome(failure("pytest", error: "Command timed out after 2m 0.0s")) == nil)
    #expect(testOutcome(failure("pytest", error: "Exit code 0")) == nil)
    #expect(testOutcome(failure("pytest", error: "Exit code 1\nno summary")) == .fail)
}

@Test func testScriptsMatchWholeWords() {
    for c in ["scripts/test.sh", "./run_tests.sh", "scripts/test-all.sh", "tests.sh", "ci/unit_test.sh"] {
        #expect(isTestCommand(c), "\(c)")
    }
    for c in ["./deploy-latest.sh", "scripts/attestation.sh", "./contest.sh", "testing.sh"] {
        #expect(!isTestCommand(c), "\(c)")
    }
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

@Test func maskedExitStatusDecidesFromSummaryOnly() {
    for c in ["npm test || true", "pytest || exit 0", "npm test; true", "npm test ; exit 0"] {
        #expect(testOutcome(post(c, stdout: "some output")) == nil, "\(c)")
        #expect(testOutcome(post(c, stdout: "Tests: 2 failed")) == .fail, "\(c)")
    }
    #expect(testOutcome(post("npm test", stdout: "some output")) == .pass)
    #expect(testOutcome(post("echo '||' ; npm test", stdout: "some output")) == .pass)
}

@Test func zeroFailedCountIsNotAFailure() {
    #expect(testOutcome(post("npm test", stdout: "Tests: 0 failed, 5 passed")) == .pass)
    #expect(testOutcome(post("pytest", stdout: "5 passed, 0 failed")) == .pass)
    #expect(testOutcome(post("mvn test | tail", stdout: "Failures: 0, Errors: 0\n0 failures")) == nil)
    #expect(testOutcome(post("pytest | tail", stdout: "0 passed")) == nil)
    #expect(testOutcome(post("npm test", stdout: "Tests: 1 failed, 5 passed")) == .fail)
    #expect(testOutcome(post("npm test", stdout: "3 failures")) == .fail)
}

@Test func exitStatusTrustedOnlyWhenTestIsLastCommand() {
    for c in ["swift test; echo done", "pytest; echo done", "swift test; echo \"exit $?\"", "npm test; npm run lint",
              "pytest\necho done", "pytest &", "npm test & wait", "cd a; npm test; echo ok"] {
        #expect(testOutcome(post(c, stdout: "error: build failed")) == nil, "\(c)")
        #expect(testOutcome(post(c, stdout: "Tests: 1 failed")) == .fail, "\(c)")
    }
    for c in ["swift test", "cd app && pytest -q", "echo a; pytest", "pytest 2>&1", "pytest && echo done", "cd a\nnpm test"] {
        #expect(testOutcome(post(c, stdout: "no summary")) == .pass, "\(c)")
    }
}
