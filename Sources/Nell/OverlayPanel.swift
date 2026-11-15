import AppKit
import NellCore
import SwiftUI

/// Borderless, non-activating, above full-screen apps, in every Space. Only the message bar and Chat replies make it key.
final class OverlayPanel: NSPanel {
    init(size: NSSize) {
        super.init(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        hidesOnDeactivate = false
        ignoresMouseEvents = true
    }
    /// True for a window point (AppKit coords) on a view that needs the keyboard (the bar, a selectable reply). A click
    /// anywhere else, buttons included, must leave the keyboard with the app you're typing in; SwiftUI buttons fire
    /// without it. (`becomesKeyOnlyIfNeeded` can't tell: SwiftUI's hosting view always says it needs the keyboard.)
    var takesKeyboard: (NSPoint) -> Bool = { _ in false }
    private var keyAllowed = true
    override var canBecomeKey: Bool { keyAllowed }
    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown || event.type == .rightMouseDown { keyAllowed = takesKeyboard(event.locationInWindow) }
        super.sendEvent(event) // makes the panel key here, if it's allowed to
        keyAllowed = true // ⌥⌘N's makeKey() comes outside a click
    }
    override var canBecomeMain: Bool { false }
}

/// Views that should take clicks report their frames; everywhere else clicks fall through to the app behind.
struct InteractiveRectsKey: PreferenceKey {
    static let defaultValue: [CGRect] = []
    static func reduce(value: inout [CGRect], nextValue: () -> [CGRect]) { value += nextValue() }
}

/// Views that need the keyboard when clicked (the bar, a selectable reply); every other click leaves it where it was.
struct KeyRectsKey: PreferenceKey {
    static let defaultValue: [CGRect] = []
    static func reduce(value: inout [CGRect], nextValue: () -> [CGRect]) { value += nextValue() }
}

/// Nell's sprite: takes clicks only while ⌥ is held.
struct GrabRectsKey: PreferenceKey {
    static let defaultValue: [CGRect] = []
    static func reduce(value: inout [CGRect], nextValue: () -> [CGRect]) { value += nextValue() }
}

/// Every bubble's frame, so hover can pause fading without the bubble taking clicks.
struct HoverRectsKey: PreferenceKey {
    static let defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) { value.merge(nextValue()) { $1 } }
}

extension View {
    func interactive() -> some View {
        background(GeometryReader { g in Color.clear.preference(key: InteractiveRectsKey.self, value: [g.frame(in: .global)]) })
    }
    /// Takes clicks and, when clicked, the keyboard.
    func takesKeyboard() -> some View {
        interactive().background(GeometryReader { g in Color.clear.preference(key: KeyRectsKey.self, value: [g.frame(in: .global)]) })
    }
    func grabbable() -> some View {
        background(GeometryReader { g in Color.clear.preference(key: GrabRectsKey.self, value: [g.frame(in: .global)]) })
    }
}

/// Moves Nell's window to the layout, decides click-through 10× a second, and drags her (with ⌥).
@MainActor final class PanelController {
    let panel: OverlayPanel
    var rects: [CGRect] = []
    var grabRects: [CGRect] = []
    var keyRects: [CGRect] = []
    /// Her drawn pixels at a point in the sprite box: those take clicks (the right-click menu) even without ⌥.
    var spriteOpaque: (CGPoint) -> Bool = { _ in false }
    var hoverRects: [UUID: CGRect] = [:]
    /// Locked, asleep or hidden: the 10 Hz poll stops.
    var paused = false { didSet { if paused != oldValue { paused ? stopClickThrough() : startClickThrough() } } }
    /// Bottom-left of Nell's block in screen coordinates; the layout grows everything else around it.
    var nellOrigin: CGPoint = .zero
    var onPositionSaved: ((String, CGPoint) -> Void)?
    var onHover: ((UUID?) -> Void)?
    /// The window started or stopped taking clicks (the showcase logs it).
    var onHitChange: ((Bool) -> Void)?
    private var timer: Timer?
    private var dragStart: (mouse: NSPoint, origin: NSPoint, nell: CGPoint)?
    private var dragLatch = DragLatch()
    /// Which way she faced at the last layout, so turning around doesn't move her sprite.
    private var faceRight: Bool?

    init(panel: OverlayPanel) {
        self.panel = panel
        panel.takesKeyboard = { [weak self] w in
            guard let self, let content = panel.contentView else { return false }
            return clickTakesKeyboard(CGPoint(x: w.x, y: content.bounds.height - w.y), keyRects: keyRects)
        }
    }

    /// shortcut: Nell stays on the primary display (the menu-bar one), where kitty's panel lives — kitty isn't told an
    /// --output-name yet. Dropping her on another display pulls her back. Upgrade when multi-display is designed.
    var screen: NSScreen? { NSScreen.screens.first }

    /// Lays everything out for `phase` around Nell and moves the window there. With no display (none attached for a
    /// moment) there's nothing to lay out against, so it returns nil and the last layout stays.
    func relayout(_ phase: ConsolePhase, cell: CGSize) -> NellCore.Layout? {
        guard let s = screen?.visibleFrame else { return nil }
        let l = layoutKeepingHerStill(LayoutInput(screen: s, nellOrigin: nellOrigin, nellSize: NellBlock.size, columnSize: NellBlock.column,
                                                  console: phase, cell: cell,
                                                  consoleChrome: CGSize(width: 2 * ConsoleChrome.border, height: 2 * ConsoleChrome.border + ConsoleChrome.title),
                                                  minimisedSize: NellBlock.minimised), wasFaceRight: faceRight)
        faceRight = l.faceRight
        nellOrigin = l.nellFrame.origin // the layout may have clamped her back on screen, or shifted the block as she turned
        panel.setFrame(l.panelFrame, display: true)
        return l
    }

    /// 10 Hz: let clicks through unless the pointer is on a control, or on Nell with ⌥ held. Also tracks hover.
    /// shortcut: polled, so a click within 0.1 s of moving onto or off a control can go to the wrong window (it no longer
    /// takes the keyboard). Mouse-moved monitors would also need ⌥ changes, and Apple documents global key-related
    /// monitors as needing Accessibility trust, which Nell doesn't ask for. Upgrade if that lag is ever noticed.
    func startClickThrough() {
        stopClickThrough()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateMouse() }
        }
    }
    private func stopClickThrough() { timer?.invalidate(); timer = nil }

    /// Whether a click at `p` (content-view points, y down) would land on Nell rather than pass through.
    func takesClick(at p: CGPoint) -> Bool {
        isInteractive(p, rects: rects, grabRects: grabRects, optionHeld: NSEvent.modifierFlags.contains(.option), opaqueAt: spriteOpaque)
    }

    private func updateMouse() {
        guard panel.isVisible, let content = panel.contentView else { return }
        if dragStart != nil { return } // keep the sprite solid mid-drag even if ⌥ is released
        let w = panel.convertPoint(fromScreen: NSEvent.mouseLocation)
        let p = CGPoint(x: w.x, y: content.bounds.height - w.y)
        let inside = takesClick(at: p)
        if panel.ignoresMouseEvents == inside { panel.ignoresMouseEvents = !inside; onHitChange?(inside) }
        onHover?(hoverRects.first { $0.value.contains(p) }?.key)
    }

    /// Returns true on the first call of a drag, so the caller can hide the console.
    /// `start` is the gesture's start location: ⌥ is decided once, when the gesture starts, so a plain drag never moves her.
    func dragChanged(start: CGPoint) -> Bool {
        guard dragLatch.allows(start: start, optionHeld: NSEvent.modifierFlags.contains(.option)) else { return false }
        let m = NSEvent.mouseLocation
        let first = dragStart == nil
        if first { dragStart = (m, panel.frame.origin, nellOrigin) }
        guard let s = dragStart else { return false }
        let dx = (m.x - s.mouse.x).rounded(), dy = (m.y - s.mouse.y).rounded() // whole points keep her pixels crisp
        panel.setFrameOrigin(NSPoint(x: s.origin.x + dx, y: s.origin.y + dy))
        nellOrigin = CGPoint(x: s.nell.x + dx, y: s.nell.y + dy)
        return first
    }

    /// Returns true if a drag actually happened; the caller relays out, then calls `savePosition`.
    func dragEnded() -> Bool {
        dragLatch.reset()
        guard dragStart != nil else { return false }
        dragStart = nil
        return true
    }

    /// Saves where she is now. After the drop's relayout: turning around shifts the block, and relaunch must find it there.
    func savePosition() { onPositionSaved?(displayKey(screen), nellOrigin) }

    func displayKey(_ screen: NSScreen?) -> String {
        (screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.stringValue ?? "main"
    }

    /// Saved spot for her display (the one layout and saving use), else bottom-right of it.
    func restore(positions: [String: CGPoint]) {
        if let p = positions[displayKey(screen)] { nellOrigin = CGPoint(x: p.x.rounded(), y: p.y.rounded()) }
        else if let v = screen?.visibleFrame { nellOrigin = CGPoint(x: v.maxX - NellBlock.size.width - 16, y: v.minY + 16) }
    }
}
