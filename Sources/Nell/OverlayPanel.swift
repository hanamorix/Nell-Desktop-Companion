import AppKit
import NellCore
import SwiftUI

/// Borderless, non-activating, above full-screen apps, in every Space. Only the message bar ever makes it key.
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
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Views that should take clicks report their frames; everywhere else clicks fall through to the app behind.
struct InteractiveRectsKey: PreferenceKey {
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
    func grabbable() -> some View {
        background(GeometryReader { g in Color.clear.preference(key: GrabRectsKey.self, value: [g.frame(in: .global)]) })
    }
}

/// Moves Nell's window to the layout, decides click-through 10× a second, and drags her (with ⌥).
@MainActor final class PanelController {
    let panel: OverlayPanel
    var rects: [CGRect] = []
    var grabRects: [CGRect] = []
    var hoverRects: [UUID: CGRect] = [:]
    var paused = false
    /// Bottom-left of Nell's block in screen coordinates; the layout grows everything else around it.
    var nellOrigin: CGPoint = .zero
    var onPositionSaved: ((String, CGPoint) -> Void)?
    var onHover: ((UUID?) -> Void)?
    private var timer: Timer?
    private var dragStart: (mouse: NSPoint, origin: NSPoint, nell: CGPoint)?

    static let nellSize = CGSize(width: 230, height: 200)
    static let columnSize = CGSize(width: 270, height: 320)
    static let minimisedSize = CGSize(width: 340, height: 30)

    init(panel: OverlayPanel) { self.panel = panel }

    var screen: NSScreen? {
        NSScreen.screens.first { $0.frame.contains(CGPoint(x: nellOrigin.x + 1, y: nellOrigin.y + 1)) } ?? NSScreen.main
    }

    /// Lays everything out for `phase` around Nell and moves the window there.
    func relayout(_ phase: ConsolePhase, cell: CGSize) -> NellCore.Layout {
        let s = screen?.visibleFrame ?? .zero
        let l = layout(LayoutInput(screen: s, nellOrigin: nellOrigin, nellSize: Self.nellSize, columnSize: Self.columnSize, console: phase,
                                   cell: cell, consoleChrome: CGSize(width: 2 * ConsoleChrome.border, height: 2 * ConsoleChrome.border + ConsoleChrome.title),
                                   minimisedSize: Self.minimisedSize))
        nellOrigin = l.nellFrame.origin // the layout may have clamped her back on screen
        panel.setFrame(l.panelFrame, display: true)
        return l
    }

    /// 10 Hz: let clicks through unless the pointer is on a control, or on Nell with ⌥ held. Also tracks hover.
    func startClickThrough() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateMouse() }
        }
    }

    private func updateMouse() {
        guard !paused, panel.isVisible, let content = panel.contentView else { return }
        if dragStart != nil { return } // keep the sprite solid mid-drag even if ⌥ is released
        let w = panel.convertPoint(fromScreen: NSEvent.mouseLocation)
        let p = CGPoint(x: w.x, y: content.bounds.height - w.y)
        let inside = isInteractive(p, rects: rects, grabRects: grabRects, optionHeld: NSEvent.modifierFlags.contains(.option))
        if panel.ignoresMouseEvents == inside { panel.ignoresMouseEvents = !inside }
        onHover?(hoverRects.first { $0.value.contains(p) }?.key)
    }

    /// Returns true on the first call of a drag, so the caller can hide the console.
    func dragChanged() -> Bool {
        let m = NSEvent.mouseLocation
        let first = dragStart == nil
        if first { dragStart = (m, panel.frame.origin, nellOrigin) }
        guard let s = dragStart else { return false }
        panel.setFrameOrigin(NSPoint(x: s.origin.x + m.x - s.mouse.x, y: s.origin.y + m.y - s.mouse.y))
        nellOrigin = CGPoint(x: s.nell.x + m.x - s.mouse.x, y: s.nell.y + m.y - s.mouse.y)
        return first
    }

    func dragEnded() {
        dragStart = nil
        onPositionSaved?(displayKey(screen), nellOrigin)
    }

    func displayKey(_ screen: NSScreen?) -> String {
        (screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.stringValue ?? "main"
    }

    /// Saved spot for the main display, else bottom-right of it.
    func restore(positions: [String: CGPoint]) {
        let main = NSScreen.main ?? NSScreen.screens.first
        if let p = positions[displayKey(main)] { nellOrigin = p }
        else if let v = main?.visibleFrame { nellOrigin = CGPoint(x: v.maxX - Self.nellSize.width - 16, y: v.minY + 16) }
    }
}
