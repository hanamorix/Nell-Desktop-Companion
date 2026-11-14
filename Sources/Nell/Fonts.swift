import AppKit
import CoreText
import SwiftUI

/// Departure Mono (SIL OFL): registered privately for Nell's own text, and installed per user so kitty can load it.
enum Fonts {
    static let family = "Departure Mono"
    static let file = "DepartureMono-Regular.otf"
    private static var source: URL { resourceURL("fonts/" + file) }

    static func register() {
        CTFontManagerRegisterFontsForURL(source as CFURL, .process, nil)
    }

    /// Copies the font into ~/Library/Fonts once (approved by the user). kitty only sees installed fonts.
    @discardableResult
    static func installForKitty() -> Bool {
        let dest = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Fonts/" + file)
        guard !FileManager.default.fileExists(atPath: dest.path) else { return true }
        return (try? FileManager.default.copyItem(at: source, to: dest)) != nil
    }

    /// 11 pt is Departure Mono's pixel grid at 2×; keep sizes on that grid so it stays crisp.
    static func ui(_ size: CGFloat = 11) -> Font { .custom(family, fixedSize: size) }
}
