import SwiftUI
import SwiftData
import WidgetKit
import FamilyCore
import FamilyData
import FamilyDesign

/// Today's family schedule, read from the shared App Group store.
/// Phase 6 adds medium/large layouts, rides and interactive actions.
struct TodayScheduleWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodaySchedule", provider: TodayScheduleProvider()) { entry in
            TodayScheduleView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Today")
        .description("Your family’s next events.")
        .supportedFamilies([.systemSmall])
    }
}

struct TodayScheduleEntry: TimelineEntry {
    struct Item: Hashable, Identifiable {
        let id: String
        let title: String
        let start: Date
        let isAllDay: Bool
        let colors: [MemberColor]
    }

    let date: Date
    let items: [Item]

    static let placeholder = TodayScheduleEntry(date: .now, items: [
        Item(id: "1", title: "Soccer practice", start: .now, isAllDay: false, colors: [.purple]),
        Item(id: "2", title: "Swim team", start: .now.addingTimeInterval(3600), isAllDay: false, colors: [.green]),
    ])
}

struct TodayScheduleProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayScheduleEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayScheduleEntry) -> Void) {
        completion(context.isPreview ? .placeholder : Self.loadEntry(at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayScheduleEntry>) -> Void) {
        let now = Date.now
        let entry = Self.loadEntry(at: now)
        // Refresh when the next event starts, at midnight, or in 30 minutes.
        let midnight = Calendar.current.startOfDay(for: now).addingTimeInterval(86_400)
        let nextStart = entry.items.map(\.start).filter { $0 > now }.min()
        let refresh = [nextStart, midnight, now.addingTimeInterval(30 * 60)].compactMap { $0 }.min() ?? midnight
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }

    static func loadEntry(at now: Date) -> TodayScheduleEntry {
        guard let container = try? FamilyStore.makeContainer() else {
            return TodayScheduleEntry(date: now, items: [])
        }
        let context = ModelContext(container)
        let events = (try? context.fetch(FetchDescriptor<Event>())) ?? []
        let exceptions = (try? context.fetch(FetchDescriptor<EventException>())) ?? []
        let members = (try? context.fetch(FetchDescriptor<Member>())) ?? []
        let colors = Dictionary(members.map { ($0.id, $0.color) }, uniquingKeysWith: { first, _ in first })

        let items = OccurrenceExpander
            .occurrences(of: events, exceptions: exceptions, in: OccurrenceExpander.day(containing: now))
            .filter { $0.isAllDay || $0.end > now }
            .map { occurrence in
                TodayScheduleEntry.Item(
                    id: occurrence.id,
                    title: occurrence.title,
                    start: occurrence.start,
                    isAllDay: occurrence.isAllDay,
                    colors: occurrence.event.attendeeIDs.compactMap { colors[$0] }
                )
            }
        return TodayScheduleEntry(date: now, items: items)
    }
}

struct TodayScheduleView: View {
    let entry: TodayScheduleEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.date, format: .dateTime.weekday(.wide))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tint)
                .textCase(.uppercase)
            if entry.items.isEmpty {
                Spacer()
                Text("Nothing else today")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ForEach(entry.items.prefix(3)) { item in
                    HStack(spacing: 6) {
                        MemberColorBar(item.colors)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(item.title)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                            Group {
                                if item.isAllDay {
                                    Text("All day")
                                } else {
                                    Text(item.start, format: .dateTime.hour().minute())
                                }
                            }
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview(as: .systemSmall) {
    TodayScheduleWidget()
} timeline: {
    TodayScheduleEntry.placeholder
    TodayScheduleEntry(date: .now, items: [])
}
