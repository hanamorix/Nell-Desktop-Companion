import Foundation

public enum Timings {
    public static let typingWatchdog: TimeInterval = 180
    public static let hooksNotConnected: TimeInterval = 8
    public static let bubbleVisible: TimeInterval = 20
    public static let chatReplyVisible: TimeInterval = 60
    public static let bubbleFade: TimeInterval = 2
    public static let maxVisibleBubbles = 4
    public static let hookTimeout = 600
    /// No events for this long: breathing rests and blinks slow.
    public static let longQuiet: TimeInterval = 600
}
