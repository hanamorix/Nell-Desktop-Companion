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

extension View {
    func interactive() -> some View {
        background(GeometryReader { g in Color.clear.preference(key: InteractiveRectsKey.self, value: [g.frame(in: .global)]) })
    }
}

@MainActor final class PanelController {
    let panel: OverlayPanel
    var rects: [CGRect] = []
    var paused = false
    var onPositionSaved: ((String, CGPoint) -> Void)?
    private var timer: Timer?
    private var dragStart: (mouse: NSPoint, origin: NSPoint)?

    init(panel: OverlayPanel) { self.panel = panel }

    /// 10 Hz: let clicks through unless the pointer is over Nell, a bubble or the bar.
    func startClickThrough() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateMouse() }
        }
    }

    private func updateMouse() {
        guard !paused, panel.isVisible, let content = panel.contentView else { return }
        let p = panel.convertPoint(fromScreen: NSEvent.mouseLocation)
        let inside = isInteractive(CGPoint(x: p.x, y: content.bounds.height - p.y), rects: rects)
        if panel.ignoresMouseEvents == inside { panel.ignoresMouseEvents = !inside }
    }

    func dragChanged() {
        let m = NSEvent.mouseLocation
        if dragStart == nil { dragStart = (m, panel.frame.origin) }
        guard let s = dragStart else { return }
        panel.setFrameOrigin(NSPoint(x: s.origin.x + m.x - s.mouse.x, y: s.origin.y + m.y - s.mouse.y))
    }

    func dragEnded() {
        dragStart = nil
        clampToScreen()
        onPositionSaved?(displayKey(panel.screen), panel.frame.origin)
    }

    func displayKey(_ screen: NSScreen?) -> String {
        (screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.stringValue ?? "main"
    }

    /// Saved spot for the main display, else bottom-right of it.
    func restore(positions: [String: CGPoint]) {
        let main = NSScreen.main ?? NSScreen.screens.first
        if let p = positions[displayKey(main)] { panel.setFrameOrigin(p) }
        else if let v = main?.visibleFrame { panel.setFrameOrigin(NSPoint(x: v.maxX - panel.frame.width - 24, y: v.minY + 24)) }
        clampToScreen()
    }

    /// Pulls Nell back inside a display that still exists (a display was unplugged, or she was dragged off).
    func clampToScreen() {
        let f = panel.frame
        let screen = NSScreen.screens.first { $0.visibleFrame.intersects(f) } ?? NSScreen.main
        guard let v = screen?.visibleFrame else { return }
        let x = min(max(f.minX, v.minX), v.maxX - f.width)
        let y = min(max(f.minY, v.minY), v.maxY - f.height)
        if x != f.minX || y != f.minY { panel.setFrameOrigin(NSPoint(x: x, y: y)) }
    }
}
