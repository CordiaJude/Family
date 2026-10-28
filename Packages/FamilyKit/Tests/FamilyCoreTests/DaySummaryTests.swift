import Foundation
import Testing
@testable import FamilyCore

@Suite("Day summary")
struct DaySummaryTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }()

    func at(_ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 3, hour: hour, minute: minute))!
    }

    @Test func emptyDay() {
        let summary = DaySummary(timedStarts: [], unclaimedRides: 0, totalRides: 0, calendar: calendar)
        #expect(summary.sentence == "Nothing on the family calendar today.")
    }

    @Test func busyAfternoonWithUnclaimedRide() {
        let summary = DaySummary(timedStarts: [at(9), at(14, 30), at(16), at(15)], unclaimedRides: 1, totalRides: 3, calendar: calendar)
        #expect(summary.busiestPart == .afternoon)
        #expect(summary.sentence == "Busy afternoon: 4 events, 1 ride still needs a driver.")
    }

    @Test func pluralRides() {
        let summary = DaySummary(timedStarts: [at(17), at(18), at(19), at(20)], unclaimedRides: 2, totalRides: 2, calendar: calendar)
        #expect(summary.sentence == "Busy evening: 4 events, 2 rides still need a driver.")
    }

    @Test func easyDayWithCoveredRides() {
        let summary = DaySummary(timedStarts: [at(8)], unclaimedRides: 0, totalRides: 1, calendar: calendar)
        #expect(summary.sentence == "Easy day: 1 event, every ride is covered.")
    }

    @Test func allDayEventsCount() {
        let summary = DaySummary(timedStarts: [], allDayCount: 2, unclaimedRides: 0, totalRides: 0, calendar: calendar)
        #expect(summary.sentence == "Easy day: 2 events.")
    }

    @Test func partOfDayBoundaries() {
        #expect(DaySummary.PartOfDay(hour: 11) == .morning)
        #expect(DaySummary.PartOfDay(hour: 12) == .afternoon)
        #expect(DaySummary.PartOfDay(hour: 16) == .afternoon)
        #expect(DaySummary.PartOfDay(hour: 17) == .evening)
    }

    @Test func tiesGoToTheEarlierPart() {
        let summary = DaySummary(timedStarts: [at(9), at(10), at(18), at(19)], unclaimedRides: 0, totalRides: 0, calendar: calendar)
        #expect(summary.busiestPart == .morning)
    }
}
