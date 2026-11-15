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
