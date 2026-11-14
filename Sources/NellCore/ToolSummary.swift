import Foundation

/// One short line for the live status bubble while a tool runs.
public func toolSummary(name: String, input: [String: JSONValue]?) -> String {
    func str(_ k: String) -> String? { input?[k]?.string }
    func cut(_ s: String, _ n: Int) -> String { s.count > n ? String(s.prefix(n)) + "…" : s }
    func file() -> String { cut((str("file_path") ?? str("notebook_path")).map { ($0 as NSString).lastPathComponent } ?? "a file", 40) }
    switch name {
    case "Bash": return "Running `\(cut(str("command") ?? "", 40))`"
    case "Edit", "Write", "MultiEdit", "NotebookEdit": return "Editing \(file())"
    case "Read": return "Reading \(file())"
    case "Grep", "Glob": return "Searching for \(cut(str("pattern") ?? "", 40))"
    case "WebFetch": return "Looking up \(cut(str("url").flatMap { URL(string: $0)?.host } ?? "a page", 40))"
    case "WebSearch": return "Looking up \(cut(str("query") ?? "", 40))"
    case "Task", "Agent": return "Delegating: \(cut(str("description") ?? "", 40))"
    default: return "Using \(cut(name, 40))"
    }
}

/// The approval bubble's line: "Wants to run `ls`", built from the live summary.
public func approvalSummary(name: String, input: [String: JSONValue]?) -> String {
    let s = toolSummary(name: name, input: input)
    for (from, to) in [("Running ", "run "), ("Editing ", "edit "), ("Reading ", "read "), ("Searching for ", "search for "),
                       ("Looking up ", "look up "), ("Delegating: ", "delegate: "), ("Using ", "use ")] where s.hasPrefix(from) {
        return "Wants to " + to + s.dropFirst(from.count)
    }
    return "Wants to " + s
}
