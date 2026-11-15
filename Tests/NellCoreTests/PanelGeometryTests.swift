import CoreGraphics
import Foundation
import Testing
@testable import NellCore

// Spike, 2026-11-14: asked 700×420 at margins (300, 350) → kitty drew 756×476 at (300, 387) from the top of a 1169 pt display.
let display = CGRect(x: 0, y: 0, width: 1800, height: 1169)

@Test func calibrationRoundTripsSpikeNumbers() {
    let cal = PanelCalibration.measured(requested: CGRect(x: 300, y: 350, width: 700, height: 420),
                                        actual: CGRect(x: 300, y: 387, width: 756, height: 476))
    #expect(cal == PanelCalibration(extraSize: CGSize(width: 56, height: 56), topOffset: 37))
    #expect(cal == PanelCalibration.spike)
    // the content rect kitty should end up covering, in AppKit coords (y up)
    let content = CGRect(x: 300, y: 1169 - 387 - 476, width: 756, height: 476)
    #expect(panelRequest(content: content, display: display, cal: cal) == PanelRequest(marginLeft: 300, marginTop: 350, widthPx: 700, heightPx: 420))
}

@Test func calibrationIsCodable() throws {
    let data = try JSONEncoder().encode(PanelCalibration.spike)
    #expect(try JSONDecoder().decode(PanelCalibration.self, from: data) == .spike)
}

@Test func launchPanelArgsMatchGlobalConstraints() {
    let p = Paths(support: URL(fileURLWithPath: "/A/Nell"))
    let a = KittyCommands.launchPanel(paths: p, request: PanelRequest(marginLeft: 10, marginTop: 20, widthPx: 700, heightPx: 420),
                                      cwd: "/p q", shell: "/bin/zsh", claude: "/c/claude", args: ["--resume", "S"])
    #expect(a.first == KittyCommands.kitten)
    #expect(Array(a.dropFirst().prefix(1)) == ["panel"])
    let joined = a.joined(separator: " ")
    for part in ["--edge none", "--margin-left 10", "--margin-top 20", "--columns 700px", "--lines 420px", "--layer overlay",
                 "-o macos_ns_window_layer=NSScreenSaverWindowLevel", "--focus-policy on-demand", "--start-as-hidden",
                 "-c /A/Nell/kitty.conf", "-o allow_remote_control=socket-only", "-o tab_bar_style=hidden", "-o env=NELL_MODE=code",
                 "--listen-on unix:/A/Nell/kitty-{kitty_pid}.sock"] {
        #expect(joined.contains(part), "\(part)")
    }
    // Claude runs as the last act of your interactive login shell, in its folder, so it gets your terminal's environment
    #expect(Array(a.suffix(9)) == ["/bin/zsh", "-l", "-i", "-c", #"cd -- "$0"; export SHLVL=$((SHLVL+1)); exec "$@""#, "/p q", "/c/claude", "--resume", "S"])
    #expect(!a.contains("--session"))
}

@Test func placePanelUsesIncrementalOsPanel() {
    let a = KittyCommands.placePanel(socket: "unix:/s", request: PanelRequest(marginLeft: 1, marginTop: 2, widthPx: 3, heightPx: 4))
    #expect(Array(a.dropFirst()) == ["@", "--to", "unix:/s", "resize-os-window", "--action", "os-panel", "--incremental",
                                     "margin-left=1", "margin-top=2", "columns=3px", "lines=4px"])
}

@Test func tabAndVisibilityCommands() {
    #expect(Array(KittyCommands.launchTab(socket: "unix:/s", mode: .chat, cwd: "/c d", shell: "/bin/bash", claude: "/cl", args: ["-x"]).dropFirst())
            == ["@", "--to", "unix:/s", "launch", "--type=tab", "--keep-focus", "--var", "nell_mode=chat", "--env", "NELL_MODE=chat", "--cwd", "/c d",
                "/bin/bash", "-l", "-i", "-c", #"cd -- "$0"; eval "${PROMPT_COMMAND:-}"; export SHLVL=$((SHLVL+1)); exec "$@""#, "/c d", "/cl", "-x"])
    #expect(KittyCommands.showPanel(socket: "unix:/s").suffix(2) == ["--action", "show"])
    #expect(KittyCommands.hidePanel(socket: "unix:/s").suffix(2) == ["--action", "hide"])
    #expect(KittyCommands.focusTab(socket: "unix:/s", mode: .chat).suffix(3) == ["focus-tab", "--match", "var:nell_mode=chat"])
    #expect(KittyCommands.closeTab(socket: "unix:/s", mode: .code).suffix(3) == ["close-tab", "--match", "var:nell_mode=code"])
}
