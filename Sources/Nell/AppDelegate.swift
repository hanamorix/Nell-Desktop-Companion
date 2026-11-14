import AppKit
import NellCore
import ServiceManagement
import SwiftUI

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    private let paths = Paths.standard()
    private var model: NellModel!
    private var kitty: KittyController!
    private var server: HookServer?
    private var panel: OverlayPanel!
    private var controller: PanelController!
    private var timer: Timer?

    func applicationDidFinishLaunching(_ note: Notification) {
        try? FileManager.default.createDirectory(at: paths.support, withIntermediateDirectories: true)
        guard let (sheet, image) = loadSprites() else { return fail("Nell's sprites are missing from the app bundle.") }
        EventLog.start(paths.support.appending(path: "nell.log"))
        EventLog.write("start")
        let registry = ApprovalRegistry()
        kitty = KittyController(paths: paths)
        model = NellModel(kitty: kitty, registry: registry, paths: paths, state: SavedState.load(paths.stateFile))

        let model = self.model!
        let server = HookServer(socketPath: paths.nellSocket.path, registry: registry,
            onEvent: { m, e, id in
                EventLog.write("\(m.rawValue) \(e.name) \(e.toolName ?? "")\(id.map { " req=" + $0.prefix(8) } ?? "")")
                DispatchQueue.main.async { MainActor.assumeIsolated { model.handle(m, e, requestId: id) } } },
            onRequestSettled: { m, id, a in
                EventLog.write("\(m.rawValue) settled req=\(id.prefix(8)) \(a)")
                DispatchQueue.main.async { MainActor.assumeIsolated { model.requestSettled(m, id, a) } } })
        do { try server.start() } catch { return fail("Nell couldn't open her socket: \(error)") }
        self.server = server

        if model.state.projectDir == nil { model.state.projectDir = pickFolder() ?? FileManager.default.homeDirectoryForCurrentUser.path }
        do {
            let reused = try kitty.ensureRunning(projectDir: model.state.projectDir!, state: &model.state)
            if !reused { model.markLaunched(Mode.allCases) }
        } catch { return fail("Nell couldn't start kitty: \(error)") }
        save()

        panel = OverlayPanel(size: NSSize(width: 320, height: 520))
        controller = PanelController(panel: panel)
        panel.contentView = NSHostingView(rootView: CompanionView(model: model, sheet: sheet, image: image, controller: controller))
        controller.restore(positions: model.state.positions)
        controller.onPositionSaved = { [weak self] key, p in self?.model.state.positions[key] = p; self?.save() }
        controller.startClickThrough()
        panel.orderFrontRegardless()

        model.onNeedsYou = { [weak self] in
            self?.panel.orderFrontRegardless() // comes back from "Hide Nell"
            if NSWorkspace.shared.frontmostApplication?.bundleIdentifier != "net.kovidgoyal.kitty" { NSSound(named: "Tink")?.play() }
        }
        model.onOpenProject = { [weak self] in self?.openProject() }
        model.onHide = { [weak self] in self?.panel.orderOut(nil) }
        model.onQuit = { NSApp.terminate(nil) }
        Hotkey.register { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.panel.orderFrontRegardless()
                self.panel.ignoresMouseEvents = false
                self.panel.makeKey()
                NotificationCenter.default.post(name: .nellFocusBar, object: nil)
            }
        }

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
                self?.model.tick(userIdle: idle)
            }
        }
        observePauses()
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.controller.clampToScreen() }
        }
        if Bundle.main.bundleURL.pathExtension == "app" { try? SMAppService.mainApp.register() }
    }

    func applicationWillTerminate(_ note: Notification) {
        kitty?.quit()
        server?.stop()
        save()
    }

    private func save() { try? model?.state.save(paths.stateFile) }

    /// Stop animating and polling the mouse while the screen is locked or asleep.
    private func observePauses() {
        let set: @Sendable (Bool) -> Void = { [weak self] p in
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.model.paused = p; self?.controller.paused = p } }
        }
        let dnc = DistributedNotificationCenter.default()
        dnc.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { _ in set(true) }
        dnc.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { _ in set(false) }
        let wnc = NSWorkspace.shared.notificationCenter
        wnc.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { _ in set(true) }
        wnc.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { _ in set(false) }
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
