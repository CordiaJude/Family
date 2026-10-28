import Foundation
import SwiftData
import FamilyCore

@Model
public final class Place: SyncableModel {
    /// Core Location rejects smaller geofences reliably.
    public static let minimumRadius: Double = 100

    @Attribute(.unique) public var id: UUID
    public var householdID: UUID
    public var name: String
    public var latitude: Double
    public var longitude: Double
    public var radius: Double
    public var symbol: String
    /// Stores trigger grocery reminders on arrival.
    public var isStore: Bool

    public var modifiedAt: Date
    public var ckSystemFields: Data?
    public var dirtyFields: [String]

    public init(
        id: UUID = UUID(),
        householdID: UUID,
        name: String,
        latitude: Double,
        longitude: Double,
        radius: Double = 150,
        symbol: String = "mappin",
        isStore: Bool = false
    ) {
        self.id = id
        self.householdID = householdID
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.radius = max(radius, Self.minimumRadius)
        self.symbol = symbol
        self.isStore = isStore
        self.modifiedAt = .now
        self.ckSystemFields = nil
        self.dirtyFields = []
    }
}

/// "Notify <watcher> when <member> arrives at / leaves <place>."
@Model
public final class PlaceAlert: SyncableModel {
    @Attribute(.unique) public var id: UUID
    public var householdID: UUID
    public var memberID: UUID
    public var watcherID: UUID
    public var placeID: UUID
    public var onArrive: Bool
    public var onDepart: Bool

    public var modifiedAt: Date
    public var ckSystemFields: Data?
    public var dirtyFields: [String]

    public init(
        id: UUID = UUID(),
        householdID: UUID,
        memberID: UUID,
        watcherID: UUID,
        placeID: UUID,
        onArrive: Bool = true,
        onDepart: Bool = false
    ) {
        self.id = id
        self.householdID = householdID
        self.memberID = memberID
        self.watcherID = watcherID
        self.placeID = placeID
        self.onArrive = onArrive
        self.onDepart = onDepart
        self.modifiedAt = .now
        self.ckSystemFields = nil
        self.dirtyFields = []
    }
}

/// A member's latest shared position. Only the newest snapshot plus the
/// previous 24 hours are kept; older ones are deleted by their author.
@Model
public final class LocationSnapshot: SyncableModel {
    @Attribute(.unique) public var id: UUID
    public var householdID: UUID
    public var memberID: UUID
    public var latitude: Double
    public var longitude: Double
    public var timestamp: Date
    public var placeID: UUID?
    /// Human label such as "Driving" or "Near Maple Grove".
    public var label: String
    public var isDriving: Bool
    /// 0...1 when the member shares battery level.
    public var batteryLevel: Double?

    public var modifiedAt: Date
    public var ckSystemFields: Data?
    public var dirtyFields: [String]

    public init(
        id: UUID = UUID(),
        householdID: UUID,
        memberID: UUID,
        latitude: Double,
        longitude: Double,
        timestamp: Date = .now,
        placeID: UUID? = nil,
        label: String,
        isDriving: Bool = false,
        batteryLevel: Double? = nil
    ) {
        self.id = id
        self.householdID = householdID
        self.memberID = memberID
        self.latitude = latitude
        self.longitude = longitude
        self.timestamp = timestamp
        self.placeID = placeID
        self.label = label
        self.isDriving = isDriving
        self.batteryLevel = batteryLevel
        self.modifiedAt = timestamp
        self.ckSystemFields = nil
        self.dirtyFields = []
    }
}

@Model
public final class ArriveSafelySession: SyncableModel {
    @Attribute(.unique) public var id: UUID
    public var householdID: UUID
    public var memberID: UUID
    public var destinationName: String
    public var destinationLatitude: Double
    public var destinationLongitude: Double
    public var expectedArrival: Date
    public var startedAt: Date
    public var stateRaw: String

    public var modifiedAt: Date
    public var ckSystemFields: Data?
    public var dirtyFields: [String]

    public init(
        id: UUID = UUID(),
        householdID: UUID,
        memberID: UUID,
        destinationName: String,
        destinationLatitude: Double,
        destinationLongitude: Double,
        expectedArrival: Date,
        startedAt: Date = .now
    ) {
        self.id = id
        self.householdID = householdID
        self.memberID = memberID
        self.destinationName = destinationName
        self.destinationLatitude = destinationLatitude
        self.destinationLongitude = destinationLongitude
        self.expectedArrival = expectedArrival
        self.startedAt = startedAt
        self.stateRaw = ArriveSafelyState.active.rawValue
        self.modifiedAt = startedAt
        self.ckSystemFields = nil
        self.dirtyFields = []
    }

    public var state: ArriveSafelyState {
        get { ArriveSafelyState(rawValue: stateRaw) ?? .active }
        set { stateRaw = newValue.rawValue }
    }
}
