import Foundation

/// Days of the week, numbered the way `Calendar` numbers them (Sunday = 1).
public enum Weekday: Int, Codable, Sendable, CaseIterable, Comparable, Identifiable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    public var id: Int { rawValue }

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// A repeating schedule for an event or chore.
///
/// Mirrors the subset of RFC 5545 that families actually use:
/// every N days/weeks/months/years, specific weekdays, "the 2nd Tuesday",
/// and an end after a count or on a date.
public struct RecurrenceRule: Codable, Hashable, Sendable {
    public enum Frequency: String, Codable, Sendable, CaseIterable {
        case daily, weekly, monthly, yearly
    }

    public var frequency: Frequency
    /// Repeat every `interval` units of `frequency`. Always at least 1.
    public var interval: Int
    /// Weekly: the days it repeats on (defaults to the start's weekday).
    /// Monthly with `monthlyOrdinal`: the weekday to use.
    public var weekdays: [Weekday]
    /// Monthly only: 1...4 for "first…fourth", -1 for "last". Requires one weekday.
    public var monthlyOrdinal: Int?
    /// Stop after this many occurrences (counted from the series start).
    public var count: Int?
    /// Last day an occurrence may start on (inclusive, whole day).
    public var until: Date?

    public init(
        frequency: Frequency,
        interval: Int = 1,
        weekdays: [Weekday] = [],
        monthlyOrdinal: Int? = nil,
        count: Int? = nil,
        until: Date? = nil
    ) {
        self.frequency = frequency
        self.interval = max(1, interval)
        self.weekdays = weekdays.sorted()
        self.monthlyOrdinal = monthlyOrdinal
        self.count = count
        self.until = until
    }

    public static let daily = RecurrenceRule(frequency: .daily)
    public static func weekly(on days: [Weekday], every interval: Int = 1) -> RecurrenceRule {
        RecurrenceRule(frequency: .weekly, interval: interval, weekdays: days)
    }

    public func encoded() -> Data? { try? JSONEncoder().encode(self) }

    public static func decode(_ data: Data?) -> RecurrenceRule? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(RecurrenceRule.self, from: data)
    }
}

/// Expands recurrence rules into concrete occurrence start dates.
///
/// All date math goes through `Calendar` so wall-clock times stay put across
/// daylight-saving changes (soccer at 5 PM stays at 5 PM).
public struct RecurrenceEngine: Sendable {
    public var calendar: Calendar

    /// Upper bound on generated candidates, as a guard against runaway rules.
    static let maxCandidates = 20_000

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// Start dates of every occurrence that overlaps `window`.
    ///
    /// - Parameters:
    ///   - rule: The rule, or `nil` for a one-off event.
    ///   - seriesStart: Start of the first occurrence.
    ///   - duration: Length of each occurrence, used for overlap tests.
    ///   - window: Half-open interval to collect occurrences for.
    ///   - excluding: Occurrence start dates to skip (cancelled exceptions).
    public func occurrences(
        of rule: RecurrenceRule?,
        seriesStart: Date,
        duration: TimeInterval,
        overlapping window: DateInterval,
        excluding: Set<Date> = []
    ) -> [Date] {
        var result: [Date] = []
        forEachCandidate(of: rule, seriesStart: seriesStart) { start in
            if start >= window.end { return false }
            let overlaps = duration > 0
                ? start.addingTimeInterval(duration) > window.start
                : start >= window.start
            if overlaps && !excluding.contains(start) {
                result.append(start)
            }
            return true
        }
        return result
    }

    /// The first occurrence starting at or after `date`, if any.
    public func nextOccurrence(
        of rule: RecurrenceRule?,
        seriesStart: Date,
        onOrAfter date: Date,
        excluding: Set<Date> = []
    ) -> Date? {
        var found: Date?
        forEachCandidate(of: rule, seriesStart: seriesStart) { start in
            if start >= date && !excluding.contains(start) {
                found = start
                return false
            }
            return true
        }
        return found
    }

    /// Walks occurrences in order, honoring `count` and `until`, until `body` returns false.
    func forEachCandidate(
        of rule: RecurrenceRule?,
        seriesStart: Date,
        _ body: (Date) -> Bool
    ) {
        guard let rule else {
            _ = body(seriesStart)
            return
        }
        let lastAllowed = rule.until.flatMap { endOfDay($0) }
        var emitted = 0
        var period = 0
        var candidates = 0

        while candidates < Self.maxCandidates {
            let starts = startsInPeriod(period, of: rule, seriesStart: seriesStart)
            period += 1
            candidates += max(1, starts.count)
            for start in starts where start >= seriesStart {
                if let lastAllowed, start >= lastAllowed { return }
                if let count = rule.count, emitted >= count { return }
                emitted += 1
                if !body(start) { return }
            }
            if let lastAllowed, periodStart(period, of: rule, seriesStart: seriesStart).map({ $0 >= lastAllowed }) == true {
                return
            }
        }
    }

    // MARK: - Period expansion

    private func timeOfDay(_ date: Date) -> DateComponents {
        calendar.dateComponents([.hour, .minute, .second], from: date)
    }

    private func endOfDay(_ date: Date) -> Date? {
        calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))
    }

    /// Builds a date on the given day keeping the series' wall-clock time.
    private func date(onDayOf day: Date, at time: DateComponents) -> Date? {
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = time.hour
        components.minute = time.minute
        components.second = time.second
        return calendar.date(from: components)
    }

    private func periodStart(_ period: Int, of rule: RecurrenceRule, seriesStart: Date) -> Date? {
        let step = period * rule.interval
        switch rule.frequency {
        case .daily:
            return calendar.date(byAdding: .day, value: step, to: calendar.startOfDay(for: seriesStart))
        case .weekly:
            guard let week = calendar.dateInterval(of: .weekOfYear, for: seriesStart)?.start else { return nil }
            return calendar.date(byAdding: .weekOfYear, value: step, to: week)
        case .monthly:
            guard let month = calendar.dateInterval(of: .month, for: seriesStart)?.start else { return nil }
            return calendar.date(byAdding: .month, value: step, to: month)
        case .yearly:
            guard let year = calendar.dateInterval(of: .year, for: seriesStart)?.start else { return nil }
            return calendar.date(byAdding: .year, value: step, to: year)
        }
    }

    private func startsInPeriod(_ period: Int, of rule: RecurrenceRule, seriesStart: Date) -> [Date] {
        let time = timeOfDay(seriesStart)
        let step = period * rule.interval

        switch rule.frequency {
        case .daily:
            guard let day = calendar.date(byAdding: .day, value: step, to: calendar.startOfDay(for: seriesStart)) else { return [] }
            return date(onDayOf: day, at: time).map { [$0] } ?? []

        case .weekly:
            guard let weekStart = periodStart(period, of: rule, seriesStart: seriesStart) else { return [] }
            let startWeekday = calendar.component(.weekday, from: seriesStart)
            let days = rule.weekdays.isEmpty
                ? [Weekday(rawValue: startWeekday) ?? .sunday]
                : rule.weekdays
            let firstWeekday = calendar.component(.weekday, from: weekStart)
            return days
                .map { ($0.rawValue - firstWeekday + 7) % 7 }
                .sorted()
                .compactMap { offset in
                    calendar.date(byAdding: .day, value: offset, to: weekStart)
                        .flatMap { date(onDayOf: $0, at: time) }
                }

        case .monthly:
            guard let monthStart = periodStart(period, of: rule, seriesStart: seriesStart) else { return [] }
            if let ordinal = rule.monthlyOrdinal, let weekday = rule.weekdays.first {
                return nthWeekday(ordinal, weekday, inMonthStarting: monthStart)
                    .flatMap { date(onDayOf: $0, at: time) }
                    .map { [$0] } ?? []
            }
            let dayOfMonth = calendar.component(.day, from: seriesStart)
            return day(dayOfMonth, inPeriodStarting: monthStart, unit: .month)
                .flatMap { date(onDayOf: $0, at: time) }
                .map { [$0] } ?? []

        case .yearly:
            let month = calendar.component(.month, from: seriesStart)
            let dayOfMonth = calendar.component(.day, from: seriesStart)
            let year = calendar.component(.year, from: seriesStart) + step
            guard let monthStart = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
                  let day = day(dayOfMonth, inPeriodStarting: monthStart, unit: .month)
            else { return [] }
            return date(onDayOf: day, at: time).map { [$0] } ?? []
        }
    }

    /// The given day number inside a month, or nil when the month is too short
    /// (a series on the 31st skips 30-day months, like Calendar does).
    private func day(_ number: Int, inPeriodStarting start: Date, unit: Calendar.Component) -> Date? {
        guard let range = calendar.range(of: .day, in: unit, for: start), range.contains(number) else { return nil }
        return calendar.date(byAdding: .day, value: number - 1, to: start)
    }

    private func nthWeekday(_ ordinal: Int, _ weekday: Weekday, inMonthStarting monthStart: Date) -> Date? {
        guard let days = calendar.range(of: .day, in: .month, for: monthStart) else { return nil }
        let matches = days.compactMap { day -> Date? in
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) else { return nil }
            return calendar.component(.weekday, from: date) == weekday.rawValue ? date : nil
        }
        if ordinal == -1 { return matches.last }
        guard ordinal >= 1, ordinal <= matches.count else { return nil }
        return matches[ordinal - 1]
    }
}
