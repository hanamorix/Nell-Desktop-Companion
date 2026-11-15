import CoreGraphics

/// Which bubbles the column shows, by height: every pinned one (a pending approval or question must stay on screen),
/// then the newest others while they fit, stopping at the first that doesn't. `heights` and `pinned` are oldest first.
/// The newest bubble always shows if nothing else does, so the column is never empty with a bubble live.
public func fitRows(heights: [CGFloat], pinned: [Bool], budget: CGFloat, spacing: CGFloat) -> [Bool] {
    var fit = pinned
    var used = zip(heights, pinned).filter(\.1).map(\.0).reduce(0, +) + spacing * CGFloat(max(0, pinned.filter { $0 }.count - 1))
    for i in heights.indices.reversed() where !pinned[i] {
        let any = fit.contains(true), add = heights[i] + (any ? spacing : 0)
        guard !any || used + add <= budget else { break }
        used += add; fit[i] = true
    }
    return fit
}
