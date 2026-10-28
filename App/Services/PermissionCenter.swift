import Foundation
import CoreLocation
import EventKit
import UserNotifications
#if SYNC_ENABLED
import CloudKit
#endif

enum PermissionState: Equatable {
    case notDetermined
    case granted
    /// Granted with limits (for example approximate location only).
    case limited
    case denied

    var isGranted: Bool { self == .granted || self == .limited }
}

enum ICloudState: Equatable {
    case checking
    case available
    case noAccount
    case restricted
    case temporarilyUnavailable
    /// Sync isn't built into this configuration yet (no CloudKit entitlement).
    case notConfigured
}

/// Reads and requests the system permissions Family uses. Each request is
/// made only when the person taps the matching button, after an explanation.
@Observable
final class PermissionCenter: NSObject, CLLocationManagerDelegate {
    private(set) var notifications: PermissionState = .notDetermined
    private(set) var location: PermissionState = .notDetermined
    private(set) var calendar: PermissionState = .notDetermined
    private(set) var iCloud: ICloudState = .checking

    @ObservationIgnored private let locationManager = CLLocationManager()
    /// Holds the app's "when in use" authorization goal for its lifetime.
    @ObservationIgnored private var locationSession: CLServiceSession?

    override init() {
        super.init()
        locationManager.delegate = self
        location = Self.state(for: locationManager)
        calendar = Self.state(for: EKEventStore.authorizationStatus(for: .event))
    }

    func refresh() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notifications = Self.state(for: settings.authorizationStatus)
        location = Self.state(for: locationManager)
        calendar = Self.state(for: EKEventStore.authorizationStatus(for: .event))
        iCloud = await Self.iCloudStatus()
    }

    func requestNotifications() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        await refresh()
    }

    /// Starts a "when in use" authorization goal. The system prompt appears the
    /// first time; `locationManagerDidChangeAuthorization` reports the answer.
    func requestLocation() {
        if locationSession == nil {
            locationSession = CLServiceSession(authorization: .whenInUse)
        }
    }

    func requestCalendar() async {
        _ = try? await EKEventStore().requestFullAccessToEvents()
        calendar = Self.state(for: EKEventStore.authorizationStatus(for: .event))
    }

    /// One location fix, for "Use Current Location". Returns nil if denied or unavailable.
    func currentLocation() async -> CLLocation? {
        requestLocation()
        do {
            for try await update in CLLocationUpdate.liveUpdates() {
                if let location = update.location { return location }
                if update.authorizationDenied || update.authorizationDeniedGlobally { return nil }
            }
        } catch {
            return nil
        }
        return nil
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        location = Self.state(for: manager)
    }

    // MARK: Mapping

    private static func state(for manager: CLLocationManager) -> PermissionState {
        switch manager.authorizationStatus {
        case .notDetermined: .notDetermined
        case .restricted, .denied: .denied
        case .authorizedAlways, .authorizedWhenInUse:
            manager.accuracyAuthorization == .reducedAccuracy ? .limited : .granted
        @unknown default: .notDetermined
        }
    }

    private static func state(for status: EKAuthorizationStatus) -> PermissionState {
        switch status {
        case .notDetermined: .notDetermined
        case .fullAccess: .granted
        case .writeOnly: .limited
        case .restricted, .denied: .denied
        @unknown default: .notDetermined
        }
    }

    private static func state(for status: UNAuthorizationStatus) -> PermissionState {
        switch status {
        case .notDetermined: .notDetermined
        case .authorized: .granted
        case .provisional, .ephemeral: .limited
        case .denied: .denied
        @unknown default: .notDetermined
        }
    }

    private static func iCloudStatus() async -> ICloudState {
        #if SYNC_ENABLED
        guard let identifier = Bundle.main.object(forInfoDictionaryKey: "FamilyCloudKitContainer") as? String else {
            return .notConfigured
        }
        do {
            switch try await CKContainer(identifier: identifier).accountStatus() {
            case .available: return .available
            case .noAccount: return .noAccount
            case .restricted: return .restricted
            case .temporarilyUnavailable, .couldNotDetermine: return .temporarilyUnavailable
            @unknown default: return .temporarilyUnavailable
            }
        } catch {
            return .temporarilyUnavailable
        }
        #else
        return .notConfigured
        #endif
    }
}
