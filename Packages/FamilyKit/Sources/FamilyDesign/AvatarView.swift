import SwiftUI
import UIKit
import FamilyCore

/// A member's circular avatar: photo, emoji on their color, or initials.
public struct AvatarView: View {
    public enum Size: Sendable {
        /// "Added by" marks on list items.
        case mini
        case small
        case regular
        case large
        case hero

        var diameter: CGFloat {
            switch self {
            case .mini: 18
            case .small: 26
            case .regular: 36
            case .large: 56
            case .hero: 96
            }
        }

        var textStyle: Font.TextStyle {
            switch self {
            case .mini: .caption2
            case .small: .caption
            case .regular: .callout
            case .large: .title2
            case .hero: .largeTitle
            }
        }
    }

    let badge: MemberBadge
    let size: Size
    var showsRing: Bool

    @ScaledMetric private var scale: CGFloat = 1

    public init(_ badge: MemberBadge, size: Size = .regular, showsRing: Bool = false) {
        self.badge = badge
        self.size = size
        self.showsRing = showsRing
    }

    private var diameter: CGFloat { size.diameter * min(scale, 1.6) }

    public var body: some View {
        content
            .frame(width: diameter, height: diameter)
            .clipShape(.circle)
            .overlay {
                if showsRing {
                    Circle().strokeBorder(badge.color.color, lineWidth: max(1.5, diameter * 0.06))
                        .padding(-diameter * 0.08)
                }
            }
            .accessibilityElement()
            .accessibilityLabel(badge.firstName)
    }

    @ViewBuilder
    private var content: some View {
        if let data = badge.photo, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else if let emoji = badge.emoji {
            Text(emoji)
                .font(.system(size: diameter * 0.58))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(badge.color.color.opacity(0.22).gradient)
        } else {
            Text(badge.initials)
                .font(.system(size: diameter * 0.4, weight: .semibold, design: .rounded))
                .foregroundStyle(badge.color.foregroundOnFill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(badge.color.color.gradient)
        }
    }
}

/// Overlapping avatars, like the participants row in Messages.
public struct AvatarStack: View {
    let badges: [MemberBadge]
    let size: AvatarView.Size
    let limit: Int

    @Environment(\.colorScheme) private var colorScheme

    public init(_ badges: [MemberBadge], size: AvatarView.Size = .small, limit: Int = 4) {
        self.badges = badges
        self.size = size
        self.limit = limit
    }

    public var body: some View {
        let shown = Array(badges.prefix(limit))
        let overflow = badges.count - shown.count
        HStack(spacing: -size.diameter * 0.3) {
            ForEach(shown) { badge in
                AvatarView(badge, size: size)
                    .padding(1.5)
                    .background(Color(.systemBackground), in: .circle)
            }
            if overflow > 0 {
                Text("+\(overflow)")
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: size.diameter, height: size.diameter)
                    .background(Color(.secondarySystemFill), in: .circle)
                    .padding(1.5)
                    .background(Color(.systemBackground), in: .circle)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ListFormatter.localizedString(byJoining: badges.map(\.firstName)))
    }
}

#if DEBUG
#Preview("Avatars") {
    VStack(spacing: 24) {
        HStack(spacing: 16) {
            ForEach(MemberBadge.parkers) { AvatarView($0, size: .large) }
        }
        HStack(spacing: 16) {
            AvatarView(.liam, size: .hero, showsRing: true)
            AvatarView(.emma, size: .regular)
            AvatarView(.sam, size: .small)
            AvatarView(.alex, size: .mini)
        }
        AvatarStack(MemberBadge.parkers, size: .regular)
        AvatarStack(Array(MemberBadge.parkers.prefix(2)))
    }
    .padding()
}
#endif
