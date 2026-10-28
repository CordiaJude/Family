import SwiftUI
import FamilyCore

/// A capsule with a member's avatar and first name, tinted with their color.
/// Used in filter rows and as the "claimed by" state of a ride leg.
public struct MemberChip: View {
    let badge: MemberBadge
    var isSelected: Bool
    var detail: String?

    public init(_ badge: MemberBadge, isSelected: Bool = true, detail: String? = nil) {
        self.badge = badge
        self.isSelected = isSelected
        self.detail = detail
    }

    public var body: some View {
        HStack(spacing: 6) {
            AvatarView(badge, size: .small)
            VStack(alignment: .leading, spacing: 0) {
                Text(badge.firstName)
                    .font(.subheadline.weight(.semibold))
                if let detail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .lineLimit(1)
        }
        .padding(.leading, 4)
        .padding(.trailing, 12)
        .padding(.vertical, 4)
        .background {
            Capsule()
                .fill(isSelected ? badge.color.color.opacity(0.18) : Color(.tertiarySystemFill))
        }
        .overlay {
            Capsule()
                .strokeBorder(isSelected ? badge.color.color.opacity(0.5) : .clear, lineWidth: 1)
        }
        .contentShape(.capsule)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A horizontally scrolling row of selectable member chips (multi-select).
public struct MemberFilterBar: View {
    let members: [MemberBadge]
    @Binding var selection: Set<UUID>

    public init(members: [MemberBadge], selection: Binding<Set<UUID>>) {
        self.members = members
        self._selection = selection
    }

    public var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(members) { member in
                    Button {
                        if selection.contains(member.id) {
                            selection.remove(member.id)
                        } else {
                            selection.insert(member.id)
                        }
                    } label: {
                        MemberChip(member, isSelected: selection.isEmpty || selection.contains(member.id))
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(Text("Shows only events that include \(member.firstName)."))
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
        .scrollIndicators(.hidden)
        .sensoryFeedback(.selection, trigger: selection)
    }
}

#if DEBUG
#Preview("Chips") {
    @Previewable @State var selection: Set<UUID> = [MemberBadge.emma.id]
    VStack(alignment: .leading, spacing: 16) {
        MemberChip(.emma)
        MemberChip(.sam, detail: "Pickup")
        MemberChip(.liam, isSelected: false)
        MemberFilterBar(members: MemberBadge.parkers, selection: $selection)
    }
}
#endif
