import SwiftUI
import FamilyCore
import FamilyDesign

/// Edits one family member's draft: name, role, color, avatar, birthday, phone.
struct MemberEditorSheet: View {
    @State var draft: MemberDraft
    let takenColors: Set<MemberColor>
    let isNew: Bool
    let onSave: (MemberDraft) -> Void
    var onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var pickingContact = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        AvatarView(draft.badge, size: .hero, showsRing: true)
                            .animation(.snappy, value: draft.color)
                        if !draft.isPet {
                            Button("Fill from Contacts", systemImage: "person.crop.circle.badge.plus") {
                                pickingContact = true
                            }
                            .buttonStyle(.glass)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }

                Section {
                    TextField(draft.isPet ? "Pet’s name" : "Name", text: $draft.name)
                        .textContentType(draft.isPet ? nil : .name)
                        .font(.title3)
                    if !draft.isPet {
                        Picker("Role", selection: $draft.role) {
                            ForEach(MemberRole.allCases) { Text($0.displayName).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                } footer: {
                    if !draft.isPet {
                        Text(roleExplanation)
                    }
                }

                Section("Color") {
                    MemberColorPicker(selection: $draft.color, taken: takenColors)
                        .padding(.vertical, 4)
                }

                Section("Avatar") {
                    AvatarStylePicker(draft: $draft)
                }

                if !draft.isPet {
                    Section {
                        Toggle("Birthday", isOn: Binding(
                            get: { draft.birthday != nil },
                            set: { draft.birthday = $0 ? (draft.birthday ?? Calendar.current.date(byAdding: .year, value: -10, to: .now)) : nil }
                        ))
                        if let birthday = draft.birthday {
                            DatePicker("Date", selection: Binding(get: { birthday }, set: { draft.birthday = $0 }),
                                       in: ...Date.now, displayedComponents: .date)
                        }
                        TextField("Mobile number", text: $draft.phone)
                            .textContentType(.telephoneNumber)
                            .keyboardType(.phonePad)
                    } footer: {
                        Text("The number is used for “Call” and “Message” buttons, and to send allowance with Apple Cash in Messages.")
                    }
                }

                if let onDelete, !isNew {
                    Section {
                        Button("Remove from Household", role: .destructive) {
                            onDelete()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(isNew ? (draft.isPet ? "Add Pet" : "Add Person") : "Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isNew ? "Add" : "Done") {
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(!draft.isValid)
                }
            }
            .contactPicker(isPresented: $pickingContact) { contacts in
                guard let contact = contacts.first else { return }
                let filled = MemberDraft(contact: contact, color: draft.color)
                draft.name = filled.name
                draft.phone = filled.phone.isEmpty ? draft.phone : filled.phone
                if let birthday = filled.birthday {
                    draft.birthday = birthday
                    draft.role = filled.role
                }
                if let photo = filled.photo {
                    draft.photo = photo
                    draft.avatarKind = .photo
                }
            }
        }
    }

    private var roleExplanation: LocalizedStringKey {
        switch draft.role {
        case .adult: "Adults can manage the household, approve chores and drive."
        case .teen: "Teens can add events. They can only claim rides if an adult allows it."
        case .child: "Children get a simpler view focused on their day, chores and rides."
        }
    }
}
