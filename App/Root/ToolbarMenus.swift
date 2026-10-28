import SwiftUI
import FamilyData
import FamilyDesign

/// Leading toolbar item: the household's avatar stack. Opens a menu with the
/// household, its members and Settings.
struct HouseholdMenu: View {
    @Environment(HouseholdSession.self) private var session
    let household: Household?
    let members: [Member]

    var body: some View {
        Menu {
            Section(household?.name ?? String(localized: "Household")) {
                ForEach(members.filter { !$0.isPet }) { member in
                    Label {
                        Text(member.name)
                        Text(member.role.displayName)
                    } icon: {
                        Image(systemName: member.id == session.currentMemberID ? "person.crop.circle.fill.badge.checkmark" : "person.crop.circle")
                    }
                }
            }
            Button("Settings", systemImage: "gearshape") {
                session.presentedSheet = .settings
            }
        } label: {
            AvatarStack(members.map(\.badge), size: .small, limit: 3)
        }
        .accessibilityLabel(Text("\(household?.name ?? String(localized: "Household")) and Settings"))
    }
}

/// Trailing toolbar item: the "+" quick add menu.
struct QuickAddMenu: View {
    @Environment(HouseholdSession.self) private var session

    var body: some View {
        Menu {
            ForEach(QuickAddKind.allCases) { kind in
                Button {
                    session.presentedSheet = .quickAdd(kind)
                } label: {
                    Label(kind.title, systemImage: kind.symbol)
                }
            }
        } label: {
            Label("Add", systemImage: "plus")
        }
    }
}

/// Stand-in for the add flows built in Phases 2 and 3.
struct QuickAddPlaceholderSheet: View {
    let kind: QuickAddKind
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label {
                    Text("New \(Text(kind.title))")
                } icon: {
                    Image(systemName: kind.symbol)
                }
            } description: {
                Text("Adding items arrives in the next build.")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark", role: .cancel) { dismiss() }
                }
            }
        }
    }
}
