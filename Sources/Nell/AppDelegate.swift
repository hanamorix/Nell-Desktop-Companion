import AppKit
import NellCore
import ServiceManagement
import SwiftUI

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    /// `--showcase [scene]`: a sandboxed second Nell. Its support dir is a fresh temp dir, and it starts no hook
    /// socket, kitty or claude, registers no hotkey or login item, and never shows the folder picker.
    private let showcase = Showcase.requested(CommandLine.arguments)
    private lazy var paths: Paths = showcase == nil ? .standard()
        : Paths(support: FileManager.default.temporaryDirectory.appending(path: "nell-showcase-\(ProcessInfo.processInfo.processIdentifier)"))
    private var model: NellModel!
    private var kitty: KittyController!
    private var server: HookServer?
    private var panel: OverlayPanel!
    private var controller: PanelController!
    private var timer: Timer?
    private var pause = PauseState()
    private var runner: ShowcaseRunner?
    /// Only the instance holding the socket's lock owns state.json: a second Nell refused at start must not write back
    /// the stale copy it loaded over the live one's. The showcase owns its sandbox.
    private var ownsState = false

    func applicationDidFinishLaunching(_ note: Notification) {
        try? FileManager.default.createDirectory(at: paths.support, withIntermediateDirectories: true)
        guard let (sheet, image) = loadSprites() else { return fail("Nell's sprites are missing from the app bundle.") }
        EventLog.start(paths.support.appending(path: "nell.log"))
        EventLog.write("start")
        let registry = ApprovalRegistry()
        kitty = KittyController(paths: paths) // never started in the showcase: with no socket, every kitty call is a no-op
        model = NellModel(kitty: kitty, registry: registry, paths: paths, state: SavedState.load(paths.stateFile),
                          sprite: SpriteDriver(sheet: sheet, image: image))

        let model = self.model!
        kitty.theme = model.theme // before ensureRunning installs kitty.conf
        if showcase == nil {
            let server = HookServer(socketPath: paths.nellSocket.path, registry: registry,
                onEvent: { m, e, id in
                    EventLog.write("\(m.rawValue) \(e.name) \(e.toolName ?? "")\(id.map { " req=" + $0.prefix(8) } ?? "")")
                    DispatchQueue.main.async { MainActor.assumeIsolated { model.handle(m, e, requestId: id) } } },
                onRequestSettled: { m, id, a in
                    EventLog.write("\(m.rawValue) settled req=\(id.prefix(8)) \(a)")
                    DispatchQueue.main.async { MainActor.assumeIsolated { model.requestSettled(m, id, a) } } },
                onStatus: { r in DispatchQueue.main.async { MainActor.assumeIsolated { model.usageUpdated(r) } } })
            do { try server.start() } catch { return fail("Nell couldn't open her socket: \(error)") }
            self.server = server
        }
        ownsState = true

        Fonts.register()
        if showcase == nil {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            // a slow or hung shell falls back to the usual places, never stalls the launch
            let lookup = runTool(claudeLookup(shell: kitty.shell, home: home), environment: kitty.baseEnvironment(), timeout: 10)
            if lookup.status != 0 { EventLog.write("claude lookup in \(kitty.shell) ended with \(lookup.status)") }
            guard let claude = locateClaude(shellOutput: String(decoding: lookup.out, as: UTF8.self), home: home) else { return claudeMissing() }
            guard let app = locateKitty(home: home) ?? offerKittyInstall(home: home) else { return } // its alerts quit
            try? FileManager.default.removeItem(at: kittyStaging(in: URL(fileURLWithPath: home).appending(path: "Applications"))) // an install cut short
            kitty.claude = claude; kitty.commands = KittyCommands(app: app)
            EventLog.write("claude \(claude), kitty \(app)")
            Fonts.installForKitty() // approved by the user: kitty only loads installed fonts
            // a moved or deleted folder asks again; Cancel leaves none, and Code works in the chat folder until one is picked
            if model.state.usableProjectDir == nil { model.state.projectDir = pickFolder() }
            do {
                let reused = try kitty.ensureRunning(projectDir: model.cwd(.code), state: &model.state)
                if !reused { model.markLaunched(Mode.allCases) }
            } catch { return fail("Nell couldn't start kitty: \(error)") }
        } else {
            model.state.projectDir = paths.support.path
        }
        save()

        panel = OverlayPanel(size: NSSize(width: 320, height: 520))
        controller = PanelController(panel: panel)
        panel.contentView = NSHostingView(rootView: CompanionView(model: model, controller: controller))
        controller.restore(positions: model.state.positions)
        controller.onPositionSaved = { [weak self] key, p in self?.model.state.positions[key] = p; self?.save() }
        controller.onHover = { [weak self] id in self?.model.hovered = id }
        controller.spriteOpaque = { [weak model] p in model?.sprite.mask?.opaque(at: p, scale: 2) ?? false }
        let cell = consoleCell()
        model.relayout = { [weak self] phase in self?.controller.relayout(phase, cell: cell) }
        model.displayFrame = { NSScreen.screens.first?.frame ?? .zero } // the same display the layout uses
        model.relayoutNow()
        controller.startClickThrough()
        panel.orderFrontRegardless()

        let chime = showcase == nil // a looping showcase would chime every few seconds
        model.onNeedsYou = { [weak self] in
            self?.show() // comes back from "Hide Nell"
            if chime, NSWorkspace.shared.frontmostApplication?.bundleIdentifier != "net.kovidgoyal.kitty" { NSSound(named: "Tink")?.play() }
        }
        if showcase == nil { model.onOpenProject = { [weak self] in self?.openProject() } }
        model.onStateChanged = { [weak self] in self?.save() }
        model.onHide = { [weak self] in // the console goes with her; it comes back minimised
            if self?.model.console.phase == .open { self?.model.minimiseConsole() }
            self?.panel.orderOut(nil)
            self?.setPause { $0.hidden = true }
        }
        model.onQuit = { NSApp.terminate(nil) }
        if showcase == nil {
            Hotkey.register { [weak self] in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.show()
                    self.panel.ignoresMouseEvents = false
                    self.panel.makeKey()
                    NotificationCenter.default.post(name: .nellFocusBar, object: nil)
                }
            }
        }

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
                self?.model.tick(userIdle: idle, onScreen: (self?.controller.hoverRects.keys).map(Set.init))
            }
        }
        observePauses()
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.model.refreshPlacement() }
        }
        if let name = showcase {
            let scenes = name.map { Showcase.scene(named: $0).map { [$0] } ?? [] } ?? Showcase.scenes
            guard !scenes.isEmpty else { return fail("No showcase scene named \(name ?? ""). Try --showcase list.") }
            runner = ShowcaseRunner(model: model, controller: controller, scenes: scenes, sandbox: paths.support)
            runner?.start()
            if CommandLine.arguments.contains("--probe") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in self?.runner?.probe() }
            }
        } else if Bundle.main.bundleURL.pathExtension == "app" {
            try? SMAppService.mainApp.register()
        }
    }

    func applicationWillTerminate(_ note: Notification) {
        kitty?.quit()
        server?.stop()
        save()
    }

    /// One Departure Mono cell at kitty's 16.5 pt, used to size the console for ~100×30 cells.
    private func consoleCell() -> CGSize {
        guard let f = NSFont(name: Fonts.family, size: 16.5) else { return CGSize(width: 10, height: 21) }
        let w = ("M" as NSString).size(withAttributes: [.font: f]).width
        return CGSize(width: ceil(w), height: ceil(f.ascender - f.descender + f.leading))
    }

    private func save() { if ownsState { try? model?.state.save(paths.stateFile) } }

    private func show() {
        panel.orderFrontRegardless()
        setPause { $0.hidden = false }
    }

    /// Stops the sprite and the 10 Hz mouse poll (the 1 Hz model clock keeps running: its watchdogs hand held text back).
    private func setPause(_ change: (inout PauseState) -> Void) {
        change(&pause)
        model.paused = pause.paused; controller.paused = pause.paused; model.hidden = pause.hidden
    }

    /// Pause while the screen is locked or asleep. Locked and asleep are tracked apart: the display can wake on the lock screen.
    private func observePauses() {
        let set: @Sendable (_ lock: Bool, _ on: Bool) -> Void = { [weak self] lock, on in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self?.setPause { if lock { $0.locked = on } else { $0.asleep = on } }
                }
            }
        }
        let dnc = DistributedNotificationCenter.default()
        dnc.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { _ in set(true, true) }
        dnc.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { _ in set(true, false) }
        let wnc = NSWorkspace.shared.notificationCenter
        wnc.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { _ in set(false, true) }
        wnc.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { _ in set(false, false) }
    }

    private func pickFolder() -> String? {
        NSApp.activate()
        let p = NSOpenPanel()
        p.canChooseDirectories = true; p.canChooseFiles = false; p.allowsMultipleSelection = false
        p.message = "Which project should Nell's Claude Code work in?"
        return p.runModal() == .OK ? p.url?.path : nil
    }

    private func openProject() {
        guard let dir = pickFolder() else { return }
        kitty.restartCode(in: dir, state: &model.state)
        model.markLaunched([.code])
        save()
    }

    /// Never runs the installer itself: it's a remote script, so the user runs it in their own terminal.
    private func claudeMissing() {
        NSApp.activate()
        let a = NSAlert()
        a.messageText = "Nell needs Claude Code"
        a.informativeText = "Claude Code isn't installed (Nell looked in your login shell's PATH and the usual places). "
            + "Install it by running this in Terminal, then open Nell again:"
        let command = NSTextField(string: "curl -fsSL https://claude.ai/install.sh | bash")
        command.isEditable = false; command.isSelectable = true
        command.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        command.frame = NSRect(x: 0, y: 0, width: 340, height: 22)
        a.accessoryView = command
        a.addButton(withTitle: "Quit"); a.addButton(withTitle: "Open Setup Guide")
        if a.runModal() == .alertSecondButtonReturn { NSWorkspace.shared.open(URL(string: "https://docs.claude.com/en/docs/claude-code/setup")!) }
        NSApp.terminate(nil)
    }

    private var kittyInstall: Result<URL, any Error>?
    private let kittyCancel = Cancellation()

    /// kitty is missing: offers the official signed one, installed into ~/Applications off the main thread while a
    /// progress window shows (its Cancel ends the running step and cleans up). Returns its kitty.app, or nil once Nell is quitting.
    private func offerKittyInstall(home: String) -> String? {
        NSApp.activate()
        let ask = NSAlert()
        ask.messageText = "Nell needs kitty"
        ask.informativeText = "Nell needs kitty (a free terminal) to run Claude. Install it now? "
            + "(downloads the official signed kitty from github.com/kovidgoyal/kitty)"
        ask.addButton(withTitle: "Install"); ask.addButton(withTitle: "Quit")
        guard ask.runModal() == .alertFirstButtonReturn else { NSApp.terminate(nil); return nil }

        let window = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 380, height: 70), styleMask: [.titled], backing: .buffered, defer: false)
        window.title = "Nell"
        let spinner = NSProgressIndicator(); spinner.style = .spinning; spinner.controlSize = .small; spinner.startAnimation(nil)
        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancelKittyInstall(_:)))
        cancel.keyEquivalent = "\u{1b}"
        let row = NSStackView(views: [spinner, NSTextField(labelWithString: "Installing kitty… (about 80 MB)"), cancel])
        row.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        window.contentView = row; window.center()
        let folder = URL(fileURLWithPath: home).appending(path: "Applications"), token = kittyCancel
        DispatchQueue.global().async {
            let r = Result { try installKitty(into: folder, cancel: token) }
            // abortModal, not stopModal: this isn't an event of the modal window, so stopModal would wait for one
            DispatchQueue.main.async { MainActor.assumeIsolated { self.kittyInstall = r; NSApp.abortModal() } }
        }
        NSApp.runModal(for: window)
        window.orderOut(nil)
        switch kittyInstall {
        case .success(let app)?:
            EventLog.write("installed kitty at \(app.path)")
            return app.path
        case .failure where kittyCancel.isCancelled:
            EventLog.write("kitty install cancelled")
        case .failure(let e)?:
            EventLog.write("kitty install failed: \(e)")
            let a = NSAlert()
            a.messageText = "Nell couldn't install kitty"
            a.informativeText = "\((e as? InstallFailed)?.description ?? e.localizedDescription)\n\nNothing was installed. "
                + "You can install kitty yourself from its site, then open Nell again."
            a.addButton(withTitle: "Quit"); a.addButton(withTitle: "Open kitty's Site")
            if a.runModal() == .alertSecondButtonReturn { NSWorkspace.shared.open(URL(string: "https://sw.kovidgoyal.net/kitty/")!) }
        case nil: break
        }
        NSApp.terminate(nil)
        return nil
    }

    /// The install ends itself (and its modal) once the running step is killed and cleaned up.
    @objc private func cancelKittyInstall(_ sender: NSButton) { sender.isEnabled = false; kittyCancel.cancel() }

    private func fail(_ message: String) {
        NSApp.activate()
        let a = NSAlert(); a.messageText = "Nell can't start"; a.informativeText = message; a.runModal()
        NSApp.terminate(nil)
    }
}
