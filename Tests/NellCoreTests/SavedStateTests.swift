import Foundation
import Testing
@testable import NellCore

@Test func savedStateRoundTrips() throws {
    let url = URL(fileURLWithPath: tmpSocket()).deletingLastPathComponent().appending(path: "state.json")
    var s = SavedState()
    s.projectDir = "/Users/x/My Proj"; s.codeSessionId = "c"; s.chatSessionId = "h"; s.positions["1"] = CGPoint(x: 10, y: 20)
    try s.save(url)
    #expect(SavedState.load(url) == s)
}

@Test func corruptStateFileLoadsDefault() throws {
    let url = URL(fileURLWithPath: tmpSocket()).deletingLastPathComponent().appending(path: "state.json")
    try Data("{nope".utf8).write(to: url)
    #expect(SavedState.load(url) == SavedState())
    #expect(SavedState.load(url.appending(path: "missing")) == SavedState())
}

@Test func savedStateRoundTripsCalibration() throws {
    let url = URL(fileURLWithPath: tmpSocket()).deletingLastPathComponent().appending(path: "state.json")
    var s = SavedState()
    s.calibration = PanelCalibration(extraSize: CGSize(width: 50, height: 52), topOffset: 39)
    try s.save(url)
    #expect(SavedState.load(url).calibration == s.calibration)
}

@Test func savedStateKeepsTheme() throws {
    let url = FileManager.default.temporaryDirectory.appending(path: "nell-theme-\(UUID().uuidString).json")
    var s = SavedState()
    s.theme = "Ember"
    try s.save(url)
    #expect(SavedState.load(url).theme == "Ember")
}

@Test func savedStateUnknownThemeFallsBack() throws {
    let url = FileManager.default.temporaryDirectory.appending(path: "nell-theme-\(UUID().uuidString).json")
    try Data(#"{"positions":{},"theme":"Neon"}"#.utf8).write(to: url)
    #expect(Themes.named(SavedState.load(url).theme) == Themes.plumNight)
}

@Test func savedStateWithoutThemeStillLoads() throws {
    let url = FileManager.default.temporaryDirectory.appending(path: "nell-theme-\(UUID().uuidString).json")
    try Data(#"{"projectDir":"/x","positions":{}}"#.utf8).write(to: url)
    let s = SavedState.load(url)
    #expect(s.projectDir == "/x" && s.theme == nil)
}

@Test func savedStateWithoutPositionsKeepsTheRest() throws {
    // synthesized Decodable required every non-optional key, so one missing field wiped project, sessions and theme
    let url = FileManager.default.temporaryDirectory.appending(path: "nell-state-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: url) }
    try Data(#"{"projectDir":"/x","codeSessionId":"c","chatSessionId":"h","theme":"Ink"}"#.utf8).write(to: url)
    let s = SavedState.load(url)
    #expect(s.projectDir == "/x" && s.codeSessionId == "c" && s.chatSessionId == "h" && s.theme == "Ink" && s.positions.isEmpty)
    try Data("{}".utf8).write(to: url)
    #expect(SavedState.load(url) == SavedState())
}

@Test func usableProjectDirIsAnExistingFolder() throws {
    let dir = FileManager.default.temporaryDirectory.appending(path: "nell-proj-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let file = dir.appending(path: "f.txt"); try Data().write(to: file)
    var s = SavedState()
    #expect(s.usableProjectDir == nil)
    s.projectDir = dir.path; #expect(s.usableProjectDir == dir.path)
    s.projectDir = file.path; #expect(s.usableProjectDir == nil)                     // a file, not a folder
    s.projectDir = dir.appending(path: "gone").path; #expect(s.usableProjectDir == nil) // moved or deleted
}
