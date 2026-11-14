import Foundation

public enum TestOutcome: Equatable, Sendable { case pass, fail }

private let testCommandPatterns: [String] = [
    #"(npm|pnpm|yarn|bun|deno)\s+(run\s+)?test"#,
    #"(python3?\s+-m\s+)?(pytest|unittest)"#,
    #"(swift|cargo|go|mix|gradle|mvn|make)\s+test"#,
    #"(npx\s+)?(jest|vitest|rspec)"#,
    #"(\S*/)?[\w.-]*test[\w.-]*\.sh"#,
].map { "^(?:\($0))(?=\\s|$)" }

/// Splits on `&&` and `;` (a leading `cd x &&` is just another segment) and matches each segment's start.
public func isTestCommand(_ command: String) -> Bool {
    command.replacingOccurrences(of: "&&", with: ";").split(separator: ";").contains { seg in
        let s = seg.trimmingCharacters(in: .whitespaces)
        return testCommandPatterns.contains { s.range(of: $0, options: .regularExpression) != nil }
    }
}

/// True for a `|` outside quotes; `||` doesn't count.
public func isPiped(_ command: String) -> Bool {
    var quote: Character?
    let cs = Array(command)
    var i = 0
    while i < cs.count {
        let c = cs[i]
        if let q = quote { if c == q { quote = nil } }
        else if c == "\"" || c == "'" { quote = c }
        else if c == "|" {
            if i + 1 < cs.count, cs[i + 1] == "|" { i += 1 } else { return true }
        }
        i += 1
    }
    return false
}

private let failSummaries: [String] = [
    #"\b\d+ failed\b"#, #"Tests:.*\bfailed\b"#, #"✘ Test run"#,
    #"test result: FAILED"#, #"^FAIL\b"#, #"^FAILED \("#,
]
private let passSummaries: [String] = [
    #"\b\d+ passed\b"#, #"Tests:.*\bpassed\b"#, #"✔ Test run"#,
    #"test result: ok\."#, #"^ok\s"#, #"^OK\b"#,
]

private func summary(_ out: String) -> TestOutcome? {
    if failSummaries.contains(where: { out.range(of: "(?m)" + $0, options: .regularExpression) != nil }) { return .fail }
    if passSummaries.contains(where: { out.range(of: "(?m)" + $0, options: .regularExpression) != nil }) { return .pass }
    return nil
}

/// A failure summary always wins; exit status is trusted only when the command isn't piped.
public func testOutcome(_ e: HookEvent) -> TestOutcome? {
    guard e.toolName == "Bash", e.name == "PostToolUse" || e.name == "PostToolUseFailure",
          let command = e.toolInput?["command"]?.string, isTestCommand(command) else { return nil }
    let piped = isPiped(command)
    if e.name == "PostToolUseFailure" {
        guard let err = e.error else { return piped ? nil : .fail }
        return summary(err) == .fail || !piped ? .fail : nil
    }
    guard case .object(let r)? = e.toolResponse else { return nil }
    if case .bool(true)? = r["interrupted"] { return nil }
    let out = [r["stdout"]?.string, r["stderr"]?.string].compactMap { $0 }.joined(separator: "\n")
    return summary(out) ?? (piped ? nil : .pass)
}
