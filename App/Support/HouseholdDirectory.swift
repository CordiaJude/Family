import Foundation
import FamilyCore
import FamilyData
import FamilyDesign

/// Fast lookups across one snapshot of household data, and the mapping from
/// stored models to design-system row models.
struct HouseholdDirectory {
    struct LegKey: Hashable {
        let eventID: UUID
        let occurrenceDate: Date
        let leg: RideLeg
    }

    let members: [Member]
    private let membersByID: [UUID: Member]
    private let claimsByLeg: [LegKey: [RideClaim]]

    init(members: [Member], claims: [RideClaim]) {
        self.members = members
        self.membersByID = Dictionary(members.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let active = claims.filter { $0.status != .released }
        self.claimsByLeg = Dictionary(grouping: active) {
            LegKey(eventID: $0.eventID, occurrenceDate: $0.occurrenceDate, leg: $0.leg)
        }.mapValues { $0.sorted { $0.claimedAt < $1.claimedAt } }
    }

    func member(_ id: UUID?) -> Member? {
        id.flatMap { membersByID[$0] }
    }

    func badges(_ ids: [UUID]) -> [MemberBadge] {
        ids.compactMap { membersByID[$0]?.badge }
    }

    /// Active claims for one leg, earliest first. More than one means two
    /// people claimed it at the same time; the earliest is treated as primary.
    func claims(for occurrence: EventOccurrence, leg: RideLeg) -> [RideClaim] {
        claimsByLeg[LegKey(eventID: occurrence.event.id, occurrenceDate: occurrence.occurrenceDate, leg: leg)] ?? []
    }

    func claimer(for occurrence: EventOccurrence, leg: RideLeg) -> Member? {
        member(claims(for: occurrence, leg: leg).first?.memberID)
    }

    func unclaimedLegs(of occurrence: EventOccurrence) -> [RideLeg] {
        occurrence.event.neededLegs.filter { claims(for: occurrence, leg: $0).isEmpty }
    }

    /// Time the driver is needed for a leg: drop-off at the start, pickup at the end.
    func time(of leg: RideLeg, in occurrence: EventOccurrence) -> Date {
        leg == .dropoff ? occurrence.start : occurrence.end
    }

    func rowModel(for occurrence: EventOccurrence) -> EventRowModel {
        EventRowModel(
            id: occurrence.id,
            title: occurrence.title,
            start: occurrence.start,
            end: occurrence.end,
            isAllDay: occurrence.isAllDay,
            location: occurrence.locationName ?? occurrence.event.locationAddress,
            attendees: badges(occurrence.event.attendeeIDs),
            rides: occurrence.event.neededLegs.map { leg in
                EventRowModel.Ride(leg: leg, claimer: claimer(for: occurrence, leg: leg)?.badge)
            }
        )
    }
}
