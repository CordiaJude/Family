import Foundation
import Testing
@testable import FamilyCore

@Suite("Recurrence engine")
struct RecurrenceEngineTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        calendar.firstWeekday = 1
        return calendar
    }()

    var engine: RecurrenceEngine { RecurrenceEngine(calendar: calendar) }

    func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    func window(_ from: Date, days: Int) -> DateInterval {
        DateInterval(start: from, end: calendar.date(byAdding: .day, value: days, to: from)!)
    }

    @Test func oneOffEventOnlyOccursOnce() {
        let start = date(2026, 11, 3, 17)
        let result = engine.occurrences(of: nil, seriesStart: start, duration: 3600, overlapping: window(date(2026, 11, 1), days: 30))
        #expect(result == [start])
    }

    @Test func oneOffOutsideWindowIsExcluded() {
        let start = date(2026, 12, 3, 17)
        let result = engine.occurrences(of: nil, seriesStart: start, duration: 3600, overlapping: window(date(2026, 11, 1), days: 30))
        #expect(result.isEmpty)
    }

    @Test func dailyWithInterval() {
        let start = date(2026, 11, 1, 7, 30)
        let rule = RecurrenceRule(frequency: .daily, interval: 2)
        let result = engine.occurrences(of: rule, seriesStart: start, duration: 600, overlapping: window(date(2026, 11, 1), days: 7))
        #expect(result == [date(2026, 11, 1, 7, 30), date(2026, 11, 3, 7, 30), date(2026, 11, 5, 7, 30), date(2026, 11, 7, 7, 30)])
    }

    @Test func weeklyOnSeveralDays() {
        // Tuesday Nov 3 2026; soccer every Tuesday and Thursday.
        let start = date(2026, 11, 3, 17)
        let rule = RecurrenceRule.weekly(on: [.tuesday, .thursday])
        let result = engine.occurrences(of: rule, seriesStart: start, duration: 5400, overlapping: window(date(2026, 11, 1), days: 14))
        #expect(result == [date(2026, 11, 3, 17), date(2026, 11, 5, 17), date(2026, 11, 10, 17), date(2026, 11, 12, 17)])
    }

    @Test func weeklyDefaultsToStartWeekday() {
        let start = date(2026, 11, 4, 16)  // Wednesday
        let rule = RecurrenceRule(frequency: .weekly)
        let result = engine.occurrences(of: rule, seriesStart: start, duration: 3600, overlapping: window(date(2026, 11, 1), days: 21))
        #expect(result == [date(2026, 11, 4, 16), date(2026, 11, 11, 16), date(2026, 11, 18, 16)])
    }

    @Test func weeklyNeverEmitsBeforeSeriesStart() {
        // Starts Thursday; the Tuesday of the first week must be skipped.
        let start = date(2026, 11, 5, 17)
        let rule = RecurrenceRule.weekly(on: [.tuesday, .thursday])
        let result = engine.occurrences(of: rule, seriesStart: start, duration: 3600, overlapping: window(date(2026, 11, 1), days: 7))
        #expect(result == [date(2026, 11, 5, 17)])
    }

    @Test func everyOtherWeek() {
        let start = date(2026, 11, 2, 9)  // Monday
        let rule = RecurrenceRule.weekly(on: [.monday], every: 2)
        let result = engine.occurrences(of: rule, seriesStart: start, duration: 3600, overlapping: window(date(2026, 11, 1), days: 35))
        #expect(result == [date(2026, 11, 2, 9), date(2026, 11, 16, 9), date(2026, 11, 30, 9)])
    }

    @Test func keepsWallClockTimeAcrossDaylightSavingEnd() {
        // DST ends Nov 1 2026 in New York. A 5 PM event stays at 5 PM.
        let start = date(2026, 10, 27, 17)
        let rule = RecurrenceRule.weekly(on: [.tuesday])
        let result = engine.occurrences(of: rule, seriesStart: start, duration: 3600, overlapping: window(date(2026, 10, 25), days: 14))
        #expect(result.map { calendar.component(.hour, from: $0) } == [17, 17])
        #expect(result.last == date(2026, 11, 3, 17))
    }

    @Test func monthlyOnThe31stSkipsShortMonths() {
        let start = date(2026, 1, 31, 12)
        let rule = RecurrenceRule(frequency: .monthly)
        let result = engine.occurrences(of: rule, seriesStart: start, duration: 3600, overlapping: DateInterval(start: date(2026, 1, 1), end: date(2026, 6, 1)))
        #expect(result == [date(2026, 1, 31, 12), date(2026, 3, 31, 12), date(2026, 5, 31, 12)])
    }

    @Test func monthlySecondTuesday() {
        let start = date(2026, 11, 10, 19)
        let rule = RecurrenceRule(frequency: .monthly, weekdays: [.tuesday], monthlyOrdinal: 2)
        let result = engine.occurrences(of: rule, seriesStart: start, duration: 3600, overlapping: DateInterval(start: date(2026, 11, 1), end: date(2027, 2, 1)))
        #expect(result == [date(2026, 11, 10, 19), date(2026, 12, 8, 19), date(2027, 1, 12, 19)])
    }

    @Test func monthlyLastFriday() {
        let start = date(2026, 11, 27, 18)
        let rule = RecurrenceRule(frequency: .monthly, weekdays: [.friday], monthlyOrdinal: -1)
        let result = engine.occurrences(of: rule, seriesStart: start, duration: 3600, overlapping: DateInterval(start: date(2026, 11, 1), end: date(2027, 1, 1)))
        #expect(result == [date(2026, 11, 27, 18), date(2026, 12, 25, 18)])
    }

    @Test func yearlyOnLeapDaySkipsNonLeapYears() {
        let start = date(2028, 2, 29, 8)
        let rule = RecurrenceRule(frequency: .yearly)
        let result = engine.occurrences(of: rule, seriesStart: start, duration: 3600, overlapping: DateInterval(start: date(2028, 1, 1), end: date(2033, 1, 1)))
        #expect(result == [date(2028, 2, 29, 8), date(2032, 2, 29, 8)])
    }

    @Test func countLimitsOccurrences() {
        let start = date(2026, 11, 1, 8)
        let rule = RecurrenceRule(frequency: .daily, count: 3)
        let result = engine.occurrences(of: rule, seriesStart: start, duration: 60, overlapping: window(date(2026, 11, 1), days: 30))
        #expect(result.count == 3)
    }

    @Test func countIsMeasuredFromSeriesStartNotWindow() {
        let start = date(2026, 11, 1, 8)
        let rule = RecurrenceRule(frequency: .daily, count: 3)
        let result = engine.occurrences(of: rule, seriesStart: start, duration: 60, overlapping: window(date(2026, 11, 2), days: 30))
        #expect(result == [date(2026, 11, 2, 8), date(2026, 11, 3, 8)])
    }

    @Test func untilIsInclusiveOfTheWholeDay() {
        let start = date(2026, 11, 1, 20)
        let rule = RecurrenceRule(frequency: .daily, until: date(2026, 11, 3))
        let result = engine.occurrences(of: rule, seriesStart: start, duration: 60, overlapping: window(date(2026, 11, 1), days: 30))
        #expect(result == [date(2026, 11, 1, 20), date(2026, 11, 2, 20), date(2026, 11, 3, 20)])
    }

    @Test func untilTerminatesInfiniteWeeklyRuleWithNoMatches() {
        // Fifth Monday of a month rarely exists; must still terminate.
        let start = date(2026, 11, 30, 9)
        let rule = RecurrenceRule(frequency: .monthly, weekdays: [.monday], monthlyOrdinal: 5, until: date(2027, 6, 1))
        let result = engine.occurrences(of: rule, seriesStart: start, duration: 60, overlapping: DateInterval(start: date(2026, 1, 1), end: date(2030, 1, 1)))
        #expect(result.first == date(2026, 11, 30, 9))
        #expect(result.allSatisfy { $0 < date(2027, 6, 2) })
    }

    @Test func excludedOccurrencesAreSkipped() {
        let start = date(2026, 11, 3, 17)
        let rule = RecurrenceRule.weekly(on: [.tuesday])
        let result = engine.occurrences(
            of: rule, seriesStart: start, duration: 3600,
            overlapping: window(date(2026, 11, 1), days: 21),
            excluding: [date(2026, 11, 10, 17)]
        )
        #expect(result == [date(2026, 11, 3, 17), date(2026, 11, 17, 17)])
    }

    @Test func occurrenceInProgressAtWindowStartIsIncluded() {
        let start = date(2026, 11, 1, 23)
        let result = engine.occurrences(of: .daily, seriesStart: start, duration: 7200, overlapping: window(date(2026, 11, 2), days: 1))
        #expect(result == [date(2026, 11, 1, 23), date(2026, 11, 2, 23)])
    }

    @Test func nextOccurrenceFindsFirstAfterDate() {
        let start = date(2026, 11, 3, 17)
        let rule = RecurrenceRule.weekly(on: [.tuesday, .thursday])
        #expect(engine.nextOccurrence(of: rule, seriesStart: start, onOrAfter: date(2026, 11, 6)) == date(2026, 11, 10, 17))
    }

    @Test func ruleRoundTripsThroughData() {
        let rule = RecurrenceRule(frequency: .monthly, interval: 2, weekdays: [.friday], monthlyOrdinal: -1, count: 5)
        #expect(RecurrenceRule.decode(rule.encoded()) == rule)
    }
}
