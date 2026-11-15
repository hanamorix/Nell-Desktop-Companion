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

    /// Every key is optional, so a hand-edited file or one from an older or newer Nell keeps everything it does have.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        projectDir = try c.decodeIfPresent(String.self, forKey: .projectDir)
        codeSessionId = try c.decodeIfPresent(String.self, forKey: .codeSessionId)
        chatSessionId = try c.decodeIfPresent(String.self, forKey: .chatSessionId)
        positions = try c.decodeIfPresent([String: CGPoint].self, forKey: .positions) ?? [:]
        calibration = try c.decodeIfPresent(PanelCalibration.self, forKey: .calibration)
        theme = try c.decodeIfPresent(String.self, forKey: .theme)
    }

    /// `projectDir` while it's still a folder kitty can start in: it may have been moved, deleted, be on a drive not
    /// mounted yet, or be closed to Nell (permissions, or a macOS privacy denial), and then `Process.run` can't chdir there.
    public var usableProjectDir: String? {
        var isDir: ObjCBool = false
        let fm = FileManager.default
        guard let projectDir, fm.fileExists(atPath: projectDir, isDirectory: &isDir), isDir.boolValue,
              fm.isExecutableFile(atPath: projectDir), fm.isReadableFile(atPath: projectDir) else { return nil } // searchable, listable
        return projectDir
    }

    /// Whether a Code launch in `cwd` records its session id as the project's: only one in the saved project folder (or
    /// any, with none saved). Code that fell back to the chat folder must not stop the project's session resuming.
    public func ownsCodeSession(cwd: String) -> Bool { projectDir == nil || projectDir == cwd }

    public static func load(_ url: URL) -> SavedState {
        guard let d = try? Data(contentsOf: url), let s = try? JSONDecoder().decode(SavedState.self, from: d) else { return SavedState() }
        return s
    }

    public func save(_ url: URL) throws {
        try JSONEncoder().encode(self).write(to: url, options: .atomic)
    }
}
