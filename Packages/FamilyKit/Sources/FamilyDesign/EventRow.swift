import SwiftUI
import FamilyCore

/// Display data for one event occurrence row.
public struct EventRowModel: Identifiable, Hashable, Sendable {
    public struct Ride: Hashable, Sendable, Identifiable {
        public var leg: RideLeg
        public var claimer: MemberBadge?
        public var id: RideLeg { leg }

        public init(leg: RideLeg, claimer: MemberBadge?) {
            self.leg = leg
            self.claimer = claimer
        }
    }

    public var id: String
    public var title: String
    public var start: Date
    public var end: Date
    public var isAllDay: Bool
    public var location: String?
    public var attendees: [MemberBadge]
    public var rides: [Ride]

    public init(
        id: String, title: String, start: Date, end: Date, isAllDay: Bool = false,
        location: String? = nil, attendees: [MemberBadge], rides: [Ride] = []
    ) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.location = location
        self.attendees = attendees
        self.rides = rides
    }

    public var unclaimedLegs: [RideLeg] { rides.filter { $0.claimer == nil }.map(\.leg) }

    /// "Emma’s Soccer practice" when one person attends, otherwise the title.
    public var displayTitle: String {
        if attendees.count == 1, let only = attendees.first {
            return "\(PersonName.possessive(only.firstName)) \(title.lowercasedFirstLetterIfNeeded)"
        }
        return title
    }

    public var timeText: String {
        if isAllDay { return String(localized: "All day") }
        return (start..<max(end, start)).formatted(.interval.hour().minute())
    }

    /// e.g. "Emma’s soccer practice, 5:00 PM to 6:30 PM, at Riverside Park, pickup needs a driver"
    public var accessibilityDescription: String {
        var parts = [displayTitle]
        if isAllDay {
            parts.append(String(localized: "all day"))
        } else {
            let from = start.formatted(date: .omitted, time: .shortened)
            let to = end.formatted(date: .omitted, time: .shortened)
            parts.append(String(localized: "\(from) to \(to)"))
        }
        if let location { parts.append(String(localized: "at \(location)")) }
        for ride in rides {
            if let claimer = ride.claimer {
                parts.append(String(localized: "\(ride.leg.displayName) by \(claimer.firstName)"))
            } else {
                parts.append(String(localized: "\(ride.leg.displayName) needs a driver"))
            }
        }
        return parts.joined(separator: ", ")
    }
}

extension String {
    /// Lowercases the first letter of a title used after a possessive
    /// ("Soccer practice" → "soccer practice"), leaving acronyms alone.
    var lowercasedFirstLetterIfNeeded: String {
        guard let first = first, first.isUppercase else { return self }
        let second = dropFirst().first
        if let second, second.isUppercase { return self }
        return first.lowercased() + dropFirst()
    }
}

/// The slim leading bar showing who an event is for. Several attendees split
/// the bar into stacked segments of their colors.
public struct MemberColorBar: View {
    let colors: [MemberColor]

    public init(_ colors: [MemberColor]) {
        self.colors = colors
    }

    public var body: some View {
        VStack(spacing: 1.5) {
            ForEach(Array(colors.prefix(4).enumerated()), id: \.offset) { _, color in
                color.color
            }
        }
        .frame(width: 4)
        .clipShape(.capsule)
        .accessibilityHidden(true)
    }
}

/// The standard event row: color bar, title, time, place, attendees and ride status.
public struct EventRow: View {
    let model: EventRowModel
    var showsAttendees: Bool

    public init(_ model: EventRowModel, showsAttendees: Bool = true) {
        self.model = model
        self.showsAttendees = showsAttendees
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            MemberColorBar(model.attendees.map(\.color))
            VStack(alignment: .leading, spacing: 3) {
                Text(model.displayTitle)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(model.timeText)
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                if let location = model.location {
                    Label(location, systemImage: "mappin.and.ellipse")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .labelStyle(CompactLabelStyle())
                }
                if !model.rides.isEmpty {
                    RideStatusLine(rides: model.rides)
                        .padding(.top, 2)
                }
            }
            Spacer(minLength: 8)
            if showsAttendees && model.attendees.count > 1 {
                AvatarStack(model.attendees, size: .small, limit: 3)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.accessibilityDescription)
    }
}

/// "Pickup · Sam" or "Pickup needs a driver" for each leg.
struct RideStatusLine: View {
    let rides: [EventRowModel.Ride]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { items }
            VStack(alignment: .leading, spacing: 4) { items }
        }
    }

    @ViewBuilder
    private var items: some View {
        ForEach(rides) { ride in
            if let claimer = ride.claimer {
                HStack(spacing: 4) {
                    AvatarView(claimer, size: .mini)
                    Text("\(ride.leg.displayName) · \(claimer.firstName)")
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            } else {
                Label("\(ride.leg.displayName) needs a driver", systemImage: "car.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .labelStyle(CompactLabelStyle())
            }
        }
    }
}

/// An icon-and-title label with tighter spacing than the default.
public struct CompactLabelStyle: LabelStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            configuration.icon
                .imageScale(.small)
            configuration.title
        }
    }
}

#if DEBUG
extension EventRowModel {
    static func sample(_ title: String, hour: Int, minutes: Int, who: [MemberBadge],
                       location: String? = nil, rides: [Ride] = []) -> EventRowModel {
        let start = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: .now)!
        return EventRowModel(id: title, title: title, start: start, end: start.addingTimeInterval(Double(minutes) * 60),
                             location: location, attendees: who, rides: rides)
    }
}

#Preview("Event rows") {
    List {
        EventRow(.sample("Soccer practice", hour: 17, minutes: 90, who: [.emma], location: "Riverside Park",
                         rides: [.init(leg: .pickup, claimer: nil)]))
        EventRow(.sample("Swim team", hour: 16, minutes: 60, who: [.liam], location: "Aquatic Center",
                         rides: [.init(leg: .dropoff, claimer: .alex), .init(leg: .pickup, claimer: .sam)]))
        EventRow(.sample("Dinner at Grandma’s", hour: 18, minutes: 180, who: MemberBadge.parkers))
        EventRow(.sample("Vet checkup", hour: 9, minutes: 30, who: [.biscuit, .sam], location: "Paws Vet Clinic"))
    }
}
#endif
