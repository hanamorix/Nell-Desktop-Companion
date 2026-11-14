import AppKit
import NellCore
import SwiftUI

/// Layout A: bubbles rise from Nell's head and fade; chips + message bar under her desk.
struct CompanionView: View {
    @ObservedObject var model: NellModel
    let sheet: SpriteSheet
    let image: CGImage
    let controller: PanelController
    @FocusState private var barFocused: Bool

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Spacer(minLength: 0)
            ForEach(model.shown) { s in BubbleView(model: model, bubble: s.bubble).opacity(s.opacity) }
            if model.body == .disconnected {
                BubbleShape(text: "Can't hear Claude — check the terminal", fill: Color(nsColor: .systemOrange), ink: .black).interactive()
            }
            SpriteView(state: model.body, sheet: sheet, image: image, paused: model.paused, width: 150)
                .interactive()
                .gesture(DragGesture(minimumDistance: 2).onChanged { _ in controller.dragChanged() }.onEnded { _ in controller.dragEnded() })
                .contextMenu {
                    Button("Open project…") { model.onOpenProject?() }
                    Button("Hide Nell") { model.onHide?() }
                    Divider()
                    Button("Quit Nell") { model.onQuit?() }
                }
            HStack(spacing: 4) {
                Chip(label: "💬", help: "Chat", on: model.selected == .chat) { model.chip(.chat) }
                Chip(label: "⌘", help: "Code", on: model.selected == .code) { model.chip(.code) }
                TextField(model.barHeld ? "Waiting — answer in the terminal first" : model.selected == .chat ? "Message Nell…" : "Ask Claude Code…", text: $model.draft, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color(nsColor: .textBackgroundColor).opacity(0.95), in: RoundedRectangle(cornerRadius: 14))
                    .focused($barFocused)
                    .onSubmit { model.submit() }
                    .onChange(of: model.draft) { model.refresh() }
            }
            .interactive()
        }
        .padding(8)
        .frame(width: 320, height: 520)
        .onPreferenceChange(InteractiveRectsKey.self) { r in MainActor.assumeIsolated { controller.rects = r } }
        .onReceive(NotificationCenter.default.publisher(for: .nellFocusBar)) { _ in barFocused = true }
    }
}

extension Notification.Name { static let nellFocusBar = Notification.Name("nellFocusBar") }

struct Chip: View {
    let label: String; let help: String; let on: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label).font(.system(size: 13)).frame(width: 28, height: 26)
                .background(on ? Color.white : Color.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 9))
                .foregroundStyle(on ? Color.black : Color.white)
        }
        .buttonStyle(.plain).help(help).accessibilityLabel(help)
    }
}

struct BubbleShape: View {
    let text: String; let fill: Color; let ink: Color
    var body: some View {
        Text(text)
            .font(.system(size: 12.5)).foregroundStyle(ink)
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(fill, in: RoundedRectangle(cornerRadius: 14))
            .frame(maxWidth: 260, alignment: .trailing)
            .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
    }
}

struct BubbleView: View {
    @ObservedObject var model: NellModel
    let bubble: Bubble

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 4) {
                if bubble.mode != model.selected { Text(bubble.mode == .chat ? "💬" : "⌘").font(.system(size: 11)) }
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
                    action("Open terminal", .systemGray) { model.openTerminal(bubble.mode, requestId: id) }
                }
            }
            if bubble.kind == .question, !bubble.settled {
                action("Answer in terminal", .systemBlue) { model.openTerminal(bubble.mode, requestId: nil) }
            }
        }
        .font(.system(size: 12.5))
        .foregroundStyle(isUser ? Color.white : Color.black)
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(fill, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
        .frame(maxWidth: 260, alignment: isUser ? .trailing : .leading)
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
        .interactive()
        .onHover { model.hovered = $0 ? bubble.id : nil }
    }

    private var isUser: Bool { bubble.kind == .user }
    private var fill: Color {
        switch bubble.kind {
        case .user: Color(nsColor: .systemBlue)
        case .error: Color(red: 1, green: 0.85, blue: 0.85)
        case .approval, .question: Color(red: 1, green: 0.97, blue: 0.85)
        default: Color.white
        }
    }
    private func action(_ title: String, _ color: NSColor, _ run: @escaping () -> Void) -> some View {
        Button(action: run) {
            Text(title).font(.system(size: 11.5, weight: .semibold)).foregroundStyle(.white)
                .padding(.horizontal, 9).padding(.vertical, 4)
                .background(Color(nsColor: color), in: Capsule())
        }.buttonStyle(.plain)
    }
}
