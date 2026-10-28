import Foundation
import FamilyData

extension Member {
    /// The display form of this member used by every design-system component.
    public var badge: MemberBadge {
        MemberBadge(
            id: id,
            name: name,
            color: color,
            emoji: avatarKind == .emoji ? avatarEmoji : nil,
            photo: avatarKind == .photo ? avatarPhoto : nil
        )
    }
}
