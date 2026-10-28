import Foundation
import SwiftData
import FamilyCore

@Model
public final class Household: SyncableModel {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var createdAt: Date
    public var ownerMemberID: UUID?

    public var modifiedAt: Date
    public var ckSystemFields: Data?
    public var dirtyFields: [String]

    /// A household is its own scope; this mirrors `id` to satisfy SyncableModel.
    public var householdID: UUID { id }

    public init(id: UUID = UUID(), name: String, createdAt: Date = .now, ownerMemberID: UUID? = nil) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.ownerMemberID = ownerMemberID
        self.modifiedAt = createdAt
        self.ckSystemFields = nil
        self.dirtyFields = []
    }
}

@Model
public final class Member: SyncableModel {
    @Attribute(.unique) public var id: UUID
    public var householdID: UUID
    public var name: String
    public var roleRaw: String
    public var colorRaw: String
    public var avatarKindRaw: String
    public var avatarEmoji: String?
    @Attribute(.externalStorage) public var avatarPhoto: Data?
    public var birthday: Date?
    public var phone: String?
    public var locationSharingRaw: String
    /// Teens can drive only when an adult allows it.
    public var canDrive: Bool
    /// Pets and other members without their own device or account.
    public var isPet: Bool
    public var shareBusyTimes: Bool
    /// CloudKit participant user record name, once this member has joined.
    public var participantID: String?
    public var sortOrder: Int

    public var modifiedAt: Date
    public var ckSystemFields: Data?
    public var dirtyFields: [String]

    public init(
        id: UUID = UUID(),
        householdID: UUID,
        name: String,
        role: MemberRole,
        color: MemberColor,
        avatarKind: AvatarKind = .initials,
        avatarEmoji: String? = nil,
        birthday: Date? = nil,
        phone: String? = nil,
        locationSharing: LocationSharingState = .off,
        canDrive: Bool? = nil,
        isPet: Bool = false,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.householdID = householdID
        self.name = name
        self.roleRaw = role.rawValue
        self.colorRaw = color.rawValue
        self.avatarKindRaw = avatarKind.rawValue
        self.avatarEmoji = avatarEmoji
        self.avatarPhoto = nil
        self.birthday = birthday
        self.phone = phone
        self.locationSharingRaw = locationSharing.rawValue
        self.canDrive = canDrive ?? (role == .adult && !isPet)
        self.isPet = isPet
        self.shareBusyTimes = false
        self.participantID = nil
        self.sortOrder = sortOrder
        self.modifiedAt = .now
        self.ckSystemFields = nil
        self.dirtyFields = []
    }

    public var role: MemberRole {
        get { MemberRole(rawValue: roleRaw) ?? .child }
        set { roleRaw = newValue.rawValue }
    }

    public var color: MemberColor {
        get { MemberColor(rawValue: colorRaw) ?? .blue }
        set { colorRaw = newValue.rawValue }
    }

    public var avatarKind: AvatarKind {
        get { AvatarKind(rawValue: avatarKindRaw) ?? .initials }
        set { avatarKindRaw = newValue.rawValue }
    }

    public var locationSharing: LocationSharingState {
        get { LocationSharingState(rawValue: locationSharingRaw) ?? .off }
        set { locationSharingRaw = newValue.rawValue }
    }

    public var initials: String { PersonName.initials(of: name) }

    public var firstName: String {
        name.split(separator: " ").first.map(String.init) ?? name
    }
}
