import Foundation

/// Runs `argv` and returns its exit status and stdout (with `stderr`, its stderr too, interleaved).
/// - Status -1: it never ran (e.g. no free fds), so it says nothing about the tool.
/// - With a `timeout`, status -2: it was still running at the deadline and was killed. A timed-out tool, or a child it
///   left running that still holds stdout, can't hold the caller past the deadline (plus a moment to read the last output).
/// - `cancel` ends it (and every tool run with it after): it then exits with a signal.
/// Kills take the tool's whole process group (Process makes each tool its own group leader), so its children go too.
@discardableResult
public func runTool(_ argv: [String], stdin: Data? = nil, environment: [String: String]? = nil, stderr: Bool = false,
                    timeout: TimeInterval? = nil, cancel: Cancellation? = nil) -> (status: Int32, out: Data) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: argv[0])
    p.arguments = Array(argv.dropFirst())
    if let environment { p.environment = environment }
    let out = Pipe(); p.standardOutput = out; p.standardError = stderr ? out : FileHandle.nullDevice
    let inp = Pipe(); p.standardInput = stdin == nil ? FileHandle.nullDevice : inp
    // Wait on the exit signal, never with waitUntilExit: that runs the current run loop, so on the main thread a
    // SwiftUI layout pass could read model.state while a caller holds it inout, and Swift aborts (exclusivity).
    let exited = DispatchSemaphore(value: 0)
    p.terminationHandler = { _ in exited.signal() }
    do { try p.run() } catch { return (-1, Data()) }
    cancel?.started(p.processIdentifier)
    defer { cancel?.ended() }
    // a kitten that exits without reading (kitty gone) breaks the pipe; its exit status reports the failure
    if let stdin { try? inp.fileHandleForWriting.write(contentsOf: stdin); try? inp.fileHandleForWriting.close() }
    guard let timeout else {
        let data = out.fileHandleForReading.readDataToEndOfFile()
        exited.wait()
        return (p.terminationStatus, data)
    }
    let output = Output(), reader = out.fileHandleForReading, done = DispatchSemaphore(value: 0)
    // its own thread, not a GCD queue: with the pool busy, a queued reader might not even start before the grace runs out
    Thread.detachNewThread {
        while case let d = reader.availableData, !d.isEmpty { output.append(d) }
        done.signal()
    }
    guard exited.wait(timeout: .now() + timeout) == .success else {
        killpg(p.processIdentifier, SIGKILL) // SIGKILL: an interactive shell ignores SIGTERM
        exited.wait()
        return (-2, output.data)
    }
    _ = done.wait(timeout: .now() + 0.5)
    return (p.terminationStatus, output.data)
}

/// Ends a running `runTool` from another thread (a Cancel button), and any started with it afterwards.
public final class Cancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    private var group: pid_t = 0
    public init() {}
    public var isCancelled: Bool { lock.withLock { cancelled } }
    public func cancel() { lock.withLock { cancelled = true; if group > 0 { killpg(group, SIGKILL) } } }
    func started(_ pid: pid_t) { lock.withLock { group = pid; if cancelled { killpg(pid, SIGKILL) } } }
    func ended() { lock.withLock { group = 0 } }
}

private final class Output: @unchecked Sendable {
    private let lock = NSLock()
    private var bytes = Data()
    func append(_ d: Data) { lock.withLock { bytes.append(d) } }
    var data: Data { lock.withLock { bytes } }
}
