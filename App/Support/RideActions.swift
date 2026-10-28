import Foundation
import SwiftData
import FamilyCore
import FamilyData

/// Claiming and releasing ride legs.
enum RideActions {
    /// Claims `leg` for `member`, or releases it if `member` already has it.
    static func toggleClaim(
        _ leg: RideLeg,
        of occurrence: EventOccurrence,
        for member: Member,
        directory: HouseholdDirectory,
        in context: ModelContext
    ) {
        let existing = directory.claims(for: occurrence, leg: leg)
        if let mine = existing.first(where: { $0.memberID == member.id }) {
            mine.status = .released
            mine.markDirty("statusRaw")
        } else {
            context.insert(RideClaim(
                householdID: occurrence.event.householdID,
                eventID: occurrence.event.id,
                occurrenceDate: occurrence.occurrenceDate,
                leg: leg,
                memberID: member.id
            ))
        }
        try? context.save()
    }
}
