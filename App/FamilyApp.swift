import SwiftUI
import SwiftData
import FamilyData

@main
struct FamilyApp: App {
    let container: ModelContainer
    @State private var session: HouseholdSession

    init() {
        let session = HouseholdSession()
        _session = State(initialValue: session)
        do {
            container = try FamilyStore.makeContainer()
        } catch {
            // The on-disk store couldn't open (for example after an incompatible
            // development schema change). Keep the app usable with an empty store.
            container = try! FamilyStore.makeContainer(inMemory: true)
        }
        #if DEBUG
        DebugTools.seedSampleDataIfNeeded(in: container.mainContext, session: session)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
        }
        .modelContainer(container)
    }
}
