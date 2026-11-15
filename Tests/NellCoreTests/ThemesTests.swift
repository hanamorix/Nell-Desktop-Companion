import Foundation
import Testing
@testable import NellCore

private func isHex(_ s: String) -> Bool { s.range(of: "^#[0-9a-f]{6}$", options: .regularExpression) != nil }

private func hue(_ hex: String) -> Double {
    let v = (0..<3).map { Double(Int(hex.dropFirst(1 + 2 * $0).prefix(2), radix: 16)!) / 255 }
    let (r, g, b) = (v[0], v[1], v[2])
    let mx = max(r, g, b), d = mx - min(r, g, b)
    if d == 0 { return 0 }
    let h = mx == r ? (g - b) / d : mx == g ? 2 + (b - r) / d : 4 + (r - g) / d
    return (h * 60 + 360).truncatingRemainder(dividingBy: 360)
}

@Test func themesAreTheFiveInOrder() {
    #expect(Themes.all.map(\.id) == ["Plum Night", "Moss", "Tide", "Ember", "Slate"])
}

@Test func everyThemeHasTheFullPalette() {
    for t in Themes.all {
        #expect(Set(t.palette.keys) == Set(PlumNight.palette.keys), "\(t.id) keys")
        #expect(t.palette.values.allSatisfy(isHex), "\(t.id) palette format")
        #expect(t.ansi.count == 16 && t.ansi.allSatisfy(isHex), "\(t.id) ansi")
    }
}

@Test func plumNightIsTheTokens() {
    #expect(Themes.plumNight.palette == PlumNight.palette)
}

/// Today's Plum Night console colours, captured verbatim from kitty.conf before the colours moved into kittyColorsConf.
@Test func plumNightKittyConfUnchanged() {
    let original = """
    background #1a1214
    foreground #f5d4c9
    cursor #ec9394
    selection_background #3f3039
    selection_foreground #f5d4c9
    color0  #261a22
    color1  #cf7d8b
    color2  #4f8a46
    color3  #a8762f
    color4  #6f8fd0
    color5  #f4b6ac
    color6  #6f8fd0
    color7  #f5d4c9
    color8  #c4a9ab
    color9  #ec9394
    color10 #8ccf7a
    color11 #e9b45f
    color12 #6f8fd0
    color13 #f4b6ac
    color14 #6f8fd0
    color15 #fff4ec
    """
    let norm = { (s: String) in s.split(separator: "\n").map { $0.split(separator: " ").joined(separator: " ") } }
    #expect(norm(kittyColorsConf(Themes.plumNight)) == norm(original))
}

@Test func kittyConfUsesTheme() throws {
    let t = Themes.named("Tide")
    let lines = kittyColorsConf(t).split(separator: "\n").map(String.init)
    for l in ["background #0f1622", "foreground #d6e4f0", "cursor #5cc8c0", "selection_background #263650", "selection_foreground #d6e4f0"] {
        #expect(lines.contains(l), "\(l)")
    }
    for i in 0..<16 { #expect(lines.contains { $0.split(separator: " ").map(String.init) == ["color\(i)", t.ansi[i]] }, "color\(i)") }
}

@Test func everyThemeIsAsReadableAsPlumNight() {
    let pairs = [("cream", "plum-800"), ("muted", "plum-800"), ("muted", "plum-900"),
                 ("outline", "leaf"), ("outline", "gold"), ("snow", "berry"), ("plum-500", "plum-800")]
    let plum = Themes.plumNight.palette
    for t in Themes.all {
        for (a, b) in pairs {
            let need = min(4.5, contrastRatio(plum[a]!, plum[b]!))
            #expect(contrastRatio(t.palette[a]!, t.palette[b]!) >= need, "\(t.id) \(a)/\(b)")
        }
    }
}

@Test func consoleColoursAreReadableOnTheWell() {
    for t in Themes.all {
        for i in [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15] {
            // Plum Night's 16 are kept exactly as the user's kitty.conf had them, so it is exempt from the 4.5 bar.
            #expect(contrastRatio(t.ansi[i], t.palette["plum-900"]!) >= 4.5 || t.id == "Plum Night", "\(t.id) color\(i)")
        }
    }
}

@Test func meaningColoursKeepTheirHue() {
    for t in Themes.all {
        let leaf = hue(t.palette["leaf"]!), gold = hue(t.palette["gold"]!), berry = hue(t.palette["berry"]!)
        #expect((75...150).contains(leaf), "\(t.id) leaf \(leaf)")
        #expect((30...60).contains(gold), "\(t.id) gold \(gold)")
        #expect(berry >= 340 || berry <= 20, "\(t.id) berry \(berry)")
    }
}

@Test func contrastRatioKnownValues() {
    #expect(abs(contrastRatio("#000000", "#ffffff") - 21) < 0.01)
    #expect(abs(contrastRatio("#ec9394", "#ec9394") - 1) < 1e-9)
}

@Test func themesNamedFallsBack() {
    for n in [nil, "Neon", ""] as [String?] { #expect(Themes.named(n) == Themes.plumNight) }
    #expect(Themes.named("Tide").id == "Tide")
}

@Test func berryHighlightFollowsTheThemesBerry() {
    #expect(Themes.plumNight.berryHi == "#cf7d8b")
    #expect(Themes.plumNight.failedInk == PlumNight.palette["blush"])
    #expect(Themes.tide.berryHi == "#d5a4ac") // berry #ac4a5a halfway to white
    for t in Themes.all where t.id != "Plum Night" {
        let h = hue(t.berryHi)
        #expect(h >= 340 || h <= 20, "\(t.id) berryHi hue \(h)")
        #expect(t.failedInk == t.berryHi)
    }
}

@Test func failedLabelIsReadableOnWine() {
    for t in Themes.all {
        #expect(contrastRatio(t.failedInk, t.palette["wine"]!) >= 4.5, "\(t.id) FAILED/wine")
    }
}
