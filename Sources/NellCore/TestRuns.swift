import Foundation

public enum TestOutcome: Equatable, Sendable { case pass, fail }

private let testCommandPatterns: [String] = [
    #"(npm|pnpm|yarn|bun|deno)\s+(run\s+)?test"#,
    #"(python3?\s+-m\s+)?(pytest|unittest)"#,
    #"(swift|cargo|go|mix|gradle|mvn|make)\s+test"#,
    #"(npx\s+)?(jest|vitest|rspec)"#,
    #"(\S*/)?([\w.-]*[_.-])?tests?([_.-][\w.-]*)?\.sh"#, // whole word: test.sh, run_tests.sh, test-all.sh; not attestation.sh
].map { "^(?:\($0))(?=\\s|$)" }

/// Splits on `&&` and `;` (a leading `cd x &&` is just another segment) and matches each segment's start.
public func isTestCommand(_ command: String) -> Bool {
    command.replacingOccurrences(of: "&&", with: ";").replacingOccurrences(of: "\n", with: ";").split(separator: ";").contains { seg in
        let s = seg.trimmingCharacters(in: .whitespaces)
        return testCommandPatterns.contains { s.range(of: $0, options: .regularExpression) != nil }
    }
}

private func unquoted(_ command: String) -> String {
    var quote: Character?
    return String(command.map { c in
        if let q = quote { if c == q { quote = nil }; return " " }
        if c == "\"" || c == "'" { quote = c; return " " }
        return c
    })
}

/// True for a `|` outside quotes; `||` doesn't count.
public func isPiped(_ command: String) -> Bool {
    unquoted(command).range(of: #"(?<!\|)\|(?!\|)"#, options: .regularExpression) != nil
}

/// Exit status is trusted only when the test is the last command (or followed solely by `&&`-chained ones):
/// a pipe, `||`, `;`, newline or `&` after the first test segment can mask its failure.
func exitStatusUnreliable(_ command: String) -> Bool {
    let c = unquoted(command).replacingOccurrences(of: #"\d*>&\d*|&>"#, with: " ", options: .regularExpression)
    var start = c.startIndex
    var i = c.startIndex
    while true {
        let atEnd = i == c.endIndex
        if atEnd || c[i] == ";" || c[i] == "\n" || c[i...].hasPrefix("&&") {
            if isTestCommand(String(c[start..<i])) {
                return c[start...].replacingOccurrences(of: "&&", with: "")
                    .range(of: #"[|;&\n]"#, options: .regularExpression) != nil
            }
            if atEnd { return true }
            i = c.index(i, offsetBy: c[i...].hasPrefix("&&") ? 2 : 1)
            start = i
        } else { i = c.index(after: i) }
    }
}

private let failSummaries: [String] = [#"(\d+) failed\b"#, #"(\d+) failures?\b"#]
private let failMarkers: [String] = [#"✘ Test run"#, #"test result: FAILED"#, #"^FAIL\b"#, #"^FAILED \("#, #"^not ok\b"#, #"^# fail [1-9]"#]
private let passCounts: [String] = [#"(\d+) passed\b"#]
private let passMarkers: [String] = [#"✔ Test run"#, #"test result: ok\."#, #"^ok\s"#, #"^OK\b"#]
/// Lines that sum up the whole run with its failure count: the only passes a piped run may show (a pipe can cut the
/// failures off above them). pytest's final line, jest's "Tests:", cargo's "test result:", XCTest's "Executed".
private let wholeRunPasses: [String] = [
    #"^=*\s*(\d+ \w+, )*[1-9]\d* passed\b[^\n]* in [\d.]+s\b"#,
    #"^Tests:[^\n]*\b[1-9]\d* passed\b"#,
    #"test result: ok\. [1-9]\d* passed"#,
    #"Executed [1-9]\d* tests?, with 0 failures"#,
]

private func has(_ out: String, _ p: String) -> Bool { out.range(of: "(?m)" + p, options: .regularExpression) != nil }

/// True when some "N <word>" match has N > 0, so "0 failed" is not a failure.
private func positiveCount(_ out: String, _ p: String) -> Bool {
    guard let re = try? NSRegularExpression(pattern: p) else { return false }
    return re.matches(in: out, range: NSRange(out.startIndex..., in: out)).contains { m in
        Range(m.range(at: 1), in: out).flatMap { Int(out[$0]) }.map { $0 > 0 } ?? false
    }
}

private func summary(_ out: String, piped: Bool) -> TestOutcome? {
    if failMarkers.contains(where: { has(out, $0) }) || failSummaries.contains(where: { positiveCount(out, $0) }) { return .fail }
    if piped { return wholeRunPasses.contains { has(out, $0) } ? .pass : nil }
    if passMarkers.contains(where: { has(out, $0) }) || passCounts.contains(where: { positiveCount(out, $0) }) { return .pass }
    return nil
}

/// `run_in_background`: Claude gets control back at once, so the result isn't known yet (no yawn, no reaction).
func isBackground(_ e: HookEvent) -> Bool { e.toolInput?["run_in_background"] == .bool(true) }

/// A failure summary always wins; exit status is trusted only when the command isn't piped.
public func testOutcome(_ e: HookEvent) -> TestOutcome? {
    guard e.toolName == "Bash", e.name == "PostToolUse" || e.name == "PostToolUseFailure",
          let command = e.toolInput?["command"]?.string, isTestCommand(command), !isBackground(e) else { return nil }
    let piped = exitStatusUnreliable(command)
    if e.name == "PostToolUseFailure" {
        // only a real non-zero exit (the spike's "Exit code N" shape) is a failure: not Esc, not a timeout
        guard e.isInterrupt != true, let err = e.error, err.range(of: #"^Exit code [1-9]"#, options: .regularExpression) != nil else { return nil }
        return summary(err, piped: piped) == .fail || !piped ? .fail : nil
    }
    guard case .object(let r)? = e.toolResponse else { return nil }
    if case .bool(true)? = r["interrupted"] { return nil }
    let out = [r["stdout"]?.string, r["stderr"]?.string].compactMap { $0 }.joined(separator: "\n")
    return summary(out, piped: piped) ?? (piped ? nil : .pass)
}
