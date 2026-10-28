import SwiftUI
import SwiftData
import FamilyData
import FamilyDesign

/// Settings, opened from the household avatar menu. Phase 1 has the
/// structure; each section is filled in by the phase that owns it.
struct SettingsView: View {
    @Environment(HouseholdSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Member.sortOrder) private var members: [Member]
    @Query private var households: [Household]

    var body: some View {
        NavigationStack {
            Form {
                if let me = session.currentMember(in: members) {
                    Section {
                        HStack(spacing: 14) {
                            AvatarView(me.badge, size: .large)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(me.name)
                                    .font(.headline)
                                Text("\(me.role.displayName) · \(households.first?.name ?? "")")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                        .accessibilityElement(children: .combine)
                    }
                }

                Section("Household") {
                    ForEach(members) { member in
                        Label {
                            LabeledContent(member.name, value: member.isPet ? String(localized: "Pet") : member.role.displayName)
                        } icon: {
                            AvatarView(member.badge, size: .small)
                        }
                    }
                }

                Section {
                    settingsLink("Places", symbol: "mappin.circle.fill", color: .red)
                    settingsLink("Notifications", symbol: "bell.badge.fill", color: .red)
                    settingsLink("Location Sharing", symbol: "location.fill", color: .blue)
                    settingsLink("Calendar Mirroring", symbol: "calendar", color: .red)
                    settingsLink("Chores & Allowance", symbol: "star.fill", color: .orange)
                }

                Section {
                    settingsLink("Privacy", symbol: "hand.raised.fill", color: .blue)
                    settingsLink("iCloud Sync", symbol: "icloud.fill", color: .cyan)
                    settingsLink("About Family", symbol: "info.circle.fill", color: .gray)
                }

                #if DEBUG
                DebugSettingsSection()
                #endif
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func settingsLink(_ title: LocalizedStringKey, symbol: String, color: Color) -> some View {
        NavigationLink {
            ComingSoonView(title: title, symbol: symbol)
        } label: {
            Label {
                Text(title)
            } icon: {
                Image(systemName: symbol)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 29, height: 29)
                    .background(color.gradient, in: .rect(cornerRadius: 7))
            }
        }
    }
}

#if DEBUG
/// Tools for running without iCloud: reload The Parkers, reset, switch user.
struct DebugSettingsSection: View {
    @Environment(HouseholdSession.self) private var session
    @Environment(\.modelContext) private var context
    @Query(sort: \Member.sortOrder) private var members: [Member]
    @State private var confirmingReset = false

    var body: some View {
        @Bindable var session = session
        Section {
            Picker("Use App As", selection: $session.currentMemberID) {
                ForEach(members.filter { !$0.isPet }) { member in
                    Text(member.name).tag(Optional(member.id))
                }
            }
            Button("Load Sample Household") {
                DebugTools.loadSample(in: context, session: session)
            }
            Button("Reset All Data", role: .destructive) {
                confirmingReset = true
            }
            .confirmationDialog("Delete everything on this device?", isPresented: $confirmingReset, titleVisibility: .visible) {
                Button("Reset All Data", role: .destructive) {
                    DebugTools.resetAll(in: context)
                }
            }
        } header: {
            Text("Debug")
        } footer: {
            Text("Only in Debug builds. Location and arrival simulation arrive with the Map in Phase 5.")
        }
    }
}
#endif

#if DEBUG
#Preview {
    SettingsView()
        .environment(HouseholdSession())
        .modelContainer(SampleHousehold.previewContainer())
}
#endif
