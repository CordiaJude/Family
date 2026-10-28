import SwiftUI
import SwiftData
import FamilyCore
import FamilyData
import FamilyDesign

/// Searches members, events, list items and board notes. Filters, recent
/// searches and chores are added in Phase 3.
struct SearchView: View {
    @Query(sort: \Member.sortOrder) private var members: [Member]
    @Query(sort: \Event.start) private var events: [Event]
    @Query private var items: [ListItem]
    @Query private var lists: [FamilyList]
    @Query private var notes: [BoardNote]
    @Query private var claims: [RideClaim]
    @State private var query = ""

    var body: some View {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let directory = HouseholdDirectory(members: members, claims: claims)
        let matchingMembers = members.filter { matches($0.name, term) }
        let matchingEvents = events.filter { matches($0.title, term) || matches($0.locationName ?? "", term) }
        let matchingItems = items.filter { matches($0.text, term) }
        // Sensitive notes are searchable by title only; their contents stay locked.
        let matchingNotes = notes.filter { matches($0.title, term) || (!$0.isSensitive && matches($0.body, term)) }

        NavigationStack {
            List {
                if term.isEmpty {
                    Section("People") {
                        ForEach(members) { member in
                            Label {
                                Text(member.name)
                            } icon: {
                                AvatarView(member.badge, size: .small)
                            }
                        }
                    }
                } else {
                    if !matchingMembers.isEmpty {
                        Section("People") {
                            ForEach(matchingMembers) { member in
                                Label {
                                    Text(member.name)
                                } icon: {
                                    AvatarView(member.badge, size: .small)
                                }
                            }
                        }
                    }
                    if !matchingEvents.isEmpty {
                        Section("Events") {
                            ForEach(matchingEvents) { event in
                                EventRow(directory.rowModel(for: nextOccurrence(of: event)))
                            }
                        }
                    }
                    if !matchingItems.isEmpty {
                        Section("List Items") {
                            ForEach(matchingItems) { item in
                                LabeledContent(item.text, value: lists.first { $0.id == item.listID }?.name ?? "")
                            }
                        }
                    }
                    if !matchingNotes.isEmpty {
                        Section("Family Board") {
                            ForEach(matchingNotes) { NoteRow(note: $0) }
                        }
                    }
                }
            }
            .overlay {
                if !term.isEmpty && matchingMembers.isEmpty && matchingEvents.isEmpty && matchingItems.isEmpty && matchingNotes.isEmpty {
                    ContentUnavailableView.search(text: term)
                }
            }
            .navigationTitle("Search")
            .searchable(text: $query, prompt: "Events, lists, notes and people")
        }
    }

    private func matches(_ text: String, _ term: String) -> Bool {
        !term.isEmpty && text.localizedStandardContains(term)
    }

    /// The next upcoming occurrence of an event, or its first one.
    private func nextOccurrence(of event: Event) -> EventOccurrence {
        let start = RecurrenceEngine().nextOccurrence(of: event.recurrence, seriesStart: event.start, onOrAfter: Calendar.current.startOfDay(for: .now)) ?? event.start
        return EventOccurrence(event: event, occurrenceDate: start, start: start,
                               end: start.addingTimeInterval(event.duration),
                               title: event.title, locationName: event.locationName)
    }
}

#if DEBUG
#Preview {
    SearchView()
        .modelContainer(SampleHousehold.previewContainer())
}
#endif
