import AppKit
import NellCore
import SwiftUI

/// Plum Night in SwiftUI: colours from `PlumNight.palette`, the pixel frame, buttons, mode chips and icons.
/// Everything sits on the 2 pt art-pixel grid; there are no curves anywhere.
typealias PN = PlumNight

extension PlumNight {
    /// One art pixel.
    static let px: CGFloat = 2

    /// The theme the interface is drawn in; switching it and rebuilding the views recolours everything.
    @MainActor static var theme = Themes.plumNight
    @MainActor static func color(_ name: String) -> Color {
        let v = UInt32(theme.palette[name]!.dropFirst(), radix: 16)!
        return Color(.sRGB, red: Double(v >> 16 & 0xff) / 255, green: Double(v >> 8 & 0xff) / 255, blue: Double(v & 0xff) / 255)
    }
    @MainActor static var outline: Color { color("outline") }
    @MainActor static var plum900: Color { color("plum-900") }
    @MainActor static var plum800: Color { color("plum-800") }
    @MainActor static var plum700: Color { color("plum-700") }
    @MainActor static var plum600: Color { color("plum-600") }
    @MainActor static var plum500: Color { color("plum-500") }
    @MainActor static var hair700: Color { color("hair-700") }
    @MainActor static var hair500: Color { color("hair-500") }
    @MainActor static var cream: Color { color("cream") }
    @MainActor static var snow: Color { color("snow") }
    @MainActor static var muted: Color { color("muted") }
    @MainActor static var blush: Color { color("blush") }
    @MainActor static var pink400: Color { color("pink-400") }
    @MainActor static var pink600: Color { color("pink-600") }
    @MainActor static var berry: Color { color("berry") }
    @MainActor static var wine: Color { color("wine") }
    @MainActor static var leaf: Color { color("leaf") }
    @MainActor static var leaf700: Color { color("leaf-700") }
    /// The Allow button's top highlight: the theme's leaf halfway to white (Plum Night keeps its drawn #c6efb7).
    @MainActor static var leafHi: Color {
        if theme == Themes.plumNight { return Color(.sRGB, red: 0xc6 / 255, green: 0xef / 255, blue: 0xb7 / 255) }
        let v = UInt32(theme.palette["leaf"]!.dropFirst(), radix: 16)!
        let mix = { (c: UInt32) in (Double(c & 0xff) + 255) / 2 / 255 }
        return Color(.sRGB, red: mix(v >> 16), green: mix(v >> 8), blue: mix(v))
    }
    @MainActor static var gold: Color { color("gold") }
    @MainActor static var gold700: Color { color("gold-700") }
}

/// The 1-art-pixel outline on four sides, corner pixels left empty: the notch.
struct PixelEdges: Shape {
    func path(in r: CGRect) -> Path {
        let p = PN.px
        return Path { path in
            path.addRect(CGRect(x: r.minX + p, y: r.minY, width: r.width - 2 * p, height: p))
            path.addRect(CGRect(x: r.minX + p, y: r.maxY - p, width: r.width - 2 * p, height: p))
            path.addRect(CGRect(x: r.minX, y: r.minY + p, width: p, height: r.height - 2 * p))
            path.addRect(CGRect(x: r.maxX - p, y: r.minY + p, width: p, height: r.height - 2 * p))
        }
    }
}

enum PixelDrop { case none, small, large }

/// The frame recipe: outline with notched corners, a fill, a top highlight and bottom bevel, and a hard drop.
/// Adds one art pixel around the content for the outline; the bevels sit inside the content's own padding.
struct PixelFrame: ViewModifier {
    var fill = PN.plum700, hi = PN.pink400, lo = PN.plum800
    var drop = PixelDrop.small
    /// The message bar's focus ring: pink outline, then the dark outline outside it.
    var focused = false

    func body(content: Content) -> some View {
        let p = PN.px
        content
            .padding(p)
            .background {
                ZStack {
                    // hard shadow, no blur: `drop` one art pixel down, `drop-lg` 1 right and 2 down
                    if drop != .none {
                        PN.plum900.padding(.horizontal, p).offset(x: drop == .large ? p : 0, y: drop == .large ? 2 * p : p)
                    }
                    VStack(spacing: 0) { hi.frame(height: p); fill; lo.frame(height: p) }.padding(p)
                    PixelEdges().fill(focused ? PN.pink400 : PN.outline)
                    if focused { PixelEdges().fill(PN.outline).padding(-p) }
                }
            }
    }
}

extension View {
    func pixelFrame(fill: Color = PN.plum700, hi: Color = PN.pink400, lo: Color = PN.plum800,
                    drop: PixelDrop = .small, focused: Bool = false) -> some View {
        modifier(PixelFrame(fill: fill, hi: hi, lo: lo, drop: drop, focused: focused))
    }
}

/// A small piece of pixel art from rows of characters (one per art pixel); unknown characters stay clear.
struct PixelArt: View {
    let rows: [String]; let colors: [Character: Color]
    var body: some View {
        let p = PN.px
        Canvas { ctx, _ in
            for (y, row) in rows.enumerated() {
                for (x, ch) in row.enumerated() {
                    if let c = colors[ch] { ctx.fill(Path(CGRect(x: CGFloat(x) * p, y: CGFloat(y) * p, width: p, height: p)), with: .color(c)) }
                }
            }
        }
        .frame(width: CGFloat(rows[0].count) * p, height: CGFloat(rows.count) * p)
    }

    /// The stepped speech tail from bundle.css, pointing down-left. Its top row overlaps the bubble's bottom outline.
    static func tail(_ fill: Color) -> PixelArt {
        PixelArt(rows: ["OFFFFF", "OFFFFO", "OFFFO.", "OFFO..", "OFO...", "OO...."], colors: ["O": PN.outline, "F": fill])
    }
    /// The same tail turned to point sideways (right); its left column overlaps the frame's side outline.
    static func sideTail(_ fill: Color) -> PixelArt {
        PixelArt(rows: ["OOOOOO", "FFFFFO", "FFFFO.", "FFFO..", "FFO...", "FO...."], colors: ["O": PN.outline, "F": fill])
    }
}

/// One of the 8 pixel icons (16×16 SVG), drawn nearest-neighbour at 16 or 32 pt. Tinted to `ink`, or to the
/// surrounding foreground when nil (so a button's icon takes its label's ink, e.g. outline on leaf).
struct Icon: View {
    let name: String; var ink: Color? = nil; var size: CGFloat = 16
    @MainActor private static var cache: [String: NSImage] = [:]

    var body: some View {
        if let img = Self.image(name) {
            let i = Image(nsImage: img).renderingMode(.template).resizable().interpolation(.none)
                .frame(width: size, height: size).accessibilityHidden(true)
            if let ink { i.foregroundStyle(ink) } else { i }
        }
    }

    @MainActor static func image(_ name: String) -> NSImage? {
        if let i = cache[name] { return i }
        guard let i = NSImage(contentsOf: resourceURL("icons/nell-\(name).svg")) else { return nil }
        i.isTemplate = true
        cache[name] = i
        return i
    }
}

/// The chunky bevelled button. Pressed: the top bevel turns dark and the label drops one art pixel; the button never moves.
struct PixelButton: ButtonStyle {
    enum Kind { case allow, deny, quiet, plain }
    var kind = Kind.plain
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        let (fill, hi, lo, ink) = colors
        let down = configuration.isPressed && enabled
        return HStack(spacing: 4) { configuration.label }
            .font(Fonts.ui()).textCase(.uppercase).lineLimit(1).fixedSize()
            .foregroundStyle(ink)
            .padding(.horizontal, 6)
            .padding(.top, down ? 10 : 8).padding(.bottom, down ? 4 : 6)
            .pixelFrame(fill: fill, hi: down ? lo : hi, lo: down ? fill : lo, drop: .none)
            .contentShape(Rectangle())
    }

    /// The ink also tints the button's icon: outline ink on leaf, as the design system asks.
    private var colors: (Color, Color, Color, Color) {
        guard enabled else { return (PN.plum800, PN.plum800, PN.plum800, PN.plum500) }
        switch kind {
        case .allow: return (PN.leaf, PN.leafHi, PN.leaf700, PN.outline)
        case .deny: return (PN.berry, PN.pink600, PN.wine, PN.snow)
        case .quiet: return (PN.plum800, PN.plum600, PN.plum900, PN.cream)
        case .plain: return (PN.plum600, PN.pink400, PN.plum800, PN.cream)
        }
    }
}

/// A mode switch under Nell's desk, drawn as a small wooden chip; selected chips turn plum with a pink underline.
/// Icon-only so the bar beside them stays wide; the name is in the tooltip and accessibility label.
struct ModeChip: View {
    let icon: String; let help: String; let on: Bool; let news: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 2) {
                Icon(name: icon, ink: on ? PN.cream : PN.muted).opacity(on ? 1 : 0.7)
                if news { PN.gold.frame(width: 4, height: 4) }
            }
            .padding(.horizontal, 6).padding(.top, 6).padding(.bottom, 4)
            .pixelFrame(fill: on ? PN.plum700 : PN.hair700, hi: on ? PN.pink400 : PN.hair500, lo: PN.plum900, drop: .none)
            .overlay(alignment: .bottom) { if on { PN.pink400.frame(width: 6, height: 2).offset(y: 4) } }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).help(help).accessibilityLabel(help)
    }
}

/// A usage gauge beside Chat and Code: the window's label over a sunken meter well filled to its fraction.
/// No reading shows a dimmed dash. The tooltip carries the numbers and reset time.
struct UsageChip: View {
    let kind: UsageKind; let gauge: UsageGauge
    var body: some View {
        let fill = gauge.level == .high ? PN.berry : gauge.level == .mid ? PN.gold : PN.leaf
        VStack(spacing: 2) {
            Text(kind.label).font(Fonts.ui()).foregroundColor(PN.muted).frame(height: 10)
            ZStack(alignment: .leading) {
                PN.plum900
                PN.outline.frame(height: 2).frame(maxHeight: .infinity, alignment: .top)
                if let f = gauge.fraction {
                    // option A: an outline line on top of the well, the fill taking the 6 pt below it
                    fill.frame(width: (20 * f / PN.px).rounded() * PN.px, height: 6).frame(maxHeight: .infinity, alignment: .bottom)
                } else {
                    Text("\u{2013}").font(Fonts.ui()).foregroundColor(PN.muted).opacity(0.5).frame(maxWidth: .infinity)
                }
            }
            .frame(width: 20, height: 8)
        }
        .frame(width: 28, height: 26)
        .pixelFrame(fill: PN.plum700, hi: PN.plum600, lo: PN.plum900, drop: .none)
        .help(gauge.tooltip).accessibilityElement(children: .ignore).accessibilityLabel(gauge.tooltip)
    }
}
