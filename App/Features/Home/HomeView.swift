import SwiftUI
import SwiftData
import FamilyCore
import FamilyData
import FamilyDesign

/// Lists, chores, meals and the family board. Phase 1 shows the overview;
/// the detail screens are built in Phase 3.
struct HomeView: View {
    @Query(sort: \Member.sortOrder) private var members: [Member]
    @Query(sort: \FamilyList.sortOrder) private var lists: [FamilyList]
    @Query private var items: [ListItem]
    @Query private var chores: [Chore]
    @Query private var completions: [ChoreCompletion]
    @Query(sort: \MealPlanEntry.date) private var meals: [MealPlanEntry]
    @Query(sort: \BoardNote.sortOrder) private var notes: [BoardNote]

    var body: some View {
        let directory = HouseholdDirectory(members: members, claims: [])
        NavigationStack {
            List {
                Section("Lists") {
                    ForEach(lists) { list in
                        NavigationLink(value: HomeDestination.list(list.id)) {
                            ListRow(list: list, remaining: items.filter { $0.listID == list.id && !$0.isChecked }.count)
                        }
                    }
                }

                Section {
                    ForEach(todaysChores) { chore in
                        NavigationLink(value: HomeDestination.chores) {
                            ChoreSummaryRow(
                                chore: chore,
                                assignee: directory.member(chore.assigneeID)?.badge,
                                isDone: isDoneToday(chore)
                            )
                        }
                    }
                } header: {
                    Text("Today’s Chores")
                }

                if let tonight = meals.first(where: { Calendar.current.isDateInToday($0.date) && $0.mealType == .dinner }) {
                    Section("Dinner Tonight") {
                        NavigationLink(value: HomeDestination.meals) {
                            MealRow(meal: tonight, cook: directory.member(tonight.cookID)?.badge)
                        }
                    }
                }

                Section("Family Board") {
                    ForEach(notes.filter(\.isPinned)) { note in
                        NavigationLink(value: HomeDestination.board) {
                            NoteRow(note: note)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Home")
            .navigationDestination(for: HomeDestination.self) { destination in
                ComingSoonView(title: destination.title, symbol: destination.symbol)
            }
        }
    }

    private var todaysChores: [Chore] {
        let engine = RecurrenceEngine()
        let today = OccurrenceExpander.day(containing: .now)
        return chores
            .filter { !$0.isArchived }
            .filter { chore in
                !engine.occurrences(of: chore.recurrence, seriesStart: chore.startDate, duration: 1, overlapping: today).isEmpty
            }
            .sorted { ($0.dueMinutes ?? 24 * 60) < ($1.dueMinutes ?? 24 * 60) }
    }

    private func isDoneToday(_ chore: Chore) -> Bool {
        completions.contains { $0.choreID == chore.id && Calendar.current.isDateInToday($0.occurrenceDate) }
    }
}

enum HomeDestination: Hashable {
    case list(UUID)
    case chores
    case meals
    case board

    var title: LocalizedStringKey {
        switch self {
        case .list: "Lists"
        case .chores: "Chores"
        case .meals: "Meals"
        case .board: "Family Board"
        }
    }

    var symbol: String {
        switch self {
        case .list: "checklist"
        case .chores: "star.circle"
        case .meals: "fork.knife"
        case .board: "pin"
        }
    }
}

struct ListRow: View {
    let list: FamilyList
    let remaining: Int

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: list.symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(list.color.color.gradient, in: .circle)
                .accessibilityHidden(true)
            Text(list.name)
            Spacer()
            Text(remaining, format: .number)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text("\(remaining) remaining"))
    }
}

struct ChoreSummaryRow: View {
    let chore: Chore
    let assignee: MemberBadge?
    let isDone: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isDone ? AnyShapeStyle(.green) : AnyShapeStyle(.tertiary))
                .contentTransition(.symbolEffect(.replace))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(chore.title)
                    .strikethrough(isDone, color: .secondary)
                HStack(spacing: 6) {
                    if let assignee {
                        AvatarView(assignee, size: .mini)
                        Text(assignee.firstName)
                    }
                    Text(valueText)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(isDone ? Text("Done") : Text("Not done"))
    }

    private var valueText: String {
        switch chore.valueKind {
        case .money: MoneyFormat.string(minorUnits: chore.value)
        case .points: chore.value == 1 ? String(localized: "1 point") : String(localized: "\(chore.value) points")
        }
    }
}

struct MealRow: View {
    let meal: MealPlanEntry
    let cook: MemberBadge?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "fork.knife")
                .foregroundStyle(.orange)
                .frame(width: 32, height: 32)
                .background(.orange.opacity(0.15), in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(meal.title)
                if let cook {
                    Text("\(cook.firstName) is cooking")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct NoteRow: View {
    let note: BoardNote

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: note.symbol)
                .foregroundStyle(note.color.color)
                .frame(width: 32, height: 32)
                .background(note.color.color.opacity(0.15), in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(note.title)
                if note.isSensitive {
                    Label("Locked", systemImage: "lock.fill")
                        .labelStyle(CompactLabelStyle())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(note.body)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Placeholder for screens built in later phases.
struct ComingSoonView: View {
    let title: LocalizedStringKey
    let symbol: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol)
        } description: {
            Text("This screen arrives in the next build.")
        }
        .navigationTitle(title)
    }
}

#if DEBUG
#Preview {
    HomeView()
        .environment(HouseholdSession())
        .modelContainer(SampleHousehold.previewContainer())
}
#endif
