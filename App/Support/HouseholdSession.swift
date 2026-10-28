import SwiftUI
import FamilyData

enum AppTab: String, Hashable, CaseIterable {
    case today, calendar, map, home, search
}

enum QuickAddKind: String, Identifiable, CaseIterable {
    case event, listItem, chore, note

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .event: "Event"
        case .listItem: "List Item"
        case .chore: "Chore"
        case .note: "Note"
        }
    }

    var symbol: String {
        switch self {
        case .event: "calendar.badge.plus"
        case .listItem: "checklist"
        case .chore: "star.circle"
        case .note: "pin"
        }
    }
}

enum AppSheet: Identifiable {
    case settings
    case quickAdd(QuickAddKind)

    var id: String {
        switch self {
        case .settings: "settings"
        case .quickAdd(let kind): "add-\(kind.rawValue)"
        }
    }
}

/// App-wide UI state: who is using this device, the selected tab and any
/// app-level sheet. Injected through the environment.
@Observable
final class HouseholdSession {
    private static let memberKey = "currentMemberID"
    private let defaults: UserDefaults

    /// The member this device belongs to.
    var currentMemberID: UUID? {
        didSet { defaults.set(currentMemberID?.uuidString, forKey: Self.memberKey) }
    }

    var selectedTab: AppTab
    var presentedSheet: AppSheet?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.currentMemberID = defaults.string(forKey: Self.memberKey).flatMap(UUID.init(uuidString:))
        // Lets UI tests and CI screenshots open a specific tab: -FamilyInitialTab calendar
        self.selectedTab = defaults.string(forKey: "FamilyInitialTab").flatMap(AppTab.init(rawValue:)) ?? .today
    }

    func currentMember(in members: [Member]) -> Member? {
        members.first { $0.id == currentMemberID } ?? members.first { $0.role == .adult }
    }
}
