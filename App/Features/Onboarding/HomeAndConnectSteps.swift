import SwiftUI
import MapKit
import FamilyCore
import FamilyDesign

// MARK: - Home

struct HomeStep: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(PermissionCenter.self) private var permissions
    @State private var search = PlaceSearch()
    @State private var camera: MapCameraPosition = .automatic
    @State private var locating = false
    @State private var locationFailed = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        @Bindable var search = search
        OnboardingPage(
            symbol: "house.circle.fill", tint: .blue,
            title: "Where’s Home?",
            subtitle: "Home is used for arrival alerts and travel times. Only your household can see it.",
            canContinue: model.home != nil,
            secondary: model.home == nil ? OnboardingSecondaryAction(title: "Skip for Now") { model.path.append(.connect) } : nil
        ) {
            model.path.append(.connect)
        } content: {
            VStack(spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search for your address", text: $search.query)
                        .textContentType(.fullStreetAddress)
                        .focused($searchFocused)
                        .submitLabel(.search)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 14))

                if searchFocused && !search.results.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(search.results, id: \.self) { result in
                            Button {
                                Task { await choose(result) }
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.title).foregroundStyle(.primary)
                                    if !result.subtitle.isEmpty {
                                        Text(result.subtitle)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            if result != search.results.last {
                                Divider().padding(.leading, 14)
                            }
                        }
                    }
                    .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 14))
                }

                Button {
                    Task { await useCurrentLocation() }
                } label: {
                    Label(locating ? "Finding You…" : "Use Current Location", systemImage: "location.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .controlSize(.large)
                .disabled(locating)

                if locationFailed {
                    Text("Family couldn’t get your location. Search for your address instead, or allow location access in Settings.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if let home = model.home {
                    VStack(alignment: .leading, spacing: 8) {
                        Map(position: $camera)
                            .mapStyle(.standard(pointsOfInterest: .excludingAll))
                            .overlay {
                                // A fixed pin at the center: move the map to adjust.
                                Image(systemName: "house.circle.fill")
                                    .font(.system(size: 36))
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, model.me.color.color)
                                    .shadow(radius: 3, y: 2)
                                    .allowsHitTesting(false)
                                    .accessibilityHidden(true)
                            }
                            .onMapCameraChange(frequency: .onEnd) { context in
                                model.home?.latitude = context.region.center.latitude
                                model.home?.longitude = context.region.center.longitude
                            }
                            .frame(height: 240)
                            .clipShape(.rect(cornerRadius: 16))
                            .accessibilityLabel("Map of your home")
                        Label {
                            Text(home.address ?? String(localized: "Pinned location"))
                        } icon: {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        }
                        .font(.subheadline)
                        Text("Drag the map to fine-tune where the pin sits.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
            }
            .animation(.smooth, value: model.home != nil)
        }
        .onAppear {
            if let home = model.home { center(on: home) }
        }
    }

    private func choose(_ result: MKLocalSearchCompletion) async {
        searchFocused = false
        guard let found = await search.resolve(result) else { return }
        let home = HomeDraft(address: found.address, latitude: found.coordinate.latitude, longitude: found.coordinate.longitude)
        model.home = home
        center(on: home)
    }

    private func useCurrentLocation() async {
        locating = true
        locationFailed = false
        defer { locating = false }
        guard let location = await permissions.currentLocation() else {
            locationFailed = true
            return
        }
        let home = HomeDraft(address: nil, latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        model.home = home
        center(on: home)
    }

    private func center(on home: HomeDraft) {
        let coordinate = CLLocationCoordinate2D(latitude: home.latitude, longitude: home.longitude)
        withAnimation {
            camera = .region(MKCoordinateRegion(center: coordinate, latitudinalMeters: 350, longitudinalMeters: 350))
        }
    }
}

// MARK: - Connect

struct ConnectStep: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(PermissionCenter.self) private var permissions
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        OnboardingPage(
            symbol: "link.circle.fill", tint: .indigo,
            title: "Connect Family",
            subtitle: "Turn on what you’d like. Each one is optional, and you can change them any time in Settings."
        ) {
            model.path.append(.done)
        } content: {
            VStack(spacing: 12) {
                PermissionRow(
                    symbol: "bell.badge.fill", color: .red,
                    title: "Notifications",
                    detail: "Know when someone claims a ride, a ride still needs a driver, or someone arrives.",
                    state: permissions.notifications
                ) {
                    Task { await permissions.requestNotifications() }
                }
                PermissionRow(
                    symbol: "location.fill", color: .blue,
                    title: "Location",
                    detail: "Share where you are with your family and get arrival alerts. You can pause sharing any time.",
                    state: permissions.location
                ) {
                    permissions.requestLocation()
                }
                PermissionRow(
                    symbol: "calendar", color: .orange,
                    title: "Calendar",
                    detail: "Warns about ride conflicts using when you’re busy. Event details from your calendars stay private.",
                    state: permissions.calendar
                ) {
                    Task { await permissions.requestCalendar() }
                }
                ICloudRow(state: permissions.iCloud)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // Pick up changes made in the Settings app.
            if phase == .active { Task { await permissions.refresh() } }
        }
    }
}

struct PermissionRow: View {
    let symbol: String
    let color: Color
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    let state: PermissionState
    let request: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(color.gradient, in: .rect(cornerRadius: 9))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                control
                    .padding(.top, 4)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 16))
        .sensoryFeedback(.success, trigger: state.isGranted) { _, granted in granted }
    }

    @ViewBuilder
    private var control: some View {
        switch state {
        case .granted, .limited:
            Label(state == .limited ? "On (limited)" : "On", systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.green)
                .contentTransition(.symbolEffect(.replace))
        case .notDetermined:
            Button("Allow", action: request)
                .buttonStyle(.glass)
                .tint(color)
        case .denied:
            Button("Turn On in Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            .buttonStyle(.glass)
        }
    }
}

struct ICloudRow: View {
    let state: ICloudState

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "icloud.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Color.cyan.gradient, in: .rect(cornerRadius: 9))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("iCloud").font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if state == .available {
                    Label("Connected", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.green)
                        .padding(.top, 4)
                } else if state == .checking {
                    ProgressView().padding(.top, 4)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }

    private var message: LocalizedStringKey {
        switch state {
        case .checking: "Checking your iCloud account…"
        case .available: "Your household is shared with your family through iCloud, end to end."
        case .noAccount: "Sign in to iCloud in the Settings app so Family can share with your household."
        case .restricted: "iCloud is restricted on this device, so Family can’t share with your household."
        case .temporarilyUnavailable: "iCloud isn’t reachable right now. Family will keep everything on this iPhone and share it once iCloud is back."
        case .notConfigured: "Sharing with your family’s devices through iCloud turns on in an upcoming update. Everything you add now will be shared then."
        }
    }
}
