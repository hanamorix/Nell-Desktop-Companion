import AppKit
import NellCore

/// Plays `Showcase` scenes through the same entry points real events use, one step every few seconds, forever.
/// After each step it checks what the step says it shows and logs any MISMATCH.
@MainActor final class ShowcaseRunner {
    private let model: NellModel
    private let controller: PanelController
    private let scenes: [Showcase.Scene]
    private let sandbox: URL
    private let home: CGPoint
    private var scene = 0, step = -1
    private var previousBody = Body.idle
    private var timer: Timer?
    private var due: Date?

    init(model: NellModel, controller: PanelController, scenes: [Showcase.Scene], sandbox: URL) {
        self.model = model; self.controller = controller; self.scenes = scenes; self.sandbox = sandbox
        home = controller.nellOrigin
        controller.onHitChange = { [weak self] takes in self?.log(takes ? "pointer: takes clicks" : "pointer: clicks pass through") }
    }

    func start() {
        log("sandbox \(sandbox.path)")
        next()
    }

    private func next() {
        // stress check: a main-thread timer firing more than 1 s late is a UI stall
        let now = Date()
        if let due = due, now.timeIntervalSince(due) > 1 { log(String(format: "STALL %.2f s late", now.timeIntervalSince(due))) }
        step += 1
        if step >= scenes[scene].steps.count { step = 0; scene = (scene + 1) % scenes.count }
        let sc = scenes[scene], st = sc.steps[step]
        due = now + sc.stepDuration
        timer = Timer.scheduledTimer(withTimeInterval: sc.stepDuration, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.next() }
        }
        if step == 0 {
            controller.nellOrigin = home
            model.resetForShowcase()
            previousBody = model.pose.body
        }
        if sc.stepDuration >= 1 || step % 20 == 0 { log("\(sc.name) / \(st.name)") } // a burst logs once a second
        for a in st.actions { run(a) }
        check(st)
        if sc.stepDuration >= 1 { DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.checkColumn() } } // rects settle after layout
        previousBody = model.pose.body
    }

    private func run(_ a: Showcase.Action) {
        switch a {
        case .hook(let m, let fields, let requestId):
            do { model.handle(m, try HookEvent.decode(JSONEncoder().encode(fields)), requestId: requestId) } // the server's decoder
            catch { log("MISMATCH hook didn't decode: \(error)") }
        case .stopWithContext(let tokens):
            // The real Stop path reads context from transcript_path, so write a one-line transcript into the sandbox.
            let url = sandbox.appending(path: "transcript.jsonl")
            let line = #"{"type":"assistant","message":{"usage":{"input_tokens":\#(tokens),"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}"#
            try? Data((line + "\n").utf8).write(to: url)
            run(.hook(.code, ["hook_event_name": .string("Stop"), "session_id": .string("showcase"), "transcript_path": .string(url.path)]))
        case .settle(let m, let id, let answer): model.requestSettled(m, id, answer)
        case .say(let text): model.draft = text; model.submit()
        case .chatChip: model.chatChip()
        case .codeChip: model.codeChip()
        case .openConsole: model.openConsole()
        case .minimiseConsole: model.minimiseConsole()
        case .usage(let s, let w, let resetsIn):
            let at = Date().addingTimeInterval(resetsIn)
            model.usageUpdated(UsageReading(session: s.map { UsageWindow(used: $0, resetsAt: at) }, weekly: w.map { UsageWindow(used: $0, resetsAt: at) }))
        case .theme(let n): model.setTheme(n)
        case .place(let x, let y):
            guard let v = controller.screen?.visibleFrame else { return }
            let s = NellBlock.size
            controller.nellOrigin = CGPoint(x: (v.minX + x * (v.width - s.width)).rounded(), y: (v.minY + y * (v.height - s.height)).rounded())
            model.relayoutNow()
        }
    }

    private func check(_ st: Showcase.Step) {
        let p = model.pose
        for v in st.shows {
            let ok: Bool
            switch v {
            case .face(let f): ok = p.face == f
            case .emoji(let e): ok = p.emoji == e
            case .body(let b): ok = p.body == b
            case .between(let pair): ok = "\(previousBody.rawValue)-\(p.body.rawValue)" == pair
            case .paper(let n): ok = p.stacks == n
            case .bubble(let k): ok = model.shown.contains { $0.bubble.kind.name == k }
            case .badge: ok = model.shown.contains { $0.bubble.mode != model.selected }
            case .console(let phase): ok = model.console.phase == phase
            case .placement: ok = model.layout != nil
            case .theme(let n): ok = model.theme.id == n && PN.theme.id == n
            case .gauge(let k, let l): ok = (k == .weekly ? model.weeklyGauge : model.sessionGauge).level == l
            }
            if !ok { log("MISMATCH \(v): body \(p.body) face \(p.face) emoji \(p.emoji.map(\.rawValue) ?? "none") stacks \(p.stacks)") }
        }
    }

    /// Bubbles that don't fit are off screen and report nothing; nothing just outside the column takes clicks (D3).
    private func checkColumn() {
        guard let l = model.layout else { return }
        let col = CGRect(x: l.columnFrame.minX - l.panelFrame.minX, y: l.panelFrame.maxY - l.columnFrame.maxY,
                         width: l.columnFrame.width, height: l.columnFrame.height) // window points, y down
        let outside = controller.hoverRects.values.filter { !col.insetBy(dx: -0.5, dy: -0.5).contains($0) }
        if !outside.isEmpty { log("MISMATCH bubble rects outside the column: \(outside)") }
        let beyond = CGPoint(x: col.midX, y: l.columnUp ? col.minY - 3 : col.maxY + 3) // the column's far edge, inside the panel
        if controller.takesClick(at: beyond) { log("MISMATCH a click beyond the column at \(beyond) is taken") }
        log("column: \(controller.hoverRects.count) of \(model.shown.count) bubbles on screen, pinned \(model.shown.filter(\.bubble.pinned).count)")
    }

    /// `--probe`: checks the right-click hit area in-process (posting real mouse events needs Accessibility access):
    /// a point on her head and one in a transparent gap of the sprite box; left clicks on her, the Chat chip and the bar
    /// (only the bar may take the keyboard); then a right-click on her head that opens the menu, closed 3 s later with Escape.
    func probe() {
        guard let box = controller.grabRects.first, let face = model.sprite.sheet.slice("face", frame: 0) else { return log("probe: no sprite") }
        let head = NellBlock.head(faceSlice: face, mirrored: model.layout?.faceRight ?? false)
        let body = CGPoint(x: box.minX + head.x - NellBlock.spriteX(mirrored: model.layout?.faceRight ?? false), y: box.minY + head.y)
        let gap = CGPoint(x: box.minX + 20, y: box.minY + 80) // art (10, 40): beside her hood, above the laptop
        for (name, p) in [("head", body), ("gap", gap)] {
            log("probe \(name) \(p): \(controller.takesClick(at: p) ? "takes clicks" : "clicks pass through")")
        }
        let panel = controller.panel
        guard let content = panel.contentView else { return }
        // a left click on her must not take the keyboard; the bar's text field still must
        panel.orderOut(nil); panel.orderFrontRegardless() // start without the keyboard (launching via `open` gives it)
        log("probe: key before \(panel.isKeyWindow)")
        let headAt = NSPoint(x: body.x, y: content.bounds.height - body.y)
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            if let e = NSEvent.mouseEvent(with: type, location: headAt, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                                          windowNumber: panel.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1) {
                panel.sendEvent(e)
            }
        }
        log("probe: left click on her head -> key \(panel.isKeyWindow)")
        // a button needs no keyboard: the Chat chip fires and the panel stays non-key
        let m = model.layout?.faceRight ?? false, chat = NellBlock.chips(CGSize(width: 38, height: 30), mirrored: m).chat
        let chatAt = NSPoint(x: box.minX - NellBlock.spriteX(mirrored: m) + chat.midX, y: content.bounds.height - (box.minY + chat.midY))
        model.selected = .code
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            if let e = NSEvent.mouseEvent(with: type, location: chatAt, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                                          windowNumber: panel.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1) {
                panel.sendEvent(e)
            }
        }
        log("probe: left click on the Chat chip -> key \(panel.isKeyWindow), fired \(model.selected == .chat)")
        let bar = NellBlock.bar(mirrored: model.layout?.faceRight ?? false)
        let barAt = CGPoint(x: box.minX - NellBlock.spriteX(mirrored: model.layout?.faceRight ?? false) + bar.midX, y: box.minY + bar.midY)
        var v = content.hitTest(NSPoint(x: barAt.x, y: content.bounds.height - barAt.y)), wants = false
        while let view = v, !wants { wants = view.needsPanelToBecomeKey; v = view.superview }
        log("probe: the bar's view at \(barAt) needsPanelToBecomeKey \(wants)")
        let barWindow = NSPoint(x: barAt.x, y: content.bounds.height - barAt.y)
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            if let e = NSEvent.mouseEvent(with: type, location: barWindow, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                                          windowNumber: panel.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1) {
                panel.sendEvent(e)
            }
        }
        log("probe: left click on the bar -> key \(panel.isKeyWindow)")
        panel.orderOut(nil); panel.orderFrontRegardless() // hand the keyboard straight back
        log("probe: keyboard handed back -> key \(panel.isKeyWindow)")
        let window = panel.windowNumber
        let escape = Timer(timeInterval: 3, repeats: false) { _ in
            MainActor.assumeIsolated {
                NSApp.postEvent(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                                                 windowNumber: window, context: nil, characters: "\u{1b}",
                                                 charactersIgnoringModifiers: "\u{1b}", isARepeat: false, keyCode: 53)!, atStart: false)
            }
        }
        RunLoop.main.add(escape, forMode: .common) // fires inside the menu's tracking loop
        log("probe: right-click on her head")
        let at = NSPoint(x: body.x, y: content.bounds.height - body.y)
        for type in [NSEvent.EventType.rightMouseDown, .rightMouseUp] {
            if let e = NSEvent.mouseEvent(with: type, location: at, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                                          windowNumber: panel.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1) {
                panel.sendEvent(e)
            }
        }
        log("probe: menu closed")
    }

    private func log(_ line: String) {
        EventLog.write("showcase " + line)
        FileHandle.standardError.write(Data("showcase \(line)\n".utf8))
    }
}
