import Foundation
import SwiftData
import Testing
import FamilyCore
@testable import FamilyData

@MainActor
@Suite("Sample household")
struct SampleHouseholdTests {
    let container = SampleHousehold.previewContainer()
    var context: ModelContext { container.mainContext }

    @Test func loadsTheParkers() throws {
        let households = try context.fetch(FetchDescriptor<Household>())
        #expect(households.map(\.name) == ["The Parkers"])
        let members = try context.fetch(FetchDescriptor<Member>(sortBy: [SortDescriptor(\.sortOrder)]))
        #expect(members.map(\.firstName) == ["Sam", "Alex", "Emma", "Liam", "Biscuit"])
        #expect(members.filter(\.canDrive).map(\.firstName) == ["Sam", "Alex"])
    }

    @Test func todayHasEventsAndAnUnclaimedRide() throws {
        let events = try context.fetch(FetchDescriptor<Event>())
        let exceptions = try context.fetch(FetchDescriptor<EventException>())
        let claims = try context.fetch(FetchDescriptor<RideClaim>())
        let today = OccurrenceExpander.occurrences(of: events, exceptions: exceptions, in: OccurrenceExpander.day(containing: .now))
        #expect(today.count >= 3)

        let unclaimed = today.flatMap { occurrence in
            occurrence.event.neededLegs.filter { leg in
                !claims.contains { $0.eventID == occurrence.event.id && $0.occurrenceDate == occurrence.occurrenceDate && $0.leg == leg }
            }
        }
        #expect(!unclaimed.isEmpty)
    }

    @Test func reloadingReplacesInsteadOfDuplicating() throws {
        SampleHousehold.load(into: context)
        #expect(try context.fetchCount(FetchDescriptor<Member>()) == 5)
        #expect(try context.fetchCount(FetchDescriptor<Household>()) == 1)
    }

    @Test func sampleDataStartsClean() throws {
        let items = try context.fetch(FetchDescriptor<ListItem>())
        #expect(items.allSatisfy { $0.dirtyFields.isEmpty })
    }
}

@MainActor
@Suite("Occurrence expansion")
struct OccurrenceExpanderTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }()

    func date(_ d: Int, _ h: Int, _ m: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: d, hour: h, minute: m))!
    }

    @Test func appliesExceptions() {
        let household = UUID()
        let soccer = Event(householdID: household, title: "Soccer", start: date(3, 17), end: date(3, 18, 30),
                           recurrence: .weekly(on: [.tuesday]))
        let moved = EventException(householdID: household, eventID: soccer.id, occurrenceDate: date(10, 17))
        moved.overrideStart = date(10, 16)
        moved.overrideEnd = date(10, 17)
        moved.overrideTitle = "Soccer (early)"
        let cancelled = EventException(householdID: household, eventID: soccer.id, occurrenceDate: date(17, 17), isCancelled: true)

        let result = OccurrenceExpander.occurrences(
            of: [soccer], exceptions: [moved, cancelled],
            in: DateInterval(start: date(1, 0), end: date(25, 0)), calendar: calendar
        )
        #expect(result.map(\.start) == [date(3, 17), date(10, 16), date(24, 17)])
        #expect(result[1].title == "Soccer (early)")
        #expect(result[1].occurrenceDate == date(10, 17))
    }

    @Test func allDayEventsSortFirst() {
        let household = UUID()
        let morning = Event(householdID: household, title: "Breakfast", start: date(3, 8), end: date(3, 9))
        let allDay = Event(householdID: household, title: "Field trip", start: date(3, 0), end: date(4, 0), isAllDay: true)
        let result = OccurrenceExpander.occurrences(of: [morning, allDay], exceptions: [],
                                                    in: DateInterval(start: date(3, 0), end: date(4, 0)), calendar: calendar)
        #expect(result.map(\.title) == ["Field trip", "Breakfast"])
    }

    @Test func checkingAnItemRecordsWhoAndWhen() {
        let item = ListItem(householdID: UUID(), listID: UUID(), text: "Milk")
        let sam = UUID()
        let when = date(3, 12)
        item.setChecked(true, by: sam, at: when)
        #expect(item.isChecked)
        #expect(item.checkedByID == sam)
        #expect(item.checkStateChangedAt == when)
        #expect(Set(item.dirtyFields) == ["isChecked", "checkedByID", "checkedAt", "checkStateChangedAt"])
    }
}
