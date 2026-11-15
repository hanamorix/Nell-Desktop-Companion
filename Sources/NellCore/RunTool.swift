import Foundation

@discardableResult
public func runTool(_ argv: [String], stdin: Data? = nil) -> (status: Int32, out: Data) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: argv[0])
    p.arguments = Array(argv.dropFirst())
    let out = Pipe(); p.standardOutput = out; p.standardError = FileHandle.nullDevice
    let inp = Pipe(); p.standardInput = stdin == nil ? FileHandle.nullDevice : inp
    // Wait on the exit signal, never with waitUntilExit: that runs the current run loop, so on the main thread a
    // SwiftUI layout pass could read model.state while a caller holds it inout, and Swift aborts (exclusivity).
    let exited = DispatchSemaphore(value: 0)
    p.terminationHandler = { _ in exited.signal() }
    do { try p.run() } catch { return (-1, Data()) } // -1: it never ran (e.g. no free fds), so it says nothing about kitty
    // a kitten that exits without reading (kitty gone) breaks the pipe; its exit status reports the failure
    if let stdin { try? inp.fileHandleForWriting.write(contentsOf: stdin); try? inp.fileHandleForWriting.close() }
    let data = out.fileHandleForReading.readDataToEndOfFile()
    exited.wait()
    return (p.terminationStatus, data)
}
