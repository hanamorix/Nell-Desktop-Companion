import Foundation

/// Pending approval requests, each answered at most once: by a click, or `.none` when its connection closes.
public final class ApprovalRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var waiters: [String: (sem: DispatchSemaphore, answer: ApprovalAnswer?)] = [:]
    private var done: [String: ApprovalAnswer] = [:]

    public init() {}

    public func register(id: String) {
        lock.lock(); defer { lock.unlock() }
        waiters[id] = (DispatchSemaphore(value: 0), nil)
    }

    /// Returns false if the request is unknown or already settled.
    @discardableResult
    public func answer(id: String, _ a: ApprovalAnswer) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard let w = waiters[id], w.answer == nil else { return false }
        waiters[id]?.answer = a
        w.sem.signal()
        return true
    }

    public func closed(id: String) { answer(id: id, .none) }

    /// Blocks until answered or `timeout`; the request is then gone. Timeout counts as `.none`.
    public func wait(id: String, timeout: TimeInterval) -> ApprovalAnswer {
        lock.lock()
        if let d = done[id] { lock.unlock(); return d }
        guard let w = waiters[id] else { lock.unlock(); return .none }
        lock.unlock()
        _ = w.sem.wait(timeout: .now() + timeout)
        lock.lock(); defer { lock.unlock() }
        let a = waiters[id]?.answer ?? .none
        waiters[id]?.answer = a
        waiters.removeValue(forKey: id)
        done[id] = a
        return a
    }

    public var pendingIds: [String] {
        lock.lock(); defer { lock.unlock() }
        return waiters.filter { $0.value.answer == nil }.keys.sorted()
    }
}

public func approvalResponseBody(_ a: ApprovalAnswer) -> Data {
    let decision: [String: String]
    switch a {
    case .none: return Data()
    case .allow: decision = ["behavior": "allow"]
    case .deny: decision = ["behavior": "deny", "message": "Denied from Nell"]
    }
    let obj = ["hookSpecificOutput": ["hookEventName": "PermissionRequest", "decision": decision] as [String: Any]]
    return try! JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys])
}
