import Foundation
import FamilyCore

/// One concrete appearance of an event on the calendar, with any
/// single-occurrence edits applied.
public struct EventOccurrence: Identifiable {
    public let event: Event
    /// Original start of this occurrence in the series. Claims and exceptions key on this.
    public let occurrenceDate: Date
    public let start: Date
    public let end: Date
    public let title: String
    public let locationName: String?

    public init(event: Event, occurrenceDate: Date, start: Date, end: Date, title: String, locationName: String?) {
        self.event = event
        self.occurrenceDate = occurrenceDate
        self.start = start
        self.end = end
        self.title = title
        self.locationName = locationName
    }

    public var id: String { "\(event.id.uuidString)|\(occurrenceDate.timeIntervalSinceReferenceDate)" }
    public var isAllDay: Bool { event.isAllDay }
}

public enum OccurrenceExpander {
    /// Expands `events` into occurrences overlapping `window`, sorted by start.
    public static func occurrences(
        of events: [Event],
        exceptions: [EventException],
        in window: DateInterval,
        calendar: Calendar = .current
    ) -> [EventOccurrence] {
        let engine = RecurrenceEngine(calendar: calendar)
        let exceptionsByEvent = Dictionary(grouping: exceptions, by: \.eventID)
        var result: [EventOccurrence] = []

        for event in events {
            let eventExceptions = exceptionsByEvent[event.id] ?? []
            let byDate = Dictionary(eventExceptions.map { ($0.occurrenceDate, $0) }, uniquingKeysWith: { first, _ in first })
            let cancelled = Set(eventExceptions.filter(\.isCancelled).map(\.occurrenceDate))

            // Widen the search so occurrences moved into the window by an exception are found.
            let searchWindow = DateInterval(
                start: window.start.addingTimeInterval(-7 * 86_400),
                end: window.end.addingTimeInterval(7 * 86_400)
            )
            let starts = engine.occurrences(
                of: event.recurrence,
                seriesStart: event.start,
                duration: event.duration,
                overlapping: searchWindow,
                excluding: cancelled
            )
            for original in starts {
                let exception = byDate[original]
                let start = exception?.overrideStart ?? original
                let end = exception?.overrideEnd ?? start.addingTimeInterval(event.duration)
                guard start < window.end, end > window.start || (start == end && start >= window.start) else { continue }
                result.append(EventOccurrence(
                    event: event,
                    occurrenceDate: original,
                    start: start,
                    end: end,
                    title: exception?.overrideTitle ?? event.title,
                    locationName: exception?.overrideLocationName ?? event.locationName
                ))
            }
        }
        return result.sorted { ($0.isAllDay ? 0 : 1, $0.start, $0.title) < ($1.isAllDay ? 0 : 1, $1.start, $1.title) }
    }

    public static func day(containing date: Date, calendar: Calendar = .current) -> DateInterval {
        calendar.dateInterval(of: .day, for: date) ?? DateInterval(start: date, duration: 86_400)
    }
}
