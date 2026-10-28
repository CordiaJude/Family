import Foundation
import SwiftData
import FamilyCore

@Model
public final class MealPlanEntry: SyncableModel {
    @Attribute(.unique) public var id: UUID
    public var householdID: UUID
    /// Start of the day this meal is planned for.
    public var date: Date
    public var mealTypeRaw: String
    public var title: String
    public var recipeURL: String?
    public var ingredients: [String]
    public var cookID: UUID?

    public var modifiedAt: Date
    public var ckSystemFields: Data?
    public var dirtyFields: [String]

    public init(
        id: UUID = UUID(),
        householdID: UUID,
        date: Date,
        mealType: MealType = .dinner,
        title: String,
        recipeURL: String? = nil,
        ingredients: [String] = [],
        cookID: UUID? = nil
    ) {
        self.id = id
        self.householdID = householdID
        self.date = date
        self.mealTypeRaw = mealType.rawValue
        self.title = title
        self.recipeURL = recipeURL
        self.ingredients = ingredients
        self.cookID = cookID
        self.modifiedAt = .now
        self.ckSystemFields = nil
        self.dirtyFields = []
    }

    public var mealType: MealType {
        get { MealType(rawValue: mealTypeRaw) ?? .dinner }
        set { mealTypeRaw = newValue.rawValue }
    }
}

@Model
public final class BoardNote: SyncableModel {
    @Attribute(.unique) public var id: UUID
    public var householdID: UUID
    public var title: String
    /// Synced through CKRecord.encryptedValues when `isSensitive` is set.
    public var body: String
    public var symbol: String
    public var colorRaw: String
    public var isPinned: Bool
    /// Hidden behind Face ID; never shown in widgets, notifications or Spotlight.
    public var isSensitive: Bool
    public var sortOrder: Int

    public var modifiedAt: Date
    public var ckSystemFields: Data?
    public var dirtyFields: [String]

    public init(
        id: UUID = UUID(),
        householdID: UUID,
        title: String,
        body: String,
        symbol: String = "note.text",
        color: MemberColor = .yellow,
        isPinned: Bool = false,
        isSensitive: Bool = false,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.householdID = householdID
        self.title = title
        self.body = body
        self.symbol = symbol
        self.colorRaw = color.rawValue
        self.isPinned = isPinned
        self.isSensitive = isSensitive
        self.sortOrder = sortOrder
        self.modifiedAt = .now
        self.ckSystemFields = nil
        self.dirtyFields = []
    }

    public var color: MemberColor {
        get { MemberColor(rawValue: colorRaw) ?? .yellow }
        set { colorRaw = newValue.rawValue }
    }
}
