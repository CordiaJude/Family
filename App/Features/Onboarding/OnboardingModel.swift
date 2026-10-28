import SwiftUI
import SwiftData
import FamilyCore
import FamilyData

/// A person being set up during onboarding, before anything is saved.
struct MemberDraft: Identifiable, Hashable {
    var id = UUID()
    var name: String = ""
    var role: MemberRole = .adult
    var color: MemberColor = .blue
    var avatarKind: AvatarKind = .initials
    var emoji: String = "🙂"
    var photo: Data?
    var phone: String = ""
    var birthday: Date?
    var isPet = false

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    var isValid: Bool { !trimmedName.isEmpty }

    /// Guesses a role from a birthday: under 13 is a child, under 18 a teen.
    static func role(forBirthday birthday: Date?, now: Date = .now, calendar: Calendar = .current) -> MemberRole {
        guard let birthday, let age = calendar.dateComponents([.year], from: birthday, to: now).year else { return .adult }
        switch age {
        case ..<13: return .child
        case ..<18: return .teen
        default: return .adult
        }
    }
}

/// The household's home location chosen during onboarding.
struct HomeDraft: Equatable {
    var name: String = String(localized: "Home")
    var address: String?
    var latitude: Double
    var longitude: Double
}

enum OnboardingStep: Hashable {
    case household, you, family, home, connect, done
}

@Observable
final class OnboardingModel {
    /// Order colors are handed out in, chosen so neighbors contrast.
    static let colorOrder: [MemberColor] = [.blue, .orange, .purple, .green, .pink, .teal, .red, .indigo, .mint, .yellow]

    var path: [OnboardingStep] = []
    var householdName = ""
    var me = MemberDraft(color: .blue)
    var family: [MemberDraft] = []
    var home: HomeDraft?

    var everyone: [MemberDraft] { [me] + family }

    /// "The Parkers" from "Sam Parker".
    var suggestedHouseholdName: String {
        guard let last = me.trimmedName.split(separator: " ").last, me.trimmedName.contains(" ") else { return "" }
        return String(localized: "The \(String(last))s")
    }

    func nextColor() -> MemberColor {
        let used = Set(everyone.map(\.color))
        return Self.colorOrder.first { !used.contains($0) } ?? Self.colorOrder[everyone.count % Self.colorOrder.count]
    }

    func addFamilyMember(_ draft: MemberDraft) {
        var draft = draft
        if family.contains(where: { $0.color == draft.color }) || me.color == draft.color {
            draft.color = nextColor()
        }
        family.append(draft)
    }

    func newDraft(isPet: Bool = false) -> MemberDraft {
        MemberDraft(role: isPet ? .child : .adult, color: nextColor(), avatarKind: isPet ? .emoji : .initials,
                    emoji: isPet ? "🐶" : "🙂", isPet: isPet)
    }

    /// Saves the household, members and Home place, and makes `me` this device's member.
    func finish(in context: ModelContext, session: HouseholdSession) {
        let household = Household(name: householdName.trimmingCharacters(in: .whitespacesAndNewlines))
        context.insert(household)

        for (index, draft) in everyone.enumerated() {
            let member = Member(
                id: draft.id,
                householdID: household.id,
                name: draft.trimmedName,
                role: draft.isPet ? .child : draft.role,
                color: draft.color,
                avatarKind: draft.avatarKind,
                avatarEmoji: draft.avatarKind == .emoji ? draft.emoji : nil,
                birthday: draft.birthday,
                phone: draft.phone.isEmpty ? nil : draft.phone,
                isPet: draft.isPet,
                sortOrder: index
            )
            member.avatarPhoto = draft.avatarKind == .photo ? draft.photo : nil
            context.insert(member)
        }
        household.ownerMemberID = me.id

        if let home {
            context.insert(Place(householdID: household.id, name: home.name, latitude: home.latitude,
                                 longitude: home.longitude, radius: 150, symbol: "house.fill"))
        }
        context.insert(FamilyList(householdID: household.id, name: String(localized: "Groceries"), kind: .grocery, color: .green))
        try? context.save()
        session.currentMemberID = me.id
    }
}
