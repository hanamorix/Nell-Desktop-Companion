import AppKit
import NellCore

/// Finds a bundled resource: inside Nell.app it's in Contents/Resources; under `swift run` it's in the SwiftPM bundle.
func resourceURL(_ name: String) -> URL {
    if let r = Bundle.main.resourceURL?.appending(path: name), FileManager.default.fileExists(atPath: r.path) { return r }
    return Bundle.module.url(forResource: "Resources", withExtension: nil)!.appending(path: name)
}

/// Owns Nell's kitty panel: tab 1 runs Claude Code, tab 2 runs Chat, each through your login shell. The console rests on
/// Code and shows Chat when Chat needs you there (its first-run trust prompt, an approval or a question you answer there).
/// The panel starts hidden and only appears inside Nell's console bubble.
/// shortcut: kitten @ calls run synchronously on the main thread (each ~20 ms); move to a queue if they ever stall the UI.
@MainActor final class KittyController {
    let paths: Paths
    private(set) var socket: String?
    private var lastRequest: PanelRequest?
    private var measured = false
    private var shown = false // the console is on screen, so a restarted panel must come back shown
    private var tab: Mode = .code // the tab the console last showed
    private var restartFailedAt: Date?
    private let home = FileManager.default.homeDirectoryForCurrentUser
    var claude: String { home.appending(path: ".local/bin/claude").path }
    private let shell = KittyCommands.userLoginShell()

    /// Set by the owner before installSupportFiles runs; decides kitty.conf's colours.
    var theme: Theme = Themes.plumNight
    /// kitty couldn't start in this project folder, so Code started in the chat folder instead.
    var onFellBackToChatFolder: ((String) -> Void)?
    /// Code runs outside the saved project folder (a fallback): its session ids aren't the project's, so none is saved.
    private(set) var codeAway = false

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
        // read-only: Nell's --settings replaces your status line, so her status script runs yours (read at each launch)
        let yours = (try? Data(contentsOf: home.appending(path: ".claude/settings.json"))).flatMap(userStatusLine(fromSettings:))
        for m in Mode.allCases {
            try hooksSettingsJSON(script: paths.hookScript.path, statusScript: paths.statusScript.path, socket: paths.nellSocket.path, mode: m,
                                  userStatusLine: yours).write(to: paths.hooksSettings(m))
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
        var ls = (status: Int32(0), out: Data())
        var live = pickKittySocket(sockets, isLive: { path, pid in
            guard kill(pid, 0) == 0 else { return false }
            ls = runTool(KittyCommands.ls(socket: "unix:" + path)); return ls.status == 0 || ls.status == -1 // -1 ends the search
        })
        // kitten never ran (no free fds): that kitty may be alive, so neither unlink its socket nor start a second one
        if ls.status == -1 { throw KittenWontRun() }
        // a kitty from a Nell before windows were tagged: reused, each of its Claudes would get a second one beside it
        if let l = live, !Mode.allCases.contains(where: { windowExists(lsJSON: ls.out, mode: $0) }) {
            if let pid = kittyPid(fromSocket: l), isKitty(pid) { kill(pid, SIGTERM) } // ours: Nell's folder, kitty's binary
            live = nil
        }
        for s in sockets where s != live { unlink(s) }
        if let live {
            socket = "unix:" + live
            // its Code may still be in the chat-folder fallback: ask kitty where it really runs (none yet: ensureTab decides)
            codeAway = windowCwd(lsJSON: ls.out, mode: .code).map { !state.ownsCodeSession(cwd: $0) } ?? false
            hideConsole() // the console phase always starts hidden
            applyTheme(theme)
        } else {
            socket = try startPanel(codeDir: projectDir, state: &state, wait: 30) // a cold login, or Gatekeeper re-checking kitty, is slow
        }
        ensureTab(.code, cwd: projectDir, state: &state)
        ensureTab(.chat, cwd: paths.chatDir.path, state: &state)
        return live != nil
    }

    /// Starts the hidden panel with Code as its first window, and returns its socket once kitty answers and Code is tagged.
    /// A restart reopens it where the last one was placed. `wait` bounds the poll (it blocks the main thread).
    private func startPanel(codeDir: String, state: inout SavedState, wait: TimeInterval) throws -> String {
        let request = lastRequest ?? PanelRequest(marginLeft: 100, marginTop: 100, widthPx: 700, heightPx: 420) // re-placed before shown
        let args = sessionArgs(.code, cwd: codeDir, state: &state)
        let argv = KittyCommands.launchPanel(paths: paths, request: request, shell: shell, claude: claude, args: args)
        let p = Process()
        p.executableURL = URL(fileURLWithPath: argv[0]); p.arguments = Array(argv.dropFirst())
        p.environment = KittyCommands.cleanEnvironment(home: home.path, user: NSUserName(), shell: shell, session: sessionEnvironment())
        p.currentDirectoryURL = URL(fileURLWithPath: codeDir)
        p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
        do { try p.run() } catch where codeDir != paths.chatDir.path {
            // the folder passed the check but can't be entered (a privacy denial, or it changed since): never quit over
            // it. Only the cwd differs on the retry, so if that starts, the folder was the cause.
            EventLog.write("kitty couldn't start in \(codeDir): \(error)")
            let s = try startPanel(codeDir: paths.chatDir.path, state: &state, wait: wait) // its own --resume lookup
            onFellBackToChatFolder?(codeDir)
            return s
        }
        lastRequest = request
        let path = paths.support.appending(path: "kitty-\(p.processIdentifier).sock").path // kitten panel execs into kitty
        let deadline = Date().addingTimeInterval(wait)
        while Date() < deadline {
            if FileManager.default.fileExists(atPath: path), runTool(KittyCommands.tagFirstWindow(socket: "unix:" + path)).status == 0 {
                return "unix:" + path
            }
            usleep(100_000)
        }
        p.terminate() // an untagged kitty would get a second Code tab beside its own
        throw KittyNotAnswering(wait: wait)
    }

    /// Relaunches a mode's tab if Claude exited or the tab was closed, and kitty itself if it's gone (quit, crashed, or
    /// its last tab closed: `kitten panel` always quits then). Reports every Claude it started: a restarted kitty starts
    /// Code as its first window, whichever mode asked.
    @discardableResult
    func ensureTab(_ m: Mode, cwd: String, state: inout SavedState) -> TabCheck {
        guard var socket else { return .ready } // never started (the showcase): every kitty call is a no-op
        var ls = runTool(KittyCommands.ls(socket: socket))
        // kitten never ran (no free fds): kitty may be fine and mid-turn, so don't end it; nothing can take text right now
        if ls.status == -1 { return .unavailable }
        let restarted = ls.status != 0
        if restarted {
            // after a failed restart, try again at most every 30 s, so a kitty that won't start can't freeze every send
            if let t = restartFailedAt, Date().timeIntervalSince(t) < 30 { return .unavailable }
            let path = String(socket.dropFirst("unix:".count))
            // its socket is still there and its pid is kitty: it's stuck, not gone. It's ours (it answered moments ago),
            // so end it and its Claudes rather than run a second set on the same sessions. A clean quit removes the socket.
            if FileManager.default.fileExists(atPath: path), let pid = kittyPid(fromSocket: socket), isKitty(pid) { kill(pid, SIGTERM) }
            unlink(path) // a crashed kitty leaves its socket file behind
            do { socket = try startPanel(codeDir: state.usableProjectDir ?? paths.chatDir.path, state: &state, wait: 5) } catch {
                EventLog.write("kitty restart failed: \(error)") // `socket` keeps the dead path, so a later send retries
                restartFailedAt = Date()
                return .unavailable
            }
            restartFailedAt = nil
            self.socket = socket
            if shown { runTool(KittyCommands.showPanel(socket: socket)) }
            ls = runTool(KittyCommands.ls(socket: socket))
        }
        let started: [Mode] = restarted ? [.code] : [] // the new panel's first window is Code
        guard !windowExists(lsJSON: ls.out, mode: m) else { return started.isEmpty ? .ready : .launched(started) }
        let args = sessionArgs(m, cwd: cwd, state: &state)
        let launched = runTool(KittyCommands.launchTab(socket: socket, mode: m, cwd: cwd, shell: shell, claude: claude, args: args)).status == 0
        runTool(KittyCommands.focusTab(socket: socket, mode: tab)) // the console stays on the tab it shows
        let all = started + (launched ? [m] : [])
        return all.isEmpty ? .unavailable : .launched(all)
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
        shown = true; self.tab = tab
        runTool(KittyCommands.focusTab(socket: socket, mode: tab))
        runTool(KittyCommands.showPanel(socket: socket))
        runTool(KittyCommands.focus(socket: socket, mode: tab))
        guard !measured, let r = lastRequest, let actual = panelFrameTopLeft() else { return nil }
        measured = true
        return PanelCalibration.measured(requested: CGRect(x: r.marginLeft, y: r.marginTop, width: r.widthPx, height: r.heightPx), actual: actual)
    }

    /// Switch the console's visible tab without showing it or taking the keyboard.
    func selectTab(_ m: Mode) { tab = m; if let socket { runTool(KittyCommands.focusTab(socket: socket, mode: m)) } }

    func hideConsole() { shown = false; if let socket { runTool(KittyCommands.hidePanel(socket: socket)) } }

    func send(_ text: String, to m: Mode) {
        guard let socket else { return }
        runTool(KittyCommands.sendText(socket: socket, mode: m), stdin: Data(text.utf8))
        runTool(KittyCommands.sendEnter(socket: socket, mode: m))
    }

    func restartCode(in dir: String, state: inout SavedState) {
        guard let socket else { return }
        runTool(KittyCommands.closeTab(socket: socket, mode: .code))
        state.chooseProject(dir)
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

    /// What a terminal inherits from launchd but a login shell doesn't set, read from the system rather than Nell's env.
    private func sessionEnvironment() -> [String: String] {
        var tmp = [CChar](repeating: 0, count: Int(PATH_MAX))
        let tmpdir = confstr(_CS_DARWIN_USER_TEMP_DIR, &tmp, tmp.count) > 0 ? String(cString: tmp) : ""
        let agent = String(decoding: runTool(["/bin/launchctl", "getenv", "SSH_AUTH_SOCK"]).out, as: UTF8.self)
        return ["TMPDIR": tmpdir, "SSH_AUTH_SOCK": agent.trimmingCharacters(in: .whitespacesAndNewlines)]
    }

    /// `--resume` the saved session if its transcript exists, otherwise a fresh `--session-id`.
    /// A Code launch outside the saved project gets a fresh id that isn't saved, so the project's session still resumes.
    private func sessionArgs(_ m: Mode, cwd: String, state: inout SavedState) -> [String] {
        let owns = m == .chat || state.ownsCodeSession(cwd: cwd)
        if m == .code { codeAway = !owns }
        let saved = !owns ? nil : m == .code ? state.codeSessionId : state.chatSessionId
        let resume = saved.map { FileManager.default.fileExists(atPath: transcriptPath(home: home, cwd: cwd, sessionId: $0).path) } ?? false
        let id = resume ? saved! : UUID().uuidString.lowercased()
        if m == .chat { state.chatSessionId = id } else if owns { state.codeSessionId = id }
        return claudeArgs(mode: m, sessionId: id, resume: resume, settings: paths.hooksSettings(m).path)
    }
}

struct KittenWontRun: Error, CustomStringConvertible {
    var description: String { "kitten couldn't be started to check the running kitty" }
}

struct KittyNotAnswering: Error, CustomStringConvertible {
    let wait: TimeInterval
    var description: String { "kitty didn't answer on its socket within \(Int(wait)) s" }
}

/// The pid still runs a kitty.app binary, not another process that reused a crashed kitty's pid.
func isKitty(_ pid: Int32) -> Bool {
    var buf = [UInt8](repeating: 0, count: 4096) // PROC_PIDPATHINFO_MAXSIZE
    let n = proc_pidpath(pid, &buf, UInt32(buf.count))
    return n > 0 && String(decoding: buf.prefix(Int(n)), as: UTF8.self).hasPrefix("/Applications/kitty.app/")
}
