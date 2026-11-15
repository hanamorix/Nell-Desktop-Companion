import AppKit
import NellCore

if Showcase.requested(CommandLine.arguments) == .some("list") {
    print((Showcase.scenes + Showcase.stressScenes).map(\.name).joined(separator: "\n"))
    exit(0)
}
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = MainActor.assumeIsolated { AppDelegate() }
app.delegate = delegate
app.run()
