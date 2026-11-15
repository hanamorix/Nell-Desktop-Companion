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

@Test func plumNightConsoleMatchesKittyConf() throws {
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appending(path: "../../Sources/Nell/Resources/kitty.conf")
    var found: [Int: String] = [:]
    for line in try String(contentsOf: url, encoding: .utf8).split(separator: "\n") {
        let p = line.split(separator: " ", omittingEmptySubsequences: true)
        if p.count == 2, p[0].hasPrefix("color"), let n = Int(p[0].dropFirst(5)) { found[n] = String(p[1]) }
    }
    #expect(found.count == 16)
    #expect(Themes.plumNight.ansi == (0..<16).map { found[$0] })
}

@Test func everyThemeIsAsReadableAsPlumNight() {
    let pairs = [("cream", "plum-800"), ("muted", "plum-800"), ("muted", "plum-900"),
                 ("outline", "leaf"), ("outline", "gold"), ("snow", "berry")]
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
