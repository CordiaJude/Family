import Foundation

/// A household member's role. Roles gate what someone can do in the app;
/// CloudKit itself grants every participant the same access (see README).
public enum MemberRole: String, Codable, Sendable, CaseIterable, Identifiable {
    case adult
    case teen
    case child

    public var id: Self { self }

    public var displayName: String {
        switch self {
        case .adult: String(localized: "Adult")
        case .teen: String(localized: "Teen")
        case .child: String(localized: "Child")
        }
    }

    public var canApproveChores: Bool { self == .adult }
    public var canEditOthersEvents: Bool { self != .child }
    public var canAddEvents: Bool { self != .child }
    public var canManageHousehold: Bool { self == .adult }
}

/// The curated member palette. Each case maps to a system color in FamilyDesign.
public enum MemberColor: String, Codable, Sendable, CaseIterable, Identifiable {
    case red, orange, yellow, green, mint, teal, blue, indigo, purple, pink

    public var id: Self { self }

    public var displayName: String {
        switch self {
        case .red: String(localized: "Red")
        case .orange: String(localized: "Orange")
        case .yellow: String(localized: "Yellow")
        case .green: String(localized: "Green")
        case .mint: String(localized: "Mint")
        case .teal: String(localized: "Teal")
        case .blue: String(localized: "Blue")
        case .indigo: String(localized: "Indigo")
        case .purple: String(localized: "Purple")
        case .pink: String(localized: "Pink")
        }
    }
}

public enum AvatarKind: String, Codable, Sendable, CaseIterable {
    case initials
    case emoji
    case photo
}

public enum LocationSharingState: String, Codable, Sendable, CaseIterable {
    case sharing
    case paused
    case off
}

public enum ListKind: String, Codable, Sendable, CaseIterable, Identifiable {
    case grocery
    case packing
    case todo
    case custom

    public var id: Self { self }

    public var defaultSymbol: String {
        switch self {
        case .grocery: "cart"
        case .packing: "suitcase"
        case .todo: "checklist"
        case .custom: "list.bullet"
        }
    }
}

/// Grocery aisle sections, in the order a typical store walk visits them.
public enum GrocerySection: String, Codable, Sendable, CaseIterable, Identifiable, Comparable {
    case produce
    case bakery
    case dairy
    case meat
    case frozen
    case pantry
    case household
    case personalCare
    case other

    public var id: Self { self }

    public var displayName: String {
        switch self {
        case .produce: String(localized: "Produce")
        case .bakery: String(localized: "Bakery")
        case .dairy: String(localized: "Dairy")
        case .meat: String(localized: "Meat")
        case .frozen: String(localized: "Frozen")
        case .pantry: String(localized: "Pantry")
        case .household: String(localized: "Household")
        case .personalCare: String(localized: "Personal Care")
        case .other: String(localized: "Other")
        }
    }

    public var symbol: String {
        switch self {
        case .produce: "carrot"
        case .bakery: "birthday.cake"
        case .dairy: "cup.and.saucer"
        case .meat: "fish"
        case .frozen: "snowflake"
        case .pantry: "takeoutbag.and.cup.and.straw"
        case .household: "house"
        case .personalCare: "comb"
        case .other: "bag"
        }
    }

    private var sortIndex: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.sortIndex < rhs.sortIndex }
}

/// One leg of a ride attached to an event.
public enum RideLeg: String, Codable, Sendable, CaseIterable, Identifiable {
    case dropoff
    case pickup

    public var id: Self { self }

    public var displayName: String {
        switch self {
        case .dropoff: String(localized: "Drop-off")
        case .pickup: String(localized: "Pickup")
        }
    }
}

public enum ClaimStatus: String, Codable, Sendable {
    case active
    case released
    case swapRequested
}

public enum ApprovalState: String, Codable, Sendable {
    case pending
    case approved
    case rejected
}

public enum ChoreValueKind: String, Codable, Sendable, CaseIterable {
    case points
    case money
}

public enum MealType: String, Codable, Sendable, CaseIterable, Identifiable {
    case breakfast
    case lunch
    case dinner

    public var id: Self { self }

    public var displayName: String {
        switch self {
        case .breakfast: String(localized: "Breakfast")
        case .lunch: String(localized: "Lunch")
        case .dinner: String(localized: "Dinner")
        }
    }
}

public enum ArriveSafelyState: String, Codable, Sendable {
    case active
    case arrived
    case overdue
    case cancelled
}
