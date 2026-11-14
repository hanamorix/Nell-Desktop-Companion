import AppKit
import NellCore
import SwiftUI

// Task 7 demo entry: `swift run Nell --demo` cycles states every 2 s. Task 9 replaces this with AppDelegate.
@MainActor final class DemoModel: ObservableObject { @Published var state: NellState = .idle }

struct DemoRoot: View {
    @ObservedObject var model: DemoModel
    let sheet: SpriteSheet; let image: CGImage; let controller: PanelController
    var body: some View {
        VStack { Spacer()
            SpriteView(state: model.state, sheet: sheet, image: image, paused: false, width: 150)
                .interactive()
                .gesture(DragGesture(minimumDistance: 2).onChanged { _ in controller.dragChanged() }.onEnded { _ in controller.dragEnded() })
                .contextMenu { Button("Quit") { NSApp.terminate(nil) } }
        }
        .frame(width: 320, height: 520)
        .onPreferenceChange(InteractiveRectsKey.self) { r in MainActor.assumeIsolated { controller.rects = r } }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
guard let (sheet, image) = loadSprites() else { fatalError("missing sprites") }
let panel = OverlayPanel(size: NSSize(width: 320, height: 520))
let controller = PanelController(panel: panel)
let model = DemoModel()
panel.contentView = NSHostingView(rootView: DemoRoot(model: model, sheet: sheet, image: image, controller: controller))
controller.restore(positions: [:])
controller.startClickThrough()
panel.orderFrontRegardless()
if CommandLine.arguments.contains("--demo") {
    var i = 0
    Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
        MainActor.assumeIsolated { i += 1; model.state = NellState.allCases[i % NellState.allCases.count] }
    }
}
app.run()
