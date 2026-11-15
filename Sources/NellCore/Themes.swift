import Foundation

/// A dark colour theme: the 21 Plum Night token keys plus the 16 console (ANSI) colours.
public struct Theme: Sendable, Equatable, Identifiable {
    /// The display name.
    public let id: String
    public let palette: [String: String]
    public let ansi: [String]
}

public enum Themes {
    private static let keys = ["outline", "plum-900", "plum-800", "plum-700", "plum-600", "plum-500", "hair-700", "hair-500", "cream", "snow", "muted", "blush", "pink-400", "pink-600", "berry", "wine", "user-blue", "user-blue-hi", "leaf", "leaf-700", "gold", "gold-700"]

    private static func make(_ id: String, _ values: [String], _ ansi: [String]) -> Theme {
        Theme(id: id, palette: Dictionary(uniqueKeysWithValues: zip(keys, values)), ansi: ansi)
    }

    public static let plumNight = Theme(id: "Plum Night", palette: PlumNight.palette, ansi: [
        "#261a22", "#cf7d8b", "#4f8a46", "#a8762f", "#6f8fd0", "#f4b6ac", "#6f8fd0", "#f5d4c9", "#c4a9ab", "#ec9394", "#8ccf7a", "#e9b45f", "#6f8fd0", "#f4b6ac", "#6f8fd0", "#fff4ec",
    ])

    static let moss = make("Moss", [
        "#0c120e", "#121a15", "#1a261e", "#2c3f31", "#384a3c", "#56635a", "#2e2a1f", "#4d4635", "#e4ead0", "#f6f9ea", "#a9b59f", "#d9c79a", "#c9a85b", "#a8873f", "#b0574a", "#6a2f28", "#3d6470", "#6fa3b0", "#9fd37a", "#5a8a3f", "#e6c15c", "#a3812c",
    ], [
        "#1a261e", "#d9806f", "#7fb85a", "#c9a03f", "#6f9fd0", "#c48fb8", "#5fb8a8", "#e4ead0", "#a9b59f", "#ee9a8a", "#9fd37a", "#e6c15c", "#8fbbe6", "#deaad0", "#86d4c4", "#f6f9ea",
    ])

    static let tide = make("Tide", [
        "#0a0f17", "#0f1622", "#172133", "#263650", "#30415c", "#4f5d73", "#2a2a3a", "#474a60", "#d6e4f0", "#f2f8fd", "#9fb1c4", "#a9d8d6", "#5cc8c0", "#3fa39c", "#ac4a5a", "#6e2a36", "#5a4a9e", "#9283d6", "#7fd49a", "#3f8a5a", "#e8c060", "#a5822c",
    ], [
        "#172133", "#e0707f", "#6cc58a", "#d4aa4a", "#6fa0e0", "#b58ae0", "#4fc4c0", "#d6e4f0", "#9fb1c4", "#f2909c", "#7fd49a", "#e8c060", "#90bdf5", "#cfa8f2", "#7fdcd8", "#f2f8fd",
    ])

    static let ember = make("Ember", [
        "#120c0a", "#1a1310", "#261c17", "#3d2d25", "#4a382e", "#6a5a50", "#3a2a20", "#5e4636", "#f2dcc4", "#fff6ea", "#c2a891", "#f0b98a", "#ee8a4a", "#c96d33", "#b8483e", "#6a2620", "#3f5f8c", "#7698c8", "#9ccf6e", "#5a8a38", "#f0c25a", "#aa8228",
    ], [
        "#261c17", "#e0685c", "#8cbf5e", "#d9a845", "#6f98d0", "#c78ab0", "#5fb5ab", "#f2dcc4", "#c2a891", "#f2897d", "#9ccf6e", "#f0c25a", "#8fb4e6", "#e0a8cc", "#86d0c6", "#fff6ea",
    ])

    static let slate = make("Slate", [
        "#0d0f12", "#14171b", "#1d2127", "#2e343d", "#39404a", "#5a616b", "#2b2b30", "#4a4a52", "#dfe3e8", "#f7f9fb", "#a3abb5", "#b9c6d6", "#8fb3e0", "#6d93c4", "#ab4c55", "#6b2c33", "#3e5c9e", "#7f9fd6", "#8ccf7a", "#4f8a46", "#e9b45f", "#a8762f",
    ], [
        "#1d2127", "#d9707a", "#7fbf72", "#d4a44f", "#6f9bd8", "#b894d6", "#5fb8c4", "#dfe3e8", "#a3abb5", "#ee8f98", "#8ccf7a", "#e9b45f", "#8fb3ee", "#d0aef0", "#86d3de", "#f7f9fb",
    ])

    /// In menu order.
    public static let all: [Theme] = [plumNight, moss, tide, ember, slate]

    /// The theme with this name; nil or an unknown name gives Plum Night.
    public static func named(_ name: String?) -> Theme { all.first { $0.id == name } ?? plumNight }
}

/// WCAG 2 contrast ratio between two `#rrggbb` colours.
public func contrastRatio(_ a: String, _ b: String) -> Double {
    func lum(_ hex: String) -> Double {
        let c = (0..<3).map { i -> Double in
            let v = Double(Int(hex.dropFirst(1 + 2 * i).prefix(2), radix: 16) ?? 0) / 255
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
    }
    let (la, lb) = (lum(a), lum(b))
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
}

/// The kitty colour lines for a theme: ground and text from the palette, the 16 ANSI colours from the theme.
public func kittyColorsConf(_ t: Theme) -> String {
    let p = t.palette
    let base = ["background": p["plum-900"]!, "foreground": p["cream"]!, "cursor": p["pink-400"]!,
                "selection_background": p["plum-700"]!, "selection_foreground": p["cream"]!]
    return (["background", "foreground", "cursor", "selection_background", "selection_foreground"].map { "\($0) \(base[$0]!)" }
            + t.ansi.enumerated().map { "color\($0.offset) \($0.element)" }).joined(separator: "\n") + "\n"
}
