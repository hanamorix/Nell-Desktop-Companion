import CoreGraphics
import Foundation

public struct SavedState: Codable, Equatable, Sendable {
    public var projectDir: String?
    public var codeSessionId: String?
    public var chatSessionId: String?
    /// Panel origin per display (CGDirectDisplayID as a string).
    public var positions: [String: CGPoint] = [:]
    /// kitty's measured panel offsets (nil until the console has been shown once).
    public var calibration: PanelCalibration?
    /// Colour theme name; nil or unknown means Plum Night (see `Themes.named`).
    public var theme: String?

    public init() {}

    public static func load(_ url: URL) -> SavedState {
        guard let d = try? Data(contentsOf: url), let s = try? JSONDecoder().decode(SavedState.self, from: d) else { return SavedState() }
        return s
    }

    public func save(_ url: URL) throws {
        try JSONEncoder().encode(self).write(to: url, options: .atomic)
    }
}
