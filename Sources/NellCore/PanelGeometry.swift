import CoreGraphics

/// How kitty's panel differs from what it's asked for. Measured once at runtime; `spike` holds the 2026-11-14 values.
public struct PanelCalibration: Equatable, Codable, Sendable {
    public var extraSize: CGSize
    public var topOffset: CGFloat
    public init(extraSize: CGSize, topOffset: CGFloat) { self.extraSize = extraSize; self.topOffset = topOffset }

    public static let spike = PanelCalibration(extraSize: CGSize(width: 56, height: 56), topOffset: 37)

    /// Both rects in top-left coordinates: `requested` is (margin-left, margin-top, columns px, lines px).
    public static func measured(requested: CGRect, actual: CGRect) -> PanelCalibration {
        PanelCalibration(extraSize: CGSize(width: actual.width - requested.width, height: actual.height - requested.height),
                         topOffset: actual.minY - requested.minY)
    }
}

public struct PanelRequest: Equatable, Sendable {
    public var marginLeft: Int, marginTop: Int, widthPx: Int, heightPx: Int
    public init(marginLeft: Int, marginTop: Int, widthPx: Int, heightPx: Int) {
        self.marginLeft = marginLeft; self.marginTop = marginTop; self.widthPx = widthPx; self.heightPx = heightPx
    }
}

/// What to ask kitty for so its panel lands exactly on `content` (AppKit coords) on `display` (its full frame).
public func panelRequest(content: CGRect, display: CGRect, cal: PanelCalibration) -> PanelRequest {
    PanelRequest(marginLeft: Int((content.minX - display.minX).rounded()),
                 marginTop: Int((display.maxY - content.maxY - cal.topOffset).rounded()),
                 widthPx: Int(max(1, content.width - cal.extraSize.width).rounded()),
                 heightPx: Int(max(1, content.height - cal.extraSize.height).rounded()))
}
