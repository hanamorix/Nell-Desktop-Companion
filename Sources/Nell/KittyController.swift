import AppKit
import NellCore

/// Finds a bundled resource: inside Nell.app it's in Contents/Resources; under `swift run` it's in the SwiftPM bundle.
func resourceURL(_ name: String) -> URL {
    if let r = Bundle.main.resourceURL?.appending(path: name), FileManager.default.fileExists(atPath: r.path) { return r }
    return Bundle.module.url(forResource: "Resources", withExtension: nil)!.appending(path: name)
}

@discardableResult
func runTool(_ argv: [String], stdin: Data? = nil) -> (status: Int32, out: Data) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: argv[0])
    p.arguments = Array(argv.dropFirst())
    let out = Pipe(); p.standardOutput = out; p.standardError = FileHandle.nullDevice
    let inp = Pipe(); p.standardInput = stdin == nil ? FileHandle.nullDevice : inp
    do { try p.run() } catch { return (-1, Data()) }
    // a kitten that exits without reading (kitty gone) breaks the pipe; its exit status reports the failure
    if let stdin { try? inp.fileHandleForWriting.write(contentsOf: stdin); try? inp.fileHandleForWriting.close() }
    let data = out.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    return (p.terminationStatus, data)
}

/// Owns Nell's kitty panel: tab 1 runs Claude Code (the console shows it), tab 2 runs Chat (never shown, except
/// once for Chat's first-run trust prompt). The panel starts hidden and only appears inside Nell's console bubble.
/// shortcut: kitten @ calls run synchronously on the main thread (each ~20 ms); move to a queue if they ever stall the UI.
@MainActor final class KittyController {
    let paths: Paths
    private(set) var socket: String?
    private var lastRequest: PanelRequest?
    private var measured = false
    private var shown = false // the console is on screen, so a restarted panel must come back shown
    private let home = FileManager.default.homeDirectoryForCurrentUser
    var claude: String { home.appending(path: ".local/bin/claude").path }

    /// Set by the owner before installSupportFiles runs; decides kitty.conf's colours.
    var theme: Theme = Themes.plumNight

    init(paths: Paths) { self.paths = paths }

    /// Recolours the running kitty's windows. Does nothing when kitty isn't up, and ignores failure (it may have just exited).
    func applyTheme(_ t: Theme) {
        theme = t
        guard let socket else { return }
        do { try kittyColorsConf(t).write(to: paths.kittyColors, atomically: true, encoding: .utf8) } catch { return }
        runTool(KittyCommands.setColors(socket: socket, conf: paths.kittyColors.path))
    }

    /// Writes kitty.conf, the hook and status scripts and both hook settings files into Application Support.
    func installSupportFiles() throws {
        let fm = FileManager.default
        try fm.createDirectory(at: paths.chatDir, withIntermediateDirectories: true)
        for (name, dest) in [("kitty.conf", paths.kittyConf), ("nell-hook.sh", paths.hookScript), ("nell-status.sh", paths.statusScript)] {
            try? fm.removeItem(at: dest)
            try fm.copyItem(at: resourceURL(name), to: dest)
        }
        try kittyColorsConf(theme).write(to: paths.kittyColors, atomically: true, encoding: .utf8) // kitty.conf includes it
        for s in [paths.hookScript, paths.statusScript] { try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: s.path) }
        for m in Mode.allCases {
            try hooksSettingsJSON(script: paths.hookScript.path, statusScript: paths.statusScript.path, socket: paths.nellSocket.path, mode: m).write(to: paths.hooksSettings(m))
        }
    }

    /// Reuses a live kitty (Nell crashed earlier), hidden, or starts the panel hidden with Code, then adds the Chat tab.
    /// Returns true when an already-running kitty was reused (its sessions won't send SessionStart again).
    @discardableResult
    func ensureRunning(projectDir: String, state: inout SavedState) throws -> Bool {
        try installSupportFiles()
        let files = (try? FileManager.default.contentsOfDirectory(atPath: paths.support.path)) ?? []
        let sockets = files.filter { $0.hasPrefix("kitty-") && $0.hasSuffix(".sock") }.map { paths.support.appending(path: $0).path }
        // a live pid isn't enough: after a reboot the pid may belong to another process, so the socket must answer
        let live = pickKittySocket(sockets, isLive: { path, pid in kill(pid, 0) == 0 && runTool(KittyCommands.ls(socket: "unix:" + path)).status == 0 })
        for s in sockets where s != live { unlink(s) }
        if let live {
            socket = "unix:" + live
            hideConsole() // the console phase always starts hidden
            applyTheme(theme)
        } else {
            socket = try startPanel(codeDir: projectDir, state: &state)
        }
        ensureTab(.code, cwd: projectDir, state: &state)
        ensureTab(.chat, cwd: paths.chatDir.path, state: &state)
        return live != nil
    }

    /// Starts the hidden panel with Code as its first window, and returns its socket once kitty answers and Code is tagged.
    /// A restart reopens it where the last one was placed.
    private func startPanel(codeDir: String, state: inout SavedState) throws -> String {
        let request = lastRequest ?? PanelRequest(marginLeft: 100, marginTop: 100, widthPx: 700, heightPx: 420) // re-placed before shown
        let args = sessionArgs(.code, cwd: codeDir, state: &state)
        let argv = KittyCommands.launchPanel(paths: paths, request: request, claude: claude, args: args)
        let p = Process()
        p.executableURL = URL(fileURLWithPath: argv[0]); p.arguments = Array(argv.dropFirst())
        p.environment = KittyCommands.cleanEnvironment(home: home.path, user: NSUserName())
        p.currentDirectoryURL = URL(fileURLWithPath: codeDir)
        p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
        try p.run()
        lastRequest = request
        let path = paths.support.appending(path: "kitty-\(p.processIdentifier).sock").path // kitten panel execs into kitty
        let deadline = Date().addingTimeInterval(30) // a cold login, or Gatekeeper re-checking an updated kitty, is slow
        while Date() < deadline {
            if FileManager.default.fileExists(atPath: path), runTool(KittyCommands.tagFirstWindow(socket: "unix:" + path)).status == 0 {
                return "unix:" + path
            }
            usleep(100_000)
        }
        p.terminate() // an untagged kitty would get a second Code tab beside its own
        throw KittyNotAnswering()
    }

    /// Relaunches a mode's tab if Claude exited or the tab was closed, and kitty itself if it's gone (quit, crashed, or
    /// its last tab closed: `kitten panel` always quits then). Returns true if it launched that mode's Claude.
    @discardableResult
    func ensureTab(_ m: Mode, cwd: String, state: inout SavedState) -> Bool {
        guard var socket else { return false }
        var ls = runTool(KittyCommands.ls(socket: socket))
        let restarted = ls.status != 0
        if restarted {
            let path = String(socket.dropFirst("unix:".count))
            // its socket is still there and its pid alive: kitty is stuck, not gone. It's ours (it answered moments ago),
            // so end it and its Claudes rather than run a second set on the same sessions. A clean quit removes the socket.
            if FileManager.default.fileExists(atPath: path), let pid = kittyPid(fromSocket: socket), kill(pid, 0) == 0 { kill(pid, SIGTERM) }
            unlink(path) // a crashed kitty leaves its socket file behind
            do { socket = try startPanel(codeDir: state.usableProjectDir ?? paths.chatDir.path, state: &state) } catch {
                EventLog.write("kitty restart failed: \(error)") // `socket` keeps the dead path, so the next send retries
                return false
            }
            self.socket = socket
            if shown { runTool(KittyCommands.showPanel(socket: socket)) }
            ls = runTool(KittyCommands.ls(socket: socket))
        }
        guard !windowExists(lsJSON: ls.out, mode: m) else { return restarted } // the new panel's first window is Code
        let args = sessionArgs(m, cwd: cwd, state: &state)
        let launched = runTool(KittyCommands.launchTab(socket: socket, mode: m, cwd: cwd, claude: claude, args: args)).status == 0
        runTool(KittyCommands.focusTab(socket: socket, mode: .code)) // the console always rests on Code
        return launched
    }

    /// Moves and sizes the panel so it covers `content` (AppKit coords) on `display` (its full frame).
    func place(content: CGRect, display: CGRect, cal: PanelCalibration) {
        guard let socket else { return }
        let r = panelRequest(content: content, display: display, cal: cal)
        guard r != lastRequest else { return }
        lastRequest = r
        runTool(KittyCommands.placePanel(socket: socket, request: r))
    }

    /// Shows the console on `tab` and gives it the keyboard. The first time, measures kitty's real frame and returns
    /// the calibration so the caller can store it and re-place.
    func showConsole(tab: Mode) -> PanelCalibration? {
        guard let socket else { return nil }
        shown = true
        runTool(KittyCommands.focusTab(socket: socket, mode: tab))
        runTool(KittyCommands.showPanel(socket: socket))
        runTool(KittyCommands.focus(socket: socket, mode: tab))
        guard !measured, let r = lastRequest, let actual = panelFrameTopLeft() else { return nil }
        measured = true
        return PanelCalibration.measured(requested: CGRect(x: r.marginLeft, y: r.marginTop, width: r.widthPx, height: r.heightPx), actual: actual)
    }

    /// Switch the console's visible tab without showing it or taking the keyboard.
    func selectTab(_ m: Mode) { if let socket { runTool(KittyCommands.focusTab(socket: socket, mode: m)) } }

    func hideConsole() { shown = false; if let socket { runTool(KittyCommands.hidePanel(socket: socket)) } }

    func send(_ text: String, to m: Mode) {
        guard let socket else { return }
        runTool(KittyCommands.sendText(socket: socket, mode: m), stdin: Data(text.utf8))
        runTool(KittyCommands.sendEnter(socket: socket, mode: m))
    }

    func restartCode(in dir: String, state: inout SavedState) {
        guard let socket else { return }
        runTool(KittyCommands.closeTab(socket: socket, mode: .code))
        state.codeSessionId = nil
        state.projectDir = dir
        ensureTab(.code, cwd: dir, state: &state)
    }

    /// Closing windows leaves kitty running, so end the process itself. Sessions resume next launch.
    /// Only while kitty still answers: if it died, its old pid may belong to another process by now.
    func quit() {
        if let socket, runTool(KittyCommands.ls(socket: socket)).status == 0, let pid = kittyPid(fromSocket: socket) { kill(pid, SIGTERM) }
        socket = nil
    }

    /// The panel's on-screen frame in top-left coordinates, from the window server.
    private func panelFrameTopLeft() -> CGRect? {
        guard let socket, let pid = kittyPid(fromSocket: socket),
              let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else { return nil }
        for w in info where (w[kCGWindowOwnerPID as String] as? Int32) == pid {
            if let b = w[kCGWindowBounds as String] as? [String: CGFloat], let width = b["Width"], width > 50 {
                return CGRect(x: b["X"] ?? 0, y: b["Y"] ?? 0, width: width, height: b["Height"] ?? 0)
            }
        }
        return nil
    }

    /// `--resume` the saved session if its transcript exists, otherwise a fresh `--session-id`.
    private func sessionArgs(_ m: Mode, cwd: String, state: inout SavedState) -> [String] {
        let saved = m == .code ? state.codeSessionId : state.chatSessionId
        let resume = saved.map { FileManager.default.fileExists(atPath: transcriptPath(home: home, cwd: cwd, sessionId: $0).path) } ?? false
        let id = resume ? saved! : UUID().uuidString.lowercased()
        if m == .code { state.codeSessionId = id } else { state.chatSessionId = id }
        return claudeArgs(mode: m, sessionId: id, resume: resume, settings: paths.hooksSettings(m).path)
    }
}

struct KittyNotAnswering: Error, CustomStringConvertible {
    var description: String { "kitty didn't answer on its socket within 30 s" }
}
