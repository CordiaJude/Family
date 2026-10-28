import SwiftUI
import FamilyCore

extension MemberColor {
    /// The member's signature color: a system color, so it adapts to Dark Mode
    /// and Increase Contrast automatically.
    public var color: Color {
        switch self {
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .mint: .mint
        case .teal: .teal
        case .blue: .blue
        case .indigo: .indigo
        case .purple: .purple
        case .pink: .pink
        }
    }

    /// Text drawn on top of a filled member-color shape. Yellow and mint are too
    /// light for white text.
    public var foregroundOnFill: Color {
        switch self {
        case .yellow, .mint: .black.opacity(0.8)
        default: .white
        }
    }
}

/// Everything the design system needs to draw a member, independent of storage.
public struct MemberBadge: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var color: MemberColor
    public var emoji: String?
    public var photo: Data?

    public init(id: UUID, name: String, color: MemberColor, emoji: String? = nil, photo: Data? = nil) {
        self.id = id
        self.name = name
        self.color = color
        self.emoji = emoji
        self.photo = photo
    }

    public var firstName: String {
        name.split(separator: " ").first.map(String.init) ?? name
    }

    public var initials: String { PersonName.initials(of: name) }
}

#if DEBUG
extension MemberBadge {
    public static let sam = MemberBadge(id: UUID(), name: "Sam Parker", color: .blue, emoji: "🧔🏻")
    public static let alex = MemberBadge(id: UUID(), name: "Alex Parker", color: .orange, emoji: "👩🏽")
    public static let emma = MemberBadge(id: UUID(), name: "Emma Parker", color: .purple, emoji: "👧🏼")
    public static let liam = MemberBadge(id: UUID(), name: "Liam Parker", color: .green)
    public static let biscuit = MemberBadge(id: UUID(), name: "Biscuit", color: .yellow, emoji: "🐶")
    public static let parkers: [MemberBadge] = [.sam, .alex, .emma, .liam, .biscuit]
}
#endif
