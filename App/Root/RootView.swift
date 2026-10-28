import SwiftUI
import SwiftData
import FamilyData

struct RootView: View {
    @Environment(HouseholdSession.self) private var session
    @Query private var households: [Household]

    var body: some View {
        @Bindable var session = session
        Group {
            if households.isEmpty {
                OnboardingView()
                    .transition(.opacity)
            } else {
                FamilyTabView()
                    .transition(.opacity)
            }
        }
        .animation(.smooth, value: households.isEmpty)
        .sheet(item: $session.presentedSheet) { sheet in
            switch sheet {
            case .settings:
                SettingsView()
            case .quickAdd(let kind):
                QuickAddPlaceholderSheet(kind: kind)
                    .presentationDetents([.medium, .large])
            }
        }
    }
}

struct FamilyTabView: View {
    @Environment(HouseholdSession.self) private var session

    var body: some View {
        @Bindable var session = session
        TabView(selection: $session.selectedTab) {
            Tab("Today", systemImage: "sun.max", value: AppTab.today) {
                TodayView()
            }
            Tab("Calendar", systemImage: "calendar", value: AppTab.calendar) {
                CalendarView()
            }
            Tab("Map", systemImage: "map", value: AppTab.map) {
                FamilyMapView()
            }
            Tab("Home", systemImage: "house", value: AppTab.home) {
                HomeView()
            }
            Tab(value: AppTab.search, role: .search) {
                SearchView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory {
            NextUpAccessory()
        }
    }
}

#if DEBUG
#Preview {
    RootView()
        .environment(HouseholdSession())
        .modelContainer(SampleHousehold.previewContainer())
}
#endif
