import SwiftUI
import FamilyCore
import FamilyDesign

/// An optional plain button under the primary one, such as "Skip for Now".
struct OnboardingSecondaryAction {
    let title: LocalizedStringKey
    let action: () -> Void
}

/// The standard onboarding page: a large symbol, title and one sentence, the
/// page's content, and a prominent glass button pinned to the bottom.
struct OnboardingPage<Content: View>: View {
    let symbol: String
    let tint: Color
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    var primaryTitle: LocalizedStringKey = "Continue"
    var canContinue = true
    var secondary: OnboardingSecondaryAction?
    let primaryAction: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 12) {
                    Image(systemName: symbol)
                        .font(.system(size: 56, weight: .medium))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(tint)
                        .accessibilityHidden(true)
                    Text(title)
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    Text(subtitle)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 8)
                content
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 6) {
                Button(action: primaryAction) {
                    Text(primaryTitle)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .disabled(!canContinue)
                if let secondary {
                    Button(secondary.title, action: secondary.action)
                        .font(.subheadline.weight(.medium))
                        .padding(.vertical, 8)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
            .frame(maxWidth: 560)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// A rounded text field in the style of Apple's setup screens.
struct OnboardingTextField: View {
    let title: LocalizedStringKey
    @Binding var text: String
    var contentType: UITextContentType?

    var body: some View {
        TextField(title, text: $text)
            .textContentType(contentType)
            .font(.title3)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 14))
    }
}

/// Circles of the member palette; the selected color gets a ring and a check.
struct MemberColorPicker: View {
    @Binding var selection: MemberColor
    /// Colors other members already use, drawn dimmed but still selectable.
    var taken: Set<MemberColor> = []

    private let columns = [GridItem(.adaptive(minimum: 44), spacing: 12)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(MemberColor.allCases) { color in
                Button {
                    selection = color
                } label: {
                    Circle()
                        .fill(color.color.gradient)
                        .frame(width: 36, height: 36)
                        .overlay {
                            if selection == color {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(color.foregroundOnFill)
                            }
                        }
                        .padding(4)
                        .overlay {
                            Circle().strokeBorder(selection == color ? color.color : .clear, lineWidth: 2.5)
                        }
                        .opacity(taken.contains(color) && selection != color ? 0.35 : 1)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(color.displayName)
                .accessibilityAddTraits(selection == color ? .isSelected : [])
                .accessibilityHint(taken.contains(color) ? Text("Already used by someone else") : Text(""))
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// A row of avatar choices: photo (when one exists), emoji, or initials.
struct AvatarStylePicker: View {
    @Binding var draft: MemberDraft

    static let peopleEmoji = ["🙂", "😎", "🤓", "🥳", "😄", "🧑", "👩", "👨", "👧", "👦", "👵", "👴", "🧔", "👩‍🦰", "🧑‍🦱", "👱"]
    static let petEmoji = ["🐶", "🐱", "🐰", "🐹", "🐠", "🐦", "🐢", "🦎", "🐴", "🐷"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Avatar", selection: $draft.avatarKind) {
                if draft.photo != nil {
                    Text("Photo").tag(AvatarKind.photo)
                }
                Text("Emoji").tag(AvatarKind.emoji)
                if !draft.isPet {
                    Text("Initials").tag(AvatarKind.initials)
                }
            }
            .pickerStyle(.segmented)

            if draft.avatarKind == .emoji {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(draft.isPet ? Self.petEmoji : Self.peopleEmoji, id: \.self) { emoji in
                            Button {
                                draft.emoji = emoji
                            } label: {
                                Text(emoji)
                                    .font(.title)
                                    .frame(width: 48, height: 48)
                                    .background(
                                        draft.emoji == emoji ? draft.color.color.opacity(0.25) : Color(.secondarySystemBackground),
                                        in: .circle
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(draft.emoji == emoji ? .isSelected : [])
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
    }
}

extension MemberDraft {
    var badge: MemberBadge {
        MemberBadge(
            id: id,
            name: trimmedName.isEmpty ? (isPet ? String(localized: "Pet") : "?") : trimmedName,
            color: color,
            emoji: avatarKind == .emoji ? emoji : nil,
            photo: avatarKind == .photo ? photo : nil
        )
    }
}
