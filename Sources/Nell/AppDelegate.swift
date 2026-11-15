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
            Fonts.installForKitty() // approved by the user: kitty only loads installed fonts
            guard FileManager.default.isExecutableFile(atPath: kitty.claude) else {
                return fail("Claude Code isn't installed at \(kitty.claude), where Nell runs it from.")
            }
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

    private func fail(_ message: String) {
        NSApp.activate()
        let a = NSAlert(); a.messageText = "Nell can't start"; a.informativeText = message; a.runModal()
        NSApp.terminate(nil)
    }
}
