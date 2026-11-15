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

    init(model: NellModel, controller: PanelController, scenes: [Showcase.Scene], sandbox: URL) {
        self.model = model; self.controller = controller; self.scenes = scenes; self.sandbox = sandbox
        home = controller.nellOrigin
    }

    func start() {
        log("sandbox \(sandbox.path)")
        next()
        timer = Timer.scheduledTimer(withTimeInterval: Showcase.stepDuration, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.next() }
        }
    }

    private func next() {
        step += 1
        if step >= scenes[scene].steps.count { step = 0; scene = (scene + 1) % scenes.count }
        let sc = scenes[scene], st = sc.steps[step]
        if step == 0 {
            controller.nellOrigin = home
            model.resetForShowcase()
            previousBody = model.pose.body
        }
        log("\(sc.name) / \(st.name)")
        for a in st.actions { run(a) }
        check(st)
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
        case .place(let x, let y):
            guard let v = controller.screen?.visibleFrame else { return }
            let s = PanelController.nellSize
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
            }
            if !ok { log("MISMATCH \(v): body \(p.body) face \(p.face) emoji \(p.emoji.map(\.rawValue) ?? "none") stacks \(p.stacks)") }
        }
    }

    private func log(_ line: String) {
        EventLog.write("showcase " + line)
        FileHandle.standardError.write(Data("showcase \(line)\n".utf8))
    }
}
