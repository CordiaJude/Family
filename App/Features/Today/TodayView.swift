import SwiftUI
import SwiftData
import FamilyCore
import FamilyData
import FamilyDesign

struct TodayView: View {
    @Environment(HouseholdSession.self) private var session
    @Environment(\.modelContext) private var context
    @Query(sort: \Member.sortOrder) private var members: [Member]
    @Query private var households: [Household]
    @Query private var events: [Event]
    @Query private var exceptions: [EventException]
    @Query private var claims: [RideClaim]

    var body: some View {
        // Re-evaluated whenever the queries change; cheap at household scale.
        let now = Date.now
        let directory = HouseholdDirectory(members: members, claims: claims)
        let today = OccurrenceExpander.occurrences(of: events, exceptions: exceptions, in: OccurrenceExpander.day(containing: now))
        let tomorrowDate = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
        let tomorrow = OccurrenceExpander.occurrences(of: events, exceptions: exceptions, in: OccurrenceExpander.day(containing: tomorrowDate))
        let attention = attentionItems(today: today, tomorrow: tomorrow, directory: directory, now: now)
        let me = session.currentMember(in: members)

        NavigationStack {
            List {
                Section {
                    TodayHeader(date: now, summary: summary(for: today, directory: directory))
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 4, trailing: 20))

                if !attention.isEmpty, let me {
                    Section("Needs Attention") {
                        ForEach(attention, id: \.id) { item in
                            UnclaimedLegRow(
                                row: directory.rowModel(for: item.occurrence),
                                leg: item.leg,
                                time: item.time,
                                claimer: directory.claimer(for: item.occurrence, leg: item.leg)?.badge,
                                me: me.badge,
                                canClaim: me.canDrive
                            ) {
                                RideActions.toggleClaim(item.leg, of: item.occurrence, for: me, directory: directory, in: context)
                            }
                        }
                    }
                }

                Section("Schedule") {
                    if today.isEmpty {
                        Text("Nothing scheduled today.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(today) { occurrence in
                            EventRow(directory.rowModel(for: occurrence))
                                .opacity(occurrence.end < now && !occurrence.isAllDay ? 0.55 : 1)
                        }
                    }
                }

                if !tomorrow.isEmpty {
                    Section {
                        ForEach(tomorrow) { occurrence in
                            EventRow(directory.rowModel(for: occurrence))
                        }
                    } header: {
                        Text("Tomorrow")
                    } footer: {
                        Text(tomorrowDate, format: .dateTime.weekday(.wide).month(.wide).day())
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HouseholdMenu(household: households.first, members: members)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    QuickAddMenu()
                }
            }
        }
    }

    private struct AttentionItem {
        let occurrence: EventOccurrence
        let leg: RideLeg
        let time: Date
        var id: String { "\(occurrence.id)|\(leg.rawValue)" }
    }

    /// Unclaimed legs from now through the end of tomorrow, soonest first.
    private func attentionItems(today: [EventOccurrence], tomorrow: [EventOccurrence], directory: HouseholdDirectory, now: Date) -> [AttentionItem] {
        (today + tomorrow)
            .flatMap { occurrence in
                directory.unclaimedLegs(of: occurrence).map {
                    AttentionItem(occurrence: occurrence, leg: $0, time: directory.time(of: $0, in: occurrence))
                }
            }
            .filter { $0.time >= now }
            .sorted { $0.time < $1.time }
    }

    private func summary(for today: [EventOccurrence], directory: HouseholdDirectory) -> String {
        let legs = today.flatMap { occurrence in occurrence.event.neededLegs.map { (occurrence, $0) } }
        let unclaimed = legs.filter { directory.claims(for: $0.0, leg: $0.1).isEmpty }.count
        return DaySummary(
            timedStarts: today.filter { !$0.isAllDay }.map(\.start),
            allDayCount: today.filter(\.isAllDay).count,
            unclaimedRides: unclaimed,
            totalRides: legs.count
        ).sentence
    }
}

/// Date and one-sentence summary above the timeline.
struct TodayHeader: View {
    let date: Date
    let summary: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(date, format: .dateTime.weekday(.wide).month(.wide).day())
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(summary)
                .font(.title3.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// A row in Needs Attention: the event plus a glass "I've got it" control.
struct UnclaimedLegRow: View {
    let row: EventRowModel
    let leg: RideLeg
    let time: Date
    let claimer: MemberBadge?
    let me: MemberBadge
    let canClaim: Bool
    let toggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                MemberColorBar(row.attendees.map(\.color))
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(leg.displayName) for \(row.displayTitle)")
                        .font(.headline)
                    Text(time, format: .dateTime.weekday(.abbreviated).hour().minute())
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    if let location = row.location {
                        Label(location, systemImage: "mappin.and.ellipse")
                            .labelStyle(CompactLabelStyle())
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .accessibilityElement(children: .combine)
            if canClaim {
                ClaimLegButton(leg: leg, claimer: claimer, me: me, action: toggle)
                    .padding(.leading, 16)
            }
        }
        .padding(.vertical, 4)
    }
}

#if DEBUG
#Preview("Today") {
    TodayView()
        .environment(HouseholdSession())
        .modelContainer(SampleHousehold.previewContainer())
}
#endif
