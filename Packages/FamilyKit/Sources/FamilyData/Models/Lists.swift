import Foundation
import SwiftData
import FamilyCore

@Model
public final class FamilyList: SyncableModel {
    @Attribute(.unique) public var id: UUID
    public var householdID: UUID
    public var name: String
    public var symbol: String
    public var colorRaw: String
    public var kindRaw: String
    public var sortOrder: Int

    public var modifiedAt: Date
    public var ckSystemFields: Data?
    public var dirtyFields: [String]

    public init(
        id: UUID = UUID(),
        householdID: UUID,
        name: String,
        kind: ListKind,
        symbol: String? = nil,
        color: MemberColor = .blue,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.householdID = householdID
        self.name = name
        self.symbol = symbol ?? kind.defaultSymbol
        self.colorRaw = color.rawValue
        self.kindRaw = kind.rawValue
        self.sortOrder = sortOrder
        self.modifiedAt = .now
        self.ckSystemFields = nil
        self.dirtyFields = []
    }

    public var kind: ListKind {
        get { ListKind(rawValue: kindRaw) ?? .custom }
        set { kindRaw = newValue.rawValue }
    }

    public var color: MemberColor {
        get { MemberColor(rawValue: colorRaw) ?? .blue }
        set { colorRaw = newValue.rawValue }
    }
}

@Model
public final class ListItem: SyncableModel {
    @Attribute(.unique) public var id: UUID
    public var householdID: UUID
    public var listID: UUID
    public var text: String
    public var quantity: Double?
    public var unit: String?
    public var sectionRaw: String?
    public var addedByID: UUID?
    public var addedAt: Date
    public var isChecked: Bool
    public var checkedByID: UUID?
    public var checkedAt: Date?
    /// Timestamp of the last check/uncheck. Concurrent toggles resolve to the
    /// newest one so every device converges on the same state.
    public var checkStateChangedAt: Date
    public var sortOrder: Int

    public var modifiedAt: Date
    public var ckSystemFields: Data?
    public var dirtyFields: [String]

    public init(
        id: UUID = UUID(),
        householdID: UUID,
        listID: UUID,
        text: String,
        quantity: Double? = nil,
        unit: String? = nil,
        section: GrocerySection? = nil,
        addedByID: UUID? = nil,
        addedAt: Date = .now,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.householdID = householdID
        self.listID = listID
        self.text = text
        self.quantity = quantity
        self.unit = unit
        self.sectionRaw = section?.rawValue
        self.addedByID = addedByID
        self.addedAt = addedAt
        self.isChecked = false
        self.checkedByID = nil
        self.checkedAt = nil
        self.checkStateChangedAt = addedAt
        self.sortOrder = sortOrder
        self.modifiedAt = addedAt
        self.ckSystemFields = nil
        self.dirtyFields = []
    }

    public var section: GrocerySection? {
        get { sectionRaw.flatMap(GrocerySection.init(rawValue:)) }
        set { sectionRaw = newValue?.rawValue }
    }

    public func setChecked(_ checked: Bool, by memberID: UUID?, at date: Date = .now) {
        isChecked = checked
        checkedByID = checked ? memberID : nil
        checkedAt = checked ? date : nil
        checkStateChangedAt = date
        markDirty("isChecked", "checkedByID", "checkedAt", "checkStateChangedAt", at: date)
    }
}
