import Foundation
import SwiftData
import FamilyCore

@Model
public final class Chore: SyncableModel {
    @Attribute(.unique) public var id: UUID
    public var householdID: UUID
    public var title: String
    public var symbol: String
    public var assigneeID: UUID
    /// JSON-encoded `RecurrenceRule`; nil for a one-time chore.
    public var recurrenceData: Data?
    /// First day the chore is due.
    public var startDate: Date
    public var valueKindRaw: String
    /// Points, or money in minor units (cents).
    public var value: Int
    /// Minutes after midnight the chore is due, if any.
    public var dueMinutes: Int?
    public var requiresPhotoProof: Bool
    public var isArchived: Bool

    public var modifiedAt: Date
    public var ckSystemFields: Data?
    public var dirtyFields: [String]

    public init(
        id: UUID = UUID(),
        householdID: UUID,
        title: String,
        symbol: String = "checkmark.circle",
        assigneeID: UUID,
        recurrence: RecurrenceRule? = .daily,
        startDate: Date,
        valueKind: ChoreValueKind = .points,
        value: Int = 1,
        dueMinutes: Int? = nil,
        requiresPhotoProof: Bool = false
    ) {
        self.id = id
        self.householdID = householdID
        self.title = title
        self.symbol = symbol
        self.assigneeID = assigneeID
        self.recurrenceData = recurrence?.encoded()
        self.startDate = startDate
        self.valueKindRaw = valueKind.rawValue
        self.value = value
        self.dueMinutes = dueMinutes
        self.requiresPhotoProof = requiresPhotoProof
        self.isArchived = false
        self.modifiedAt = .now
        self.ckSystemFields = nil
        self.dirtyFields = []
    }

    public var recurrence: RecurrenceRule? {
        get { RecurrenceRule.decode(recurrenceData) }
        set { recurrenceData = newValue?.encoded() }
    }

    public var valueKind: ChoreValueKind {
        get { ChoreValueKind(rawValue: valueKindRaw) ?? .points }
        set { valueKindRaw = newValue.rawValue }
    }
}

@Model
public final class ChoreCompletion: SyncableModel {
    @Attribute(.unique) public var id: UUID
    public var householdID: UUID
    public var choreID: UUID
    /// Start of the day the completed occurrence was due.
    public var occurrenceDate: Date
    public var memberID: UUID
    public var completedAt: Date
    @Attribute(.externalStorage) public var photo: Data?
    public var approvalRaw: String
    public var approvedByID: UUID?

    public var modifiedAt: Date
    public var ckSystemFields: Data?
    public var dirtyFields: [String]

    public init(
        id: UUID = UUID(),
        householdID: UUID,
        choreID: UUID,
        occurrenceDate: Date,
        memberID: UUID,
        completedAt: Date = .now,
        approval: ApprovalState = .pending
    ) {
        self.id = id
        self.householdID = householdID
        self.choreID = choreID
        self.occurrenceDate = occurrenceDate
        self.memberID = memberID
        self.completedAt = completedAt
        self.photo = nil
        self.approvalRaw = approval.rawValue
        self.approvedByID = nil
        self.modifiedAt = completedAt
        self.ckSystemFields = nil
        self.dirtyFields = []
    }

    public var approval: ApprovalState {
        get { ApprovalState(rawValue: approvalRaw) ?? .pending }
        set { approvalRaw = newValue.rawValue }
    }
}

@Model
public final class AllowanceEntry: SyncableModel {
    @Attribute(.unique) public var id: UUID
    public var householdID: UUID
    public var memberID: UUID
    /// Minor units; positive for earnings, recorded payments use `isPaid`.
    public var amountMinor: Int
    public var reason: String
    public var date: Date
    public var isPaid: Bool
    public var completionID: UUID?

    public var modifiedAt: Date
    public var ckSystemFields: Data?
    public var dirtyFields: [String]

    public init(
        id: UUID = UUID(),
        householdID: UUID,
        memberID: UUID,
        amountMinor: Int,
        reason: String,
        date: Date = .now,
        isPaid: Bool = false,
        completionID: UUID? = nil
    ) {
        self.id = id
        self.householdID = householdID
        self.memberID = memberID
        self.amountMinor = amountMinor
        self.reason = reason
        self.date = date
        self.isPaid = isPaid
        self.completionID = completionID
        self.modifiedAt = date
        self.ckSystemFields = nil
        self.dirtyFields = []
    }
}
