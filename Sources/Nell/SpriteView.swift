import AppKit
import NellCore
import SwiftUI

/// Plays the frames for `state`, waking only when the frame changes. Placeholder art gets a state caption.
struct SpriteView: View {
    let state: NellState
    let sheet: SpriteSheet
    let image: CGImage
    let paused: Bool
    let width: CGFloat

    @StateObject private var ticker = FrameTicker()
    private var index: Int { ticker.index }

    var body: some View {
        let frames = sheet.frames(for: state)
        let f = frames[min(index, frames.count - 1)]
        Image(decorative: image.cropping(to: f.rect) ?? image, scale: 1)
            .resizable()
            .interpolation(sheet.isPlaceholder ? .medium : .none)
            .frame(width: width, height: width * f.rect.height / f.rect.width)
            .clipShape(RoundedRectangle(cornerRadius: sheet.isPlaceholder ? 14 : 0))
            .overlay(alignment: .bottom) {
                if sheet.isPlaceholder {
                    Text(state.rawValue)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(.black.opacity(0.65), in: Capsule())
                        .padding(.bottom, 6)
                }
            }
            .accessibilityLabel("Nell, \(state.rawValue)")
            .task(id: "\(state.rawValue)-\(paused)") {
                ticker.index = 0
                guard !paused, frames.count > 1 else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(frames[index].duration))
                    ticker.index = (ticker.index + 1) % frames.count
                }
            }
    }
}

/// SwiftUI's @State is a macro the Command Line Tools can't expand, so view state lives in small ObservableObjects.
@MainActor final class FrameTicker: ObservableObject { @Published var index = 0 }

func loadSprites() -> (SpriteSheet, CGImage)? {
    guard let json = try? Data(contentsOf: resourceURL("sprites/nell.json")),
          let sheet = try? SpriteSheet.parse(json),
          let img = NSImage(contentsOf: resourceURL("sprites/nell.png"))?.cgImage(forProposedRect: nil, context: nil, hints: nil)
    else { return nil }
    return (sheet, img)
}
