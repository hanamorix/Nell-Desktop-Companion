import AppKit
import NellCore
import SwiftUI

/// Nell's window, laid out by `Layout`: her block, the bubble column, and (when open) the console frame around kitty.
/// Shapes are functional placeholders; the design round replaces them.
struct CompanionView: View {
    @ObservedObject var model: NellModel
    let sheet: SpriteSheet
    let image: CGImage
    let controller: PanelController
    @FocusState private var barFocused: Bool

    var body: some View {
        if let l = model.layout {
            ZStack(alignment: .topLeading) {
                Color.clear
                column(l).place(local(l.columnFrame, in: l))
                if let c = l.consoleFrame {
                    ConsoleFrame(project: projectName, toward: l.side, minimise: model.minimiseConsole).place(local(c, in: l))
                }
                if let m = l.minimisedFrame {
                    MinimisedConsole(status: model.codeStatus, toward: l.side, open: { model.openConsole(tab: .code) })
                        .interactive().place(local(m, in: l))
                }
                nell(l).place(local(l.nellFrame, in: l))
            }
            .frame(width: l.panelFrame.width, height: l.panelFrame.height)
            .font(Fonts.ui())
            .onPreferenceChange(InteractiveRectsKey.self) { r in MainActor.assumeIsolated { controller.rects = r } }
            .onPreferenceChange(GrabRectsKey.self) { r in MainActor.assumeIsolated { controller.grabRects = r } }
            .onPreferenceChange(HoverRectsKey.self) { r in MainActor.assumeIsolated { controller.hoverRects = r } }
            .onReceive(NotificationCenter.default.publisher(for: .nellFocusBar)) { _ in barFocused = true }
        }
    }

    private var projectName: String { ((model.state.projectDir ?? "") as NSString).lastPathComponent }

    /// Screen rect (y up) → this window's local rect (y down).
    private func local(_ r: CGRect, in l: NellCore.Layout) -> CGRect {
        CGRect(x: r.minX - l.panelFrame.minX, y: l.panelFrame.maxY - r.maxY, width: r.width, height: r.height)
    }

    private func column(_ l: NellCore.Layout) -> some View {
        VStack(alignment: l.side == .left ? .trailing : .leading, spacing: 8) {
            if l.columnUp { Spacer(minLength: 0) }
            ForEach(model.shown) { s in BubbleView(model: model, bubble: s.bubble, tailRight: l.side == .left).opacity(s.opacity) }
            if !l.columnUp { Spacer(minLength: 0) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: l.side == .left ? .trailing : .leading)
        .clipped()
    }

    private func nell(_ l: NellCore.Layout) -> some View {
        VStack(spacing: 6) {
            SpriteView(state: model.body, sheet: sheet, image: image, paused: model.paused, width: 150)
                .scaleEffect(x: l.faceRight ? -1 : 1, y: 1)
                .grabbable()
                .gesture(DragGesture(minimumDistance: 2)
                    .onChanged { _ in if controller.dragChanged() { model.dragBegan() } }
                    .onEnded { _ in controller.dragEnded(); model.dragEnded() })
                .contextMenu {
                    Button("Open project…") { model.onOpenProject?() }
                    Button("Hide Nell") { model.onHide?() }
                    Divider()
                    Button("Quit Nell") { model.onQuit?() }
                }
            HStack(spacing: 4) {
                Chip(label: "💬", help: "Chat", on: model.selected == .chat) { model.chatChip() }
                Chip(label: "⌘", help: "Claude Code console", on: model.selected == .code) { model.codeChip() }
                TextField(model.barHeld ? "Waiting — answer in the console" : model.selected == .chat ? "Message Nell…" : "Ask Claude Code…",
                          text: $model.draft, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black, lineWidth: 2))
                    .foregroundStyle(.black)
                    .focused($barFocused)
                    .onSubmit { model.submit() }
                    .onChange(of: model.draft) { model.refresh() }
            }
            .interactive()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }
}

extension View {
    func place(_ r: CGRect) -> some View { frame(width: r.width, height: r.height).position(x: r.midX, y: r.midY) }
}

extension Notification.Name { static let nellFocusBar = Notification.Name("nellFocusBar") }

struct Chip: View {
    let label: String; let help: String; let on: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label).frame(width: 28, height: 26)
                .background(on ? Color(red: 0.95, green: 0.8, blue: 0.38) : Color.white, in: RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black, lineWidth: 2))
                .foregroundStyle(.black)
        }
        .buttonStyle(.plain).help(help).accessibilityLabel(help)
    }
}

/// Placeholder speech bubble: a bordered box with a small tail pointing at Nell.
struct SpeechBubble<Content: View>: View {
    let fill: Color; let tailRight: Bool
    @ViewBuilder let content: Content
    var body: some View {
        content
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(fill, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 2))
            .overlay(alignment: tailRight ? .bottomTrailing : .bottomLeading) {
                Tail().fill(fill).overlay(Tail().stroke(Color.black, lineWidth: 2))
                    .frame(width: 10, height: 8).scaleEffect(x: tailRight ? 1 : -1).offset(x: tailRight ? -14 : 14, y: 7)
            }
            .padding(.bottom, 6)
    }
}

struct Tail: Shape {
    func path(in r: CGRect) -> Path {
        Path { p in p.move(to: CGPoint(x: r.minX, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.maxY)); p.addLine(to: CGPoint(x: r.maxX, y: r.minY)) }
    }
}

struct BubbleView: View {
    @ObservedObject var model: NellModel
    let bubble: Bubble
    let tailRight: Bool

    var body: some View {
        SpeechBubble(fill: fill, tailRight: tailRight) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 4) {
                    if bubble.mode != model.selected { Text(bubble.mode == .chat ? "💬" : "⌘") }
                    if bubble.kind == .reply, bubble.mode == .chat {
                        ScrollView { Text(bubble.text).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }.frame(maxHeight: 180)
                    } else {
                        Text(bubble.text).lineLimit(bubble.kind == .reply ? 5 : 3)
                    }
                }
                if case .approval(let id) = bubble.kind, !bubble.settled {
                    HStack(spacing: 6) {
                        action("Allow", .systemGreen) { model.answer(id, .allow) }
                        action("Deny", .systemRed) { model.answer(id, .deny) }
                        action("Open terminal", .darkGray) { model.openTerminal(bubble.mode, requestId: id) }
                    }
                }
                if bubble.kind == .question, !bubble.settled {
                    action("Answer in terminal", .systemBlue) { model.openTerminal(bubble.mode, requestId: nil) }
                }
                if bubble.kind == .consoleNeeded, !bubble.settled {
                    action("Open console", .systemBlue) { model.openConsole(tab: bubble.mode) }
                }
            }
            .foregroundStyle(.black)
        }
        .frame(maxWidth: 260, alignment: tailRight ? .trailing : .leading)
        .modifier(BubbleHit(id: bubble.id, hasButtons: hasButtons))
    }

    private var hasButtons: Bool {
        guard !bubble.settled else { return bubble.kind == .reply && bubble.mode == .chat }
        if case .approval = bubble.kind { return true }
        return bubble.kind == .question || bubble.kind == .consoleNeeded || (bubble.kind == .reply && bubble.mode == .chat)
    }
    private var fill: Color {
        switch bubble.kind {
        case .user: Color(white: 0.88)
        case .error: Color(red: 1, green: 0.85, blue: 0.85)
        case .approval, .question, .consoleNeeded: Color(red: 1, green: 0.95, blue: 0.77)
        default: Color.white
        }
    }
    private func action(_ title: String, _ color: NSColor, _ run: @escaping () -> Void) -> some View {
        Button(action: run) {
            Text(title).foregroundStyle(.white).padding(.horizontal, 8).padding(.vertical, 3)
                .background(Color(nsColor: color), in: RoundedRectangle(cornerRadius: 3))
        }.buttonStyle(.plain)
    }
}

/// Bubbles with buttons (or a scrollable reply) take clicks; plain ones pass clicks through but still report hover.
struct BubbleHit: ViewModifier {
    let id: UUID; let hasButtons: Bool
    func body(content: Content) -> some View {
        let tracked = content.background(GeometryReader { g in Color.clear.preference(key: HoverRectsKey.self, value: [id: g.frame(in: .global)]) })
        if hasButtons { tracked.interactive() } else { tracked }
    }
}

/// The frame Nell draws around the kitty panel: a border, a title strip with minimise, and a tail toward her.
struct ConsoleFrame: View {
    let project: String; let toward: Side; let minimise: () -> Void
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("⌘ Claude Code · \(project)").lineLimit(1)
                Spacer()
                Button(action: minimise) { Text("_ minimise").padding(.horizontal, 6) }.buttonStyle(.plain)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .frame(height: ConsoleChrome.title)
            .background(Color(red: 0.23, green: 0.21, blue: 0.31))
            .interactive()
            Color.clear // kitty sits here, above or below this window; this area never takes clicks
        }
        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.black, lineWidth: ConsoleChrome.border))
        .overlay(alignment: toward == .left ? .bottomTrailing : .bottomLeading) {
            Tail().fill(Color.black).frame(width: 10, height: 10)
                .scaleEffect(x: toward == .left ? -1 : 1).offset(x: toward == .left ? 9 : -9, y: -14)
        }
    }
}

struct MinimisedConsole: View {
    let status: String?; let toward: Side; let open: () -> Void
    var body: some View {
        Button(action: open) {
            HStack {
                Text("⌘ " + (status ?? "Claude Code is idle")).lineLimit(1)
                Spacer()
                Text("open").opacity(0.75)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 0.11, green: 0.105, blue: 0.15), in: RoundedRectangle(cornerRadius: 3))
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.black, lineWidth: 3))
        }
        .buttonStyle(.plain)
    }
}
