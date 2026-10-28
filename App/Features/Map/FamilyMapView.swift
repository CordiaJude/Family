import SwiftUI
import SwiftData
import MapKit
import FamilyCore
import FamilyData
import FamilyDesign

/// Where everyone is. Phase 1 shows the latest shared snapshots; live
/// location, member details and Arrive Safely arrive in Phase 5.
struct FamilyMapView: View {
    @Query(sort: \Member.sortOrder) private var members: [Member]
    @Query(sort: \LocationSnapshot.timestamp, order: .reverse) private var snapshots: [LocationSnapshot]
    @Query(sort: \Place.name) private var places: [Place]

    @State private var position: MapCameraPosition = .automatic
    @State private var selectedMemberID: UUID?

    private var latestByMember: [UUID: LocationSnapshot] {
        var latest: [UUID: LocationSnapshot] = [:]
        for snapshot in snapshots where latest[snapshot.memberID] == nil {
            latest[snapshot.memberID] = snapshot
        }
        return latest
    }

    /// People who appear on the map: everyone except pets.
    private var people: [Member] { members.filter { !$0.isPet } }

    var body: some View {
        let latest = latestByMember
        Map(position: $position, selection: $selectedMemberID) {
            ForEach(places) { place in
                MapCircle(center: place.coordinate, radius: place.radius)
                    .foregroundStyle(Color.accentColor.opacity(0.08))
                    .stroke(Color.accentColor.opacity(0.25), lineWidth: 1)
                Annotation(place.name, coordinate: place.coordinate, anchor: .center) {
                    Image(systemName: place.symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(6)
                        .background(.background.secondary, in: .circle)
                        .accessibilityLabel(place.name)
                }
                .annotationTitles(.hidden)
            }
            ForEach(people) { member in
                if member.locationSharing == .sharing, let snapshot = latest[member.id] {
                    Annotation(member.firstName, coordinate: snapshot.coordinate, anchor: .bottom) {
                        MemberMapPin(badge: member.badge, isSelected: selectedMemberID == member.id)
                    }
                    .annotationTitles(.hidden)
                    .tag(member.id)
                }
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .safeAreaInset(edge: .bottom) {
            MemberStatusBar(
                people: people,
                latest: latest,
                selection: $selectedMemberID
            )
        }
        .onChange(of: selectedMemberID) { _, id in
            guard let id, let snapshot = latest[id] else { return }
            withAnimation(.smooth) {
                position = .camera(MapCamera(centerCoordinate: snapshot.coordinate, distance: 2_500))
            }
        }
        .sensoryFeedback(.selection, trigger: selectedMemberID)
    }
}

/// A member's avatar pin, ringed in their color.
struct MemberMapPin: View {
    let badge: MemberBadge
    let isSelected: Bool

    var body: some View {
        VStack(spacing: -3) {
            AvatarView(badge, size: isSelected ? .large : .regular)
                .padding(3)
                .background(badge.color.color, in: .circle)
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            Image(systemName: "triangle.fill")
                .font(.system(size: 10))
                .foregroundStyle(badge.color.color)
                .rotationEffect(.degrees(180))
                .accessibilityHidden(true)
        }
        .animation(.snappy, value: isSelected)
    }
}

/// Floating glass chips along the bottom of the map, one per person.
struct MemberStatusBar: View {
    let people: [Member]
    let latest: [UUID: LocationSnapshot]
    @Binding var selection: UUID?

    var body: some View {
        ScrollView(.horizontal) {
            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 10) {
                    ForEach(people) { member in
                        Button {
                            selection = member.id
                        } label: {
                            chip(for: member)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(
                            .regular.tint(selection == member.id ? member.color.color.opacity(0.35) : nil).interactive(),
                            in: .capsule
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .padding(.bottom, 8)
    }

    private func chip(for member: Member) -> some View {
        HStack(spacing: 8) {
            AvatarView(member.badge, size: .regular)
            VStack(alignment: .leading, spacing: 1) {
                Text(member.firstName)
                    .font(.subheadline.weight(.semibold))
                status(for: member)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
        }
        .padding(.leading, 6)
        .padding(.trailing, 14)
        .padding(.vertical, 6)
        .contentShape(.capsule)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func status(for member: Member) -> some View {
        switch member.locationSharing {
        case .paused:
            Label("Location paused", systemImage: "pause.circle")
                .labelStyle(CompactLabelStyle())
        case .off:
            Text("Not sharing")
        case .sharing:
            if let snapshot = latest[member.id] {
                Text("\(snapshot.label) · \(snapshot.timestamp, format: .relative(presentation: .named, unitsStyle: .abbreviated))")
            } else {
                Text("No location yet")
            }
        }
    }
}

extension Place {
    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
}

extension LocationSnapshot {
    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
}

#if DEBUG
#Preview {
    FamilyMapView()
        .modelContainer(SampleHousehold.previewContainer())
}
#endif
