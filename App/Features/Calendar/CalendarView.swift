import SwiftUI
import SwiftData
import FamilyCore
import FamilyData
import FamilyDesign

/// Phase 1: a two-week agenda with the member filter. Day, week and month
/// views arrive in Phase 2.
struct CalendarView: View {
    @Query(sort: \Member.sortOrder) private var members: [Member]
    @Query private var events: [Event]
    @Query private var exceptions: [EventException]
    @Query private var claims: [RideClaim]
    @State private var memberFilter: Set<UUID> = []

    private let calendar = Calendar.current

    var body: some View {
        let directory = HouseholdDirectory(members: members, claims: claims)
        let start = calendar.startOfDay(for: .now)
        let window = DateInterval(start: start, end: calendar.date(byAdding: .day, value: 14, to: start) ?? start)
        let filtered = memberFilter.isEmpty ? events : events.filter { !memberFilter.isDisjoint(with: $0.attendeeIDs) }
        let occurrences = OccurrenceExpander.occurrences(of: filtered, exceptions: exceptions, in: window)
        let days = Dictionary(grouping: occurrences) { calendar.startOfDay(for: max($0.start, window.start)) }

        NavigationStack {
            List {
                ForEach(days.keys.sorted(), id: \.self) { day in
                    Section {
                        ForEach(days[day] ?? []) { occurrence in
                            EventRow(directory.rowModel(for: occurrence))
                        }
                    } header: {
                        DayHeader(date: day)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .overlay {
                if occurrences.isEmpty {
                    ContentUnavailableView {
                        Label("No Events", systemImage: "calendar")
                    } description: {
                        Text(memberFilter.isEmpty
                             ? "Nothing on the family calendar for the next two weeks."
                             : "No events for the selected people in the next two weeks.")
                    } actions: {
                        if !memberFilter.isEmpty {
                            Button("Show Everyone") { memberFilter.removeAll() }
                                .buttonStyle(.glass)
                        }
                    }
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                MemberFilterBar(members: members.map(\.badge), selection: $memberFilter)
            }
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct DayHeader: View {
    let date: Date

    var body: some View {
        HStack(spacing: 6) {
            if Calendar.current.isDateInToday(date) {
                Text("Today")
                    .foregroundStyle(.tint)
            } else if Calendar.current.isDateInTomorrow(date) {
                Text("Tomorrow")
            }
            Text(date, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                .foregroundStyle(.secondary)
        }
        .font(.subheadline.weight(.semibold))
        .textCase(nil)
        .accessibilityAddTraits(.isHeader)
    }
}

#if DEBUG
#Preview {
    CalendarView()
        .environment(HouseholdSession())
        .modelContainer(SampleHousehold.previewContainer())
}
#endif
