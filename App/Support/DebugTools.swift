#if DEBUG
import Foundation
import SwiftData
import FamilyData

/// DEBUG-only helpers for running without iCloud.
enum DebugTools {
    private static let sampleDayKey = "sampleHouseholdLoadedDay"

    /// Loads The Parkers when the store is empty. The sample household's dates
    /// are relative to the day it was loaded, so it's refreshed once a day to
    /// keep the demo current. Pass `-FamilyResetSampleData` to force a reload.
    static func seedSampleDataIfNeeded(in context: ModelContext, session: HouseholdSession) {
        let defaults = UserDefaults.standard
        let today = Calendar.current.startOfDay(for: .now)
        let households = (try? context.fetch(FetchDescriptor<Household>())) ?? []
        let isSample = households.count == 1 && households.first?.id == SampleHousehold.IDs.household
        let loadedDay = defaults.object(forKey: sampleDayKey) as? Date
        let forced = ProcessInfo.processInfo.arguments.contains("-FamilyResetSampleData")

        if households.isEmpty || forced || (isSample && loadedDay != today) {
            loadSample(in: context, session: session)
        }
    }

    static func loadSample(in context: ModelContext, session: HouseholdSession) {
        SampleHousehold.load(into: context)
        UserDefaults.standard.set(Calendar.current.startOfDay(for: .now), forKey: sampleDayKey)
        if session.currentMemberID == nil || session.currentMemberID.map(isSampleMember) == false {
            session.currentMemberID = SampleHousehold.IDs.sam
        }
    }

    static func resetAll(in context: ModelContext) {
        SampleHousehold.resetAll(in: context)
        UserDefaults.standard.removeObject(forKey: sampleDayKey)
    }

    private static func isSampleMember(_ id: UUID) -> Bool {
        [SampleHousehold.IDs.sam, SampleHousehold.IDs.alex, SampleHousehold.IDs.emma, SampleHousehold.IDs.liam].contains(id)
    }
}
#endif
