import AppKit
import NellCore
import SwiftUI

/// Nell's window, laid out by `Layout`: her block, the bubble column, and (when open) the console frame around kitty.
/// Drawn in Plum Night (`PlumNight.swift`, from `concept-nell-design-system/`).
struct CompanionView: View {
    @ObservedObject var model: NellModel
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

    /// The chip's gold dot: the other mode has a bubble showing that you aren't looking at.
    private func hasNews(_ m: Mode) -> Bool { m != model.selected && model.shown.contains { $0.bubble.mode == m && $0.bubble.kind != .user } }

    private var projectName: String { ((model.state.projectDir ?? "") as NSString).lastPathComponent }

    /// Screen rect (y up) → this window's local rect (y down).
    private func local(_ r: CGRect, in l: NellCore.Layout) -> CGRect {
        CGRect(x: r.minX - l.panelFrame.minX, y: l.panelFrame.maxY - r.maxY, width: r.width, height: r.height)
    }

    /// Her head's x in the column's own coordinates, for the bubbles' tails.
    private func headX(_ l: NellCore.Layout) -> CGFloat {
        guard let face = model.sprite.sheet.slice("face", frame: 0) else { return l.columnFrame.width / 2 }
        return NellBlock.head(faceSlice: face, mirrored: l.faceRight).x + l.nellFrame.minX - l.columnFrame.minX
    }

    private func column(_ l: NellCore.Layout) -> some View {
        let head = headX(l), width = l.columnFrame.width
        return VStack(spacing: 8) {
            if l.columnUp { Spacer(minLength: 0) }
            ForEach(model.shown) { s in // fade each bubble as one, so its drop doesn't show through the fill
                // Nell's bubbles sit over her head; your cream ones stay on the far side
                let mine = s.bubble.kind == .user
                ColumnRow(width: width, headX: head, mine: mine) {
                    BubbleView(model: model, bubble: s.bubble, layout: l, headX: head, columnWidth: width).compositingGroup().opacity(s.opacity)
                }
            }
            if !l.columnUp { Spacer(minLength: 0) }
        }
        // the newest bubble is last: when they overflow, the oldest are the ones clipped
        .frame(width: width, height: l.columnFrame.height, alignment: .bottom)
        .clipped()
    }

    /// Option A: the sprite against the laptop side, the bar spanning her desk underneath, and the chips stacked on the
    /// chair side with the Code chip on the bar row. Everything swaps sides when she's mirrored.
    private func nell(_ l: NellCore.Layout) -> some View {
        let m = l.faceRight, size = NellBlock.size, bar = NellBlock.bar(mirrored: m)
        let chips = NellBlock.chips(CGSize(width: 38, height: 30), mirrored: m) // a chip with its news dot
        return ZStack(alignment: .topLeading) {
            SpriteCompositor(driver: model.sprite) // mirrored inside when she faces right, so the emoji stays readable
                .grabbable()
                .gesture(DragGesture(minimumDistance: 2) // only with ⌥ held: PanelController ignores plain drags
                    .onChanged { _ in if controller.dragChanged() { model.dragBegan() } }
                    .onEnded { _ in if controller.dragEnded() { model.dragEnded() } })
                .contextMenu {
                    // the shortcut only brings her back, so it's named in the label rather than shown as this item's key
                    Button("Minimise (⌥⌘N to return)") { model.onHide?() }
                    Button("Choose project folder…") { model.onOpenProject?() }
                    Divider()
                    Button("Quit Nell") { model.onQuit?() }
                }
                .place(CGRect(x: NellBlock.spriteX(mirrored: m), y: 0, width: NellBlock.sprite, height: NellBlock.sprite))
            ModeChip(icon: "chat", help: "Chat", on: model.selected == .chat, news: hasNews(.chat)) { model.chatChip() }
                .interactive().place(chips.chat)
            ModeChip(icon: "code", help: "Claude Code console", on: model.selected == .code, news: hasNews(.code)) { model.codeChip() }
                .interactive().place(chips.code)
            MessageBar(model: model, focused: $barFocused, isFocused: barFocused) // grows upward over her when multi-line
                .interactive()
                .frame(width: bar.width, height: size.height, alignment: .bottom)
                .position(x: bar.midX, y: size.height / 2)
        }
        .frame(width: size.width, height: size.height)
    }
}

extension View {
    func place(_ r: CGRect) -> some View { frame(width: r.width, height: r.height).position(x: r.midX, y: r.midY) }
}

extension Notification.Name { static let nellFocusBar = Notification.Name("nellFocusBar") }

/// The one text field: a plum panel around a sunken plum-900 well. Gold QUEUED while Claude holds your input.
struct MessageBar: View {
    @ObservedObject var model: NellModel
    var focused: FocusState<Bool>.Binding
    /// Read by the parent too, so focus changes certainly redraw the ring.
    let isFocused: Bool

    var body: some View {
        HStack(spacing: 4) {
            TextField("", text: $model.draft, prompt: Text(placeholder).foregroundColor(PN.muted), axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .foregroundStyle(PN.cream)
                .tint(PN.pink400)
                .accessibilityLabel("Message")
                .focused(focused)
                .onSubmit { model.submit() }
                .onChange(of: model.draft) { model.refresh() }
                .frame(maxWidth: .infinity, alignment: .leading)
            if model.barHeld { Text("QUEUED").foregroundStyle(PN.gold).fixedSize() }
        }
        .padding(.horizontal, 6).padding(.top, 4).padding(.bottom, 2)
        .background { VStack(spacing: 0) { PN.outline.frame(height: PN.px); PN.plum900 } } // the well, with its top shadow
        // shortcut: CSS pads the bar 8/6 and the well 6/4; trimmed to keep the bar row 34 pt (nellSize)
        .padding(.horizontal, 6).padding(.top, 6).padding(.bottom, 4)
        .pixelFrame(focused: isFocused)
    }

    private var placeholder: String { model.barHeld ? "Waiting…" : model.selected == .chat ? "Message Nell…" : "Ask Claude Code…" }
}

struct BubbleView: View {
    @ObservedObject var model: NellModel
    let bubble: Bubble
    let layout: NellCore.Layout
    /// Her head's x in the column; the tail points there.
    let headX: CGFloat
    let columnWidth: CGFloat

    var body: some View {
        let s = style, tailDown = layout.columnUp, hasTail = bubble.kind != .status // status bubbles mutter: no tail
        let badged = bubble.mode != model.selected
        let drop: CGFloat = s.drop == .large ? 2 * PN.px : s.drop == .small ? PN.px : 0
        let farEdge = badged ? TailRule.room : drop // the badge sits on the edge opposite the tail
        Cap(width: 264) { // hugs its text; long text wraps at 264
            VStack(alignment: .leading, spacing: 4) {
                if let h = header {
                    HStack(spacing: 4) { Icon(name: h.icon, ink: PN.cream); Text(h.label) }.foregroundStyle(h.color)
                }
                content
                actions.padding(.top, 4)
            }
            .lineSpacing(1) // Departure Mono's 14 pt line + 1 = the 11/15 body style
            .foregroundStyle(s.ink)
            .padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 8)
            .pixelFrame(fill: s.fill, hi: s.hi, lo: s.lo, drop: s.drop)
            .overlay { GeometryReader { g in decorations(g.size, fill: s.fill, tail: hasTail, badged: badged) } }
        }
        // room for the tail (and the badge) inside the clipped column, on the edges they stick out of
        .padding(.top, tailDown ? (badged ? farEdge : 0) : (hasTail ? TailRule.room : 0))
        .padding(.bottom, tailDown ? (hasTail ? TailRule.room : drop) : farEdge)
        .modifier(BubbleHit(id: bubble.id, hasButtons: hasButtons))
    }

    /// The tail on the edge facing her, its tip as near her head as the bubble allows; the badge on the opposite edge.
    @ViewBuilder private func decorations(_ size: CGSize, fill: Color, tail: Bool, badged: Bool) -> some View {
        let x = bubbleX(width: size.width, columnWidth: columnWidth, headX: headX, mine: bubble.kind == .user)
        let a = tailAnchor(bubble: CGRect(x: x, y: 0, width: size.width, height: size.height), layout: layout, headX: headX)
        let down = a.edge == .bottom, half = TailRule.width / 2
        if tail { // the art points down-left; its top row overlaps the bubble's outline
            PixelArt.tail(fill).scaleEffect(x: a.leansLeft ? 1 : -1, y: down ? 1 : -1)
                .position(x: a.leansLeft ? a.tipX + half : a.tipX - half, y: down ? size.height + 4 : -4)
        }
        if badged {
            badge.offset(x: a.leansLeft ? -6 : 6, y: down ? -10 : 10)
                .frame(width: size.width, height: size.height,
                       alignment: Alignment(horizontal: a.leansLeft ? .trailing : .leading, vertical: down ? .top : .bottom))
        }
    }

    @ViewBuilder private var content: some View {
        let (text, tag) = parts
        if bubble.kind == .reply, bubble.mode == .chat { // scrolls only when taller than 150 pt
            Cap(height: 150) {
                ViewThatFits(in: .vertical) {
                    rich(text).textSelection(.enabled)
                    ScrollView { rich(text).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                }
            }
        } else if bubble.kind == .status {
            (rich(text) + Text(text.hasSuffix("failed") ? "" : "…").foregroundColor(PN.pink400)).lineLimit(3)
        } else {
            rich(text).lineLimit(bubble.kind == .reply ? 5 : 3)
        }
        if hasMore { HStack(spacing: 4) { Text("…more in"); Icon(name: "code", ink: PN.muted) }.foregroundStyle(PN.muted) }
        if let tag {
            Text(tag.uppercased()).padding(.horizontal, 4)
                .foregroundStyle(tag == "Denied" ? PN.snow : PN.outline)
                .background(tag == "Allowed" ? PN.leaf : tag == "Denied" ? PN.berry : PN.gold)
        }
    }

    @ViewBuilder private var actions: some View {
        if case .approval(let id) = bubble.kind, !bubble.settled {
            // ALLOW 71 + DENY 64 + CONSOLE 85 + two 8 pt gaps = 236 pt, exactly the bubble's inner width
            HStack(spacing: 8) {
                Button { model.answer(id, .allow) } label: { Icon(name: "allow"); Text("Allow") }.buttonStyle(PixelButton(kind: .allow))
                Button { model.answer(id, .deny) } label: { Icon(name: "deny"); Text("Deny") }.buttonStyle(PixelButton(kind: .deny))
                Button { model.openTerminal(bubble.mode, requestId: id) } label: { Icon(name: "terminal"); Text("Console") }
                    .buttonStyle(PixelButton(kind: .quiet))
            }
        }
        if bubble.kind == .question, !bubble.settled {
            Button { model.openTerminal(bubble.mode, requestId: nil) } label: { Icon(name: "terminal"); Text("Answer in console") }
                .buttonStyle(PixelButton(kind: .quiet))
        }
        if bubble.kind == .consoleNeeded, !bubble.settled {
            Button { model.openConsole(tab: bubble.mode) } label: { Icon(name: "terminal"); Text("Open console") }
                .buttonStyle(PixelButton(kind: .quiet))
        }
    }

    /// A bubble from the mode you aren't looking at: a small wooden CHAT / CODE badge on its top edge.
    private var badge: some View {
        HStack(spacing: 2) { Icon(name: bubble.mode == .chat ? "chat" : "code", ink: PN.muted); Text(bubble.mode == .chat ? "CHAT" : "CODE") }
            .foregroundStyle(PN.muted)
            .padding(.leading, 2).padding(.trailing, 4)
            .pixelFrame(fill: PN.hair700, hi: PN.hair500, lo: PN.hair700, drop: .none)
    }

    private static let more = "\n…more in ⌘"
    private var hasMore: Bool { bubble.kind == .reply && bubble.text.hasSuffix(Self.more) }

    /// The text, minus the "…more in ⌘" line (drawn with the pixel icon) and the settle label (drawn as a tag).
    private var parts: (String, String?) {
        var t = bubble.text
        if hasMore { t.removeLast(Self.more.count) }
        if case .approval = bubble.kind, bubble.settled, let r = t.range(of: " — ", options: .backwards) {
            return (String(t[..<r.lowerBound]), String(t[r.upperBound...]))
        }
        return (t, nil)
    }

    /// `backticked` spans become code chips on plum-900.
    private func rich(_ s: String) -> Text {
        var out = AttributedString()
        for (i, seg) in s.components(separatedBy: "`").enumerated() {
            if i % 2 == 1, !seg.isEmpty {
                var code = AttributedString(" \(seg) ")
                code.backgroundColor = PN.plum900
                code.foregroundColor = bubble.kind == .user ? PN.snow : PN.cream
                out += code
            } else {
                out += AttributedString(seg)
            }
        }
        return Text(out)
    }

    private var header: (icon: String, label: String, color: Color)? {
        switch bubble.kind {
        case .approval, .consoleNeeded: bubble.settled ? nil : ("alert", "NEEDS YOU", PN.gold)
        case .question: bubble.settled ? nil : ("more", "QUESTION", PN.gold)
        case .alert: ("alert", "HEADS UP", PN.gold)
        case .error: ("deny", "FAILED", PN.blush)
        default: nil
        }
    }

    private var style: (fill: Color, hi: Color, lo: Color, ink: Color, drop: PixelDrop) {
        switch bubble.kind {
        case .user: (PN.cream, PN.snow, PN.muted, PN.outline, .small) // your messages are cream paper
        case .status: (PN.plum800, PN.plum600, PN.plum800, PN.muted, .small)
        case .error: (PN.wine, PN.berry, PN.plum900, PN.cream, .small)
        case .alert: (PN.plum700, PN.gold, PN.plum800, PN.cream, .small)
        case .approval, .question, .consoleNeeded: (PN.plum700, bubble.settled ? PN.plum600 : PN.gold, PN.plum800, PN.cream, .large)
        case .reply: (PN.plum700, PN.pink400, PN.plum800, PN.cream, .small)
        }
    }

    private var hasButtons: Bool {
        guard !bubble.settled else { return bubble.kind == .reply && bubble.mode == .chat }
        if case .approval = bubble.kind { return true }
        return bubble.kind == .question || bubble.kind == .consoleNeeded || (bubble.kind == .reply && bubble.mode == .chat)
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

/// The pixel frame Nell draws around the kitty panel: outline, an uppercase title strip with minimise, and a stepped
/// tail toward her. The middle stays hollow: kitty shows through it and it never takes clicks.
struct ConsoleFrame: View {
    let project: String; let toward: Side; let minimise: () -> Void
    var body: some View {
        let ring = ConsoleChrome.border - PN.px // plum between the outline and kitty
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Icon(name: "code")
                Text("CLAUDE CODE · \(project.uppercased())").lineLimit(1)
                Spacer(minLength: 4)
                Button(action: minimise) {
                    PN.cream.frame(width: 8, height: PN.px).offset(y: 3).frame(width: 16, height: 16)
                        .pixelFrame(fill: PN.plum800, hi: PN.plum600, lo: PN.plum900, drop: .none)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain).help("Minimise").accessibilityLabel("Minimise")
            }
            .foregroundStyle(PN.cream)
            .padding(.horizontal, 6).padding(.top, PN.px)
            .frame(maxWidth: .infinity)
            .frame(height: ring + ConsoleChrome.title)
            .background { VStack(spacing: 0) { PN.pink400.frame(height: PN.px); PN.plum700 } }
            .interactive()
            HStack(spacing: 0) { PN.plum700.frame(width: ring); Color.clear; PN.plum700.frame(width: ring) }
            PN.plum800.frame(height: ring) // bottom bevel
        }
        .padding(PN.px)
        .background(alignment: .bottom) { PN.plum900.frame(height: PN.px).padding(.horizontal, PN.px).offset(y: PN.px) }
        .overlay(PixelEdges().fill(PN.outline))
        .overlay(alignment: toward == .left ? .bottomTrailing : .bottomLeading) {
            PixelArt.sideTail(PN.plum700).scaleEffect(x: toward == .left ? 1 : -1).offset(x: toward == .left ? 10 : -10, y: -12)
        }
    }
}

/// The minimised console: a quiet plum-800 strip with Code's status. Clicking it opens the console.
struct MinimisedConsole: View {
    let status: String?; let toward: Side; let open: () -> Void
    var body: some View {
        Button(action: open) {
            HStack(spacing: 4) {
                Icon(name: "code", ink: PN.muted)
                Text(status ?? "Claude Code is idle").lineLimit(1)
                Spacer(minLength: 4)
                Text("OPEN").foregroundStyle(PN.pink400)
            }
            .foregroundStyle(PN.muted)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .pixelFrame(fill: PN.plum800, hi: PN.plum600, lo: PN.plum900)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// One bubble in the column, placed by `bubbleX` from its own measured width: the column's full width, the bubble's height.
struct ColumnRow: SwiftUI.Layout {
    let width: CGFloat, headX: CGFloat, mine: Bool
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        CGSize(width: width, height: subviews.first?.sizeThatFits(ProposedViewSize(width: width, height: nil)).height ?? 0)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let s = subviews.first else { return }
        let size = s.sizeThatFits(ProposedViewSize(width: width, height: nil))
        let x = bubbleX(width: size.width, columnWidth: width, headX: headX, mine: mine)
        s.place(at: CGPoint(x: bounds.minX + x, y: bounds.minY), proposal: ProposedViewSize(size))
    }
}

/// Proposes at most `width` × `height` but takes only what its content needs (a plain `.frame(maxWidth:)` would expand).
struct Cap: SwiftUI.Layout {
    var width: CGFloat? = nil, height: CGFloat? = nil
    private func capped(_ p: ProposedViewSize) -> ProposedViewSize {
        ProposedViewSize(width: width.map { min(p.width ?? $0, $0) } ?? p.width, height: height.map { min(p.height ?? $0, $0) } ?? p.height)
    }
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        subviews.first?.sizeThatFits(capped(proposal)) ?? .zero
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
    }
}
