import SwiftUI
import FamilyCore

/// The floating "I've got it" control for one leg of a ride.
///
/// Unclaimed, it's an interactive glass capsule tinted with the viewer's color.
/// Claimed, the same glass morphs into the claimer's avatar chip. With Reduce
/// Motion the change is a simple cross-fade.
public struct ClaimLegButton: View {
    let leg: RideLeg
    let claimer: MemberBadge?
    let me: MemberBadge
    let action: () -> Void

    @Namespace private var glassNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// - Parameter action: Called inside an animation when tapped. Claims the
    ///   leg when unclaimed, or releases it when `me` is the claimer.
    public init(leg: RideLeg, claimer: MemberBadge?, me: MemberBadge, action: @escaping () -> Void) {
        self.leg = leg
        self.claimer = claimer
        self.me = me
        self.action = action
    }

    private var isMine: Bool { claimer?.id == me.id }

    public var body: some View {
        GlassEffectContainer(spacing: 12) {
            Button {
                withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .bouncy) {
                    action()
                }
            } label: {
                label
                    .padding(.vertical, 8)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .contentShape(.capsule)
            }
            .buttonStyle(.plain)
            .disabled(claimer != nil && !isMine)
            .glassEffect(glass, in: .capsule)
            .glassEffectID(leg, in: glassNamespace)
        }
        .sensoryFeedback(.success, trigger: claimer?.id) { _, new in new != nil }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }

    private var glass: Glass {
        if let claimer {
            .regular.tint(claimer.color.color.opacity(0.25))
        } else {
            .regular.tint(me.color.color).interactive()
        }
    }

    @ViewBuilder
    private var label: some View {
        if let claimer {
            HStack(spacing: 6) {
                AvatarView(claimer, size: .small)
                VStack(alignment: .leading, spacing: 0) {
                    Text(leg.displayName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(isMine ? String(localized: "You") : claimer.firstName)
                        .font(.subheadline.weight(.semibold))
                }
            }
            .transition(.opacity)
        } else {
            Label {
                Text("I’ve got the \(leg.displayName.lowercased())")
            } icon: {
                Image(systemName: leg == .dropoff ? "car.side.arrowtriangle.up.fill" : "car.side.arrowtriangle.down.fill")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(me.color.foregroundOnFill)
            .transition(.opacity)
        }
    }

    private var accessibilityLabel: Text {
        if let claimer {
            Text("\(leg.displayName), \(isMine ? String(localized: "you") : claimer.firstName) has it")
        } else {
            Text("\(leg.displayName) needs a driver")
        }
    }

    private var accessibilityHint: Text {
        if claimer == nil { return Text("Claims this leg for you and lets the family know.") }
        if isMine { return Text("Releases this leg so someone else can take it.") }
        return Text("")
    }
}

#if DEBUG
#Preview("Claim buttons") {
    @Previewable @State var dropoff: MemberBadge? = nil
    @Previewable @State var pickup: MemberBadge? = .sam
    VStack(spacing: 24) {
        HStack {
            ClaimLegButton(leg: .dropoff, claimer: dropoff, me: .alex) {
                dropoff = dropoff == nil ? .alex : nil
            }
            ClaimLegButton(leg: .pickup, claimer: pickup, me: .alex) {
                pickup = pickup == nil ? .alex : nil
            }
        }
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
#endif
