import SwiftUI
import SwiftData
import FamilyCore
import FamilyData
import FamilyDesign

/// First run: welcome, then set up you, your household, your family, Home,
/// and the system connections Family uses.
struct OnboardingView: View {
    @State private var model = OnboardingModel()
    @State private var permissions = PermissionCenter()
    @State private var showingWelcome = true

    var body: some View {
        Group {
            if showingWelcome {
                WelcomeView {
                    withAnimation(.smooth) { showingWelcome = false }
                }
                .transition(.opacity)
            } else {
                NavigationStack(path: $model.path) {
                    YouStep()
                        .navigationDestination(for: OnboardingStep.self) { step in
                            switch step {
                            case .you: YouStep()
                            case .household: HouseholdStep()
                            case .family: FamilyStep()
                            case .home: HomeStep()
                            case .connect: ConnectStep()
                            case .done: DoneStep()
                            }
                        }
                }
                .transition(.opacity)
            }
        }
        .environment(model)
        .environment(permissions)
        .task { await permissions.refresh() }
        #if DEBUG
        .onAppear(perform: jumpToStepForScreenshots)
        #endif
    }

    #if DEBUG
    /// `-FamilyOnboardingStep family` opens a later step with sample answers, for CI screenshots.
    private func jumpToStepForScreenshots() {
        guard let raw = UserDefaults.standard.string(forKey: "FamilyOnboardingStep") else { return }
        let order: [OnboardingStep] = [.household, .family, .home, .connect, .done]
        let target: OnboardingStep? = switch raw {
        case "you": nil
        case "household": .household
        case "family": .family
        case "home": .home
        case "connect": .connect
        case "done": .done
        default: nil
        }
        showingWelcome = raw == "welcome"
        model.me = MemberDraft(name: "Sam Parker", color: .blue, avatarKind: .emoji, emoji: "🧔")
        model.householdName = "The Parkers"
        model.family = [
            MemberDraft(name: "Alex Parker", color: .orange, avatarKind: .emoji, emoji: "👩"),
            MemberDraft(name: "Emma Parker", role: .teen, color: .purple, avatarKind: .emoji, emoji: "👧"),
            MemberDraft(name: "Liam Parker", role: .child, color: .green),
            MemberDraft(name: "Biscuit", role: .child, color: .yellow, avatarKind: .emoji, emoji: "🐶", isPet: true),
        ]
        model.home = HomeDraft(address: "Palo Alto, CA", latitude: 37.4419, longitude: -122.1430)
        if let target, let index = order.firstIndex(of: target) {
            model.path = Array(order[...index])
        }
    }
    #endif
}

// MARK: - Welcome

struct WelcomeView: View {
    let onContinue: () -> Void
    @State private var page = 0
    #if DEBUG
    @Environment(\.modelContext) private var context
    @Environment(HouseholdSession.self) private var session
    #endif

    private struct Page {
        let symbol: String
        let colors: [Color]
        let title: LocalizedStringKey
        let body: LocalizedStringKey
    }

    private let pages = [
        Page(symbol: "person.3.fill", colors: [.purple, .blue, .mint],
             title: "Your Family, in Sync",
             body: "One shared view of everyone’s day, from school runs to dinner plans."),
        Page(symbol: "car.fill", colors: [.orange, .pink],
             title: "Who’s Got It?",
             body: "Claim a pickup with one tap, and everyone knows it’s covered."),
        Page(symbol: "location.fill", colors: [.blue, .teal],
             title: "Everyone Home Safe",
             body: "See where everyone is, on their terms, and know when they arrive."),
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    let item = pages[index]
                    VStack(spacing: 20) {
                        Spacer()
                        Image(systemName: item.symbol)
                            .font(.system(size: 64, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 128, height: 128)
                            .background(LinearGradient(colors: item.colors, startPoint: .topLeading, endPoint: .bottomTrailing), in: .rect(cornerRadius: 32))
                            .shadow(color: item.colors.first?.opacity(0.35) ?? .clear, radius: 20, y: 10)
                            .accessibilityHidden(true)
                        Text(item.title)
                            .font(.largeTitle.bold())
                            .multilineTextAlignment(.center)
                            .accessibilityAddTraits(.isHeader)
                        Text(item.body)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Spacer()
                        Spacer()
                    }
                    .padding(.horizontal, 32)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            VStack(spacing: 10) {
                Button {
                    if page < pages.count - 1 {
                        withAnimation { page += 1 }
                    } else {
                        onContinue()
                    }
                } label: {
                    Text(page < pages.count - 1 ? "Continue" : "Get Started")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .contentTransition(.numericText())
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)

                Label("Your family’s information stays in your iCloud. No ads, no tracking.", systemImage: "lock.fill")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)

                #if DEBUG
                Button("Explore with a Sample Family") {
                    DebugTools.loadSample(in: context, session: session)
                }
                .font(.footnote.weight(.medium))
                #endif
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
            .frame(maxWidth: 560)
        }
    }
}

// MARK: - You

struct YouStep: View {
    @Environment(OnboardingModel.self) private var model
    @State private var pickingContact = false

    var body: some View {
        @Bindable var model = model
        OnboardingPage(
            symbol: "person.crop.circle.fill", tint: model.me.color.color,
            title: "About You",
            subtitle: "This is how your family will see you.",
            canContinue: model.me.isValid
        ) {
            if model.householdName.isEmpty { model.householdName = model.suggestedHouseholdName }
            model.path.append(.household)
        } content: {
            VStack(spacing: 20) {
                AvatarView(model.me.badge, size: .hero, showsRing: true)
                    .animation(.snappy, value: model.me.color)
                Button("Use My Contact Card", systemImage: "person.crop.circle.badge.plus") {
                    pickingContact = true
                }
                .buttonStyle(.glass)

                OnboardingTextField(title: "Your name", text: $model.me.name, contentType: .name)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Your color")
                        .font(.headline)
                    MemberColorPicker(selection: $model.me.color)
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text("Avatar")
                        .font(.headline)
                    AvatarStylePicker(draft: $model.me)
                }
            }
        }
        .contactPicker(isPresented: $pickingContact) { contacts in
            guard let contact = contacts.first else { return }
            let filled = MemberDraft(contact: contact, color: model.me.color)
            model.me.name = filled.name
            model.me.phone = filled.phone
            model.me.birthday = filled.birthday
            if let photo = filled.photo {
                model.me.photo = photo
                model.me.avatarKind = .photo
            }
        }
    }
}

// MARK: - Household

struct HouseholdStep: View {
    @Environment(OnboardingModel.self) private var model

    var body: some View {
        @Bindable var model = model
        OnboardingPage(
            symbol: "house.fill", tint: .orange,
            title: "Name Your Household",
            subtitle: "Everyone in your family will see this name.",
            canContinue: !model.householdName.trimmingCharacters(in: .whitespaces).isEmpty
        ) {
            model.path.append(.family)
        } content: {
            OnboardingTextField(title: "Household name", text: $model.householdName, contentType: .familyName)
        }
    }
}

// MARK: - Family

struct FamilyStep: View {
    @Environment(OnboardingModel.self) private var model
    @State private var pickingContacts = false
    @State private var editing: EditRequest?

    struct EditRequest: Identifiable {
        let draft: MemberDraft
        let isNew: Bool
        var id: UUID { draft.id }
    }

    var body: some View {
        OnboardingPage(
            symbol: "person.3.fill", tint: .purple,
            title: "Add Your Family",
            subtitle: "Add the people and pets you live with. Each person gets their own color.",
            primaryTitle: model.family.isEmpty ? "Skip for Now" : "Continue"
        ) {
            model.path.append(.home)
        } content: {
            VStack(spacing: 16) {
                VStack(spacing: 0) {
                    memberRow(model.me, subtitle: String(localized: "You · \(model.me.role.displayName)"), editable: false)
                    ForEach(model.family) { draft in
                        Divider().padding(.leading, 68)
                        memberRow(draft, subtitle: draft.isPet ? String(localized: "Pet") : draft.role.displayName, editable: true)
                    }
                }
                .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 16))

                GlassEffectContainer(spacing: 10) {
                    VStack(spacing: 10) {
                        Button {
                            pickingContacts = true
                        } label: {
                            Label("Add from Contacts", systemImage: "person.crop.circle.badge.plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glass)
                        .controlSize(.large)
                        HStack(spacing: 10) {
                            Button {
                                editing = EditRequest(draft: model.newDraft(), isNew: true)
                            } label: {
                                Label("Add Someone", systemImage: "plus")
                                    .frame(maxWidth: .infinity)
                            }
                            Button {
                                editing = EditRequest(draft: model.newDraft(isPet: true), isNew: true)
                            } label: {
                                Label("Add a Pet", systemImage: "pawprint.fill")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.glass)
                        .controlSize(.large)
                    }
                }
                Text("Choosing people from Contacts brings in their name, photo, phone number and birthday. Family only sees the contacts you pick.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .contactPicker(isPresented: $pickingContacts, multiple: true) { contacts in
            withAnimation {
                for contact in contacts {
                    model.addFamilyMember(MemberDraft(contact: contact, color: model.nextColor()))
                }
            }
        }
        .sheet(item: $editing) { request in
            MemberEditorSheet(
                draft: request.draft,
                takenColors: Set(model.everyone.filter { $0.id != request.draft.id }.map(\.color)),
                isNew: request.isNew,
                onSave: { saved in
                    withAnimation {
                        if let index = model.family.firstIndex(where: { $0.id == saved.id }) {
                            model.family[index] = saved
                        } else {
                            model.family.append(saved)
                        }
                    }
                },
                onDelete: {
                    withAnimation { model.family.removeAll { $0.id == request.draft.id } }
                }
            )
        }
    }

    @ViewBuilder
    private func memberRow(_ draft: MemberDraft, subtitle: String, editable: Bool) -> some View {
        let content = HStack(spacing: 12) {
            AvatarView(draft.badge, size: .regular)
            VStack(alignment: .leading, spacing: 1) {
                Text(draft.trimmedName)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if editable {
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(.rect)

        if editable {
            Button {
                editing = EditRequest(draft: draft, isNew: false)
            } label: {
                content
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("Edit"))
        } else {
            content
                .accessibilityElement(children: .combine)
        }
    }
}

// MARK: - Done

struct DoneStep: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(HouseholdSession.self) private var session
    @Environment(\.modelContext) private var context
    @State private var finished = false

    var body: some View {
        OnboardingPage(
            symbol: "checkmark.circle.fill", tint: .green,
            title: "You’re All Set",
            subtitle: "\(model.householdName) is ready. Add your first event, list or chore from Today.",
            primaryTitle: "Start Using Family"
        ) {
            finished = true
            model.finish(in: context, session: session)
        } content: {
            AvatarStack(model.everyone.map(\.badge), size: .large, limit: 6)
                .padding(.top, 8)
        }
        .sensoryFeedback(.success, trigger: finished)
        .navigationBarBackButtonHidden(finished)
    }
}

#if DEBUG
#Preview("Onboarding") {
    OnboardingView()
        .environment(HouseholdSession())
        .modelContainer(try! FamilyStore.makeContainer(inMemory: true))
}
#endif
