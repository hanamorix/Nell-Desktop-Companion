import Foundation

public enum UsageKind: Sendable, Hashable {
    case session, weekly
    public var label: String { self == .session ? "5H" : "7D" }
    public var title: String { self == .session ? "Session" : "Weekly" }
}

public enum UsageLevel: Sendable, Hashable { case none, low, mid, high }

public struct UsageWindow: Equatable, Sendable {
    public var used: Double  // percent, 0-100
    public var resetsAt: Date?
    public init(used: Double, resetsAt: Date? = nil) { self.used = used; self.resetsAt = resetsAt }

    func resetPassed(_ now: Date) -> Bool { resetsAt.map { $0 <= now } ?? false }
}

public struct UsageReading: Equatable, Sendable {
    public var session: UsageWindow?
    public var weekly: UsageWindow?
    public init(session: UsageWindow? = nil, weekly: UsageWindow? = nil) { self.session = session; self.weekly = weekly }

    /// Reads `rate_limits` from Claude Code's status-line JSON; nil when neither window is there.
    public static func decode(_ data: Data) -> UsageReading? {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let limits = root["rate_limits"] as? [String: Any] else { return nil }
        func window(_ key: String) -> UsageWindow? {
            guard let w = limits[key] as? [String: Any], let used = (w["used_percentage"] as? NSNumber)?.doubleValue else { return nil }
            var reset: Date?
            if let n = w["resets_at"] as? NSNumber { reset = Date(timeIntervalSince1970: n.doubleValue) }
            else if let s = w["resets_at"] as? String { reset = ISO8601DateFormatter().date(from: s) }
            return UsageWindow(used: used, resetsAt: reset)
        }
        let r = UsageReading(session: window("five_hour"), weekly: window("seven_day"))
        return r.session == nil && r.weekly == nil ? nil : r
    }

    /// A newer reading wins per window, but never erases a window it lacks.
    public func merged(_ newer: UsageReading) -> UsageReading {
        UsageReading(session: newer.session ?? session, weekly: newer.weekly ?? weekly)
    }

    public func nextReset(after now: Date) -> Date? {
        [session?.resetsAt, weekly?.resetsAt].compactMap { $0 }.filter { $0 > now }.min()
    }
}

public struct UsageGauge: Equatable, Sendable {
    public var fraction: Double?
    public var level: UsageLevel
    public var tooltip: String
    public init(fraction: Double?, level: UsageLevel, tooltip: String) {
        self.fraction = fraction; self.level = level; self.tooltip = tooltip
    }
}

private func clock(_ date: Date, now: Date, _ tz: TimeZone) -> String {
    var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = tz
    f.dateFormat = cal.isDate(date, inSameDayAs: now) ? "h:mma" : "EEE h:mma"
    return f.string(from: date).replacingOccurrences(of: "AM", with: "am").replacingOccurrences(of: "PM", with: "pm")
}

public func gauge(_ w: UsageWindow?, _ kind: UsageKind, now: Date, timeZone: TimeZone = .current) -> UsageGauge {
    guard let w else { return UsageGauge(fraction: nil, level: .none, tooltip: "\(kind.title) · no reading yet") }
    if let r = w.resetsAt, r <= now {
        return UsageGauge(fraction: 0, level: .low, tooltip: "\(kind.title) 0% · reset at \(clock(r, now: now, timeZone))")
    }
    let level: UsageLevel = w.used < 50 ? .low : w.used <= 80 ? .mid : .high
    var tip = "\(kind.title) \(Int(w.used.rounded()))%"
    if let r = w.resetsAt { tip += " · resets \(clock(r, now: now, timeZone))" }
    return UsageGauge(fraction: min(max(w.used / 100, 0), 1), level: level, tooltip: tip)
}

public func tired(_ r: UsageReading?, now: Date) -> Bool {
    [r?.session, r?.weekly].contains { w in w.map { $0.used > 90 && !$0.resetPassed(now) } ?? false }
}

public func statusLineText(_ r: UsageReading?) -> String {
    [r?.session.map { "5h \(Int($0.used.rounded()))%" }, r?.weekly.map { "7d \(Int($0.used.rounded()))%" }]
        .compactMap { $0 }.joined(separator: " · ")
}
