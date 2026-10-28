import SwiftUI
import SwiftData
import FamilyCore
import FamilyData
import FamilyDesign

/// The tab bar accessory: the next ride leg that still needs a driver.
/// Shows a single compact line when the tab bar is minimized.
struct NextUpAccessory: View {
    @Environment(HouseholdSession.self) private var session
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement
    @Query(sort: \Member.sortOrder) private var members: [Member]
    @Query private var events: [Event]
    @Query private var exceptions: [EventException]
    @Query private var claims: [RideClaim]

    private struct NextLeg {
        let occurrence: EventOccurrence
        let leg: RideLeg
        let time: Date
        let who: [MemberBadge]
    }

    private var nextLeg: NextLeg? {
        let now = Date.now
        let window = DateInterval(start: now, duration: 48 * 3600)
        let directory = HouseholdDirectory(members: members, claims: claims)
        let candidates = OccurrenceExpander.occurrences(of: events.filter(\.needsDriver), exceptions: exceptions, in: window)
            .flatMap { occurrence in
                directory.unclaimedLegs(of: occurrence).map { leg in
                    NextLeg(occurrence: occurrence, leg: leg, time: directory.time(of: leg, in: occurrence),
                            who: directory.badges(occurrence.event.attendeeIDs))
                }
            }
            .filter { $0.time >= now }
        return candidates.min { $0.time < $1.time }
    }

    var body: some View {
        Button {
            session.selectedTab = .today
        } label: {
            if let next = nextLeg {
                content(for: next)
            } else {
                Label("Every ride is covered", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func content(for next: NextLeg) -> some View {
        let name = next.who.first.map { PersonName.possessive($0.firstName) } ?? ""
        let time = next.time.formatted(date: .omitted, time: .shortened)
        HStack(spacing: 10) {
            Image(systemName: "car.fill")
                .foregroundStyle(.orange)
            if placement == .inline {
                Text("\(name) \(next.leg.displayName.lowercased()) · \(time)")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Needs a driver · \(Text(next.time, style: .relative))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(name) \(next.leg.displayName.lowercased()), \(next.occurrence.title) · \(time)")
                        .font(.subheadline.weight(.semibold))
                }
                .lineLimit(1)
                Spacer(minLength: 0)
                AvatarStack(next.who, size: .small, limit: 2)
            }
        }
        .padding(.horizontal, 16)
        .monospacedDigit()
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens Today")
    }
}
