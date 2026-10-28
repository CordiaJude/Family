import Foundation

/// Builds the one-sentence summary at the top of Today, e.g.
/// "Busy afternoon: 4 events, 1 ride still needs a driver."
public struct DaySummary: Sendable {
    public enum PartOfDay: Sendable, Equatable {
        case morning, afternoon, evening

        public init(hour: Int) {
            switch hour {
            case ..<12: self = .morning
            case ..<17: self = .afternoon
            default: self = .evening
            }
        }

        var name: String {
            switch self {
            case .morning: String(localized: "morning")
            case .afternoon: String(localized: "afternoon")
            case .evening: String(localized: "evening")
            }
        }
    }

    /// Start times of today's timed (not all-day) events.
    public var timedStarts: [Date]
    public var allDayCount: Int
    /// Ride legs today that are needed but unclaimed.
    public var unclaimedRides: Int
    /// Ride legs today in total.
    public var totalRides: Int
    public var calendar: Calendar

    /// Days with at least this many events are called busy.
    static let busyThreshold = 4

    public init(timedStarts: [Date], allDayCount: Int = 0, unclaimedRides: Int, totalRides: Int, calendar: Calendar = .current) {
        self.timedStarts = timedStarts
        self.allDayCount = allDayCount
        self.unclaimedRides = unclaimedRides
        self.totalRides = totalRides
        self.calendar = calendar
    }

    public var eventCount: Int { timedStarts.count + allDayCount }

    /// The part of the day with the most timed events (earliest wins ties).
    public var busiestPart: PartOfDay? {
        let parts = timedStarts.map { PartOfDay(hour: calendar.component(.hour, from: $0)) }
        let order: [PartOfDay] = [.morning, .afternoon, .evening]
        return order
            .map { part in (part, parts.filter { $0 == part }.count) }
            .filter { $0.1 > 0 }
            .max { $0.1 < $1.1 }?.0
    }

    public var sentence: String {
        guard eventCount > 0 else {
            return String(localized: "Nothing on the family calendar today.")
        }
        let events = eventCount == 1
            ? String(localized: "1 event")
            : String(localized: "\(eventCount) events")

        let opener: String
        if eventCount >= Self.busyThreshold, let part = busiestPart {
            opener = String(localized: "Busy \(part.name)")
        } else if eventCount >= Self.busyThreshold {
            opener = String(localized: "Busy day")
        } else {
            opener = String(localized: "Easy day")
        }

        let rides: String?
        switch (unclaimedRides, totalRides) {
        case (0, 0): rides = nil
        case (0, _): rides = String(localized: "every ride is covered")
        case (1, _): rides = String(localized: "1 ride still needs a driver")
        default: rides = String(localized: "\(unclaimedRides) rides still need a driver")
        }

        if let rides {
            return String(localized: "\(opener): \(events), \(rides).")
        }
        return String(localized: "\(opener): \(events).")
    }
}
