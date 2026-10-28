import Foundation
import SwiftData
import FamilyCore

@Model
public final class Event: SyncableModel {
    @Attribute(.unique) public var id: UUID
    public var householdID: UUID
    public var title: String
    public var start: Date
    public var end: Date
    public var isAllDay: Bool
    public var timeZoneID: String?

    public var locationName: String?
    public var locationAddress: String?
    public var latitude: Double?
    public var longitude: Double?

    /// JSON-encoded `RecurrenceRule`; nil for one-off events.
    public var recurrenceData: Data?
    public var attendeeIDs: [UUID]
    public var needsDropoff: Bool
    public var needsPickup: Bool
    public var notes: String
    /// Minutes before start to remind attendees.
    public var reminderOffsets: [Int]
    public var createdByID: UUID?
    /// Set on the new series when "this and future events" splits a series.
    public var splitFromID: UUID?
    /// Identifier of the mirrored EventKit copy on this device. Never synced.
    public var ekIdentifier: String?

    public var modifiedAt: Date
    public var ckSystemFields: Data?
    public var dirtyFields: [String]

    public init(
        id: UUID = UUID(),
        householdID: UUID,
        title: String,
        start: Date,
        end: Date,
        isAllDay: Bool = false,
        locationName: String? = nil,
        locationAddress: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        recurrence: RecurrenceRule? = nil,
        attendeeIDs: [UUID] = [],
        needsDropoff: Bool = false,
        needsPickup: Bool = false,
        notes: String = "",
        reminderOffsets: [Int] = [],
        createdByID: UUID? = nil
    ) {
        self.id = id
        self.householdID = householdID
        self.title = title
        self.start = start
        self.end = max(end, start)
        self.isAllDay = isAllDay
        self.timeZoneID = nil
        self.locationName = locationName
        self.locationAddress = locationAddress
        self.latitude = latitude
        self.longitude = longitude
        self.recurrenceData = recurrence?.encoded()
        self.attendeeIDs = attendeeIDs
        self.needsDropoff = needsDropoff
        self.needsPickup = needsPickup
        self.notes = notes
        self.reminderOffsets = reminderOffsets
        self.createdByID = createdByID
        self.splitFromID = nil
        self.ekIdentifier = nil
        self.modifiedAt = .now
        self.ckSystemFields = nil
        self.dirtyFields = []
    }

    public var recurrence: RecurrenceRule? {
        get { RecurrenceRule.decode(recurrenceData) }
        set { recurrenceData = newValue?.encoded() }
    }

    public var duration: TimeInterval { end.timeIntervalSince(start) }

    public var needsDriver: Bool { needsDropoff || needsPickup }

    public var neededLegs: [RideLeg] {
        var legs: [RideLeg] = []
        if needsDropoff { legs.append(.dropoff) }
        if needsPickup { legs.append(.pickup) }
        return legs
    }
}

/// A change to one occurrence of a repeating event.
@Model
public final class EventException: SyncableModel {
    @Attribute(.unique) public var id: UUID
    public var householdID: UUID
    public var eventID: UUID
    /// Original start of the occurrence this exception replaces.
    public var occurrenceDate: Date
    public var isCancelled: Bool
    public var overrideTitle: String?
    public var overrideStart: Date?
    public var overrideEnd: Date?
    public var overrideLocationName: String?
    public var overrideNotes: String?

    public var modifiedAt: Date
    public var ckSystemFields: Data?
    public var dirtyFields: [String]

    public init(id: UUID = UUID(), householdID: UUID, eventID: UUID, occurrenceDate: Date, isCancelled: Bool = false) {
        self.id = id
        self.householdID = householdID
        self.eventID = eventID
        self.occurrenceDate = occurrenceDate
        self.isCancelled = isCancelled
        self.modifiedAt = .now
        self.ckSystemFields = nil
        self.dirtyFields = []
    }
}

/// Someone taking one leg of one occurrence. Each claim is its own record so
/// concurrent claims from two devices both survive sync and can be shown.
@Model
public final class RideClaim: SyncableModel {
    @Attribute(.unique) public var id: UUID
    public var householdID: UUID
    public var eventID: UUID
    public var occurrenceDate: Date
    public var legRaw: String
    public var memberID: UUID
    public var claimedAt: Date
    public var statusRaw: String
    public var swapTargetID: UUID?

    public var modifiedAt: Date
    public var ckSystemFields: Data?
    public var dirtyFields: [String]

    public init(
        id: UUID = UUID(),
        householdID: UUID,
        eventID: UUID,
        occurrenceDate: Date,
        leg: RideLeg,
        memberID: UUID,
        claimedAt: Date = .now
    ) {
        self.id = id
        self.householdID = householdID
        self.eventID = eventID
        self.occurrenceDate = occurrenceDate
        self.legRaw = leg.rawValue
        self.memberID = memberID
        self.claimedAt = claimedAt
        self.statusRaw = ClaimStatus.active.rawValue
        self.swapTargetID = nil
        self.modifiedAt = claimedAt
        self.ckSystemFields = nil
        self.dirtyFields = []
    }

    public var leg: RideLeg {
        get { RideLeg(rawValue: legRaw) ?? .pickup }
        set { legRaw = newValue.rawValue }
    }

    public var status: ClaimStatus {
        get { ClaimStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }
}

/// A busy period from an adult's personal calendar, shared without any details.
@Model
public final class BusyBlock: SyncableModel {
    @Attribute(.unique) public var id: UUID
    public var householdID: UUID
    public var memberID: UUID
    public var start: Date
    public var end: Date

    public var modifiedAt: Date
    public var ckSystemFields: Data?
    public var dirtyFields: [String]

    public init(id: UUID = UUID(), householdID: UUID, memberID: UUID, start: Date, end: Date) {
        self.id = id
        self.householdID = householdID
        self.memberID = memberID
        self.start = start
        self.end = end
        self.modifiedAt = .now
        self.ckSystemFields = nil
        self.dirtyFields = []
    }
}
