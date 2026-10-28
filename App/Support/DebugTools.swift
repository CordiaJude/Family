#if DEBUG
import Foundation
import SwiftData
import FamilyData

/// DEBUG-only helpers for running without iCloud.
enum DebugTools {
    private static let sampleDayKey = "sampleHouseholdLoadedDay"

    /// Handles DEBUG launch arguments and keeps the sample household current.
    ///
    /// - `-FamilyResetAllData` deletes everything, so onboarding appears.
    /// - `-FamilySampleData` loads The Parkers.
    ///
    /// The sample household's dates are relative to the day it was loaded, so
    /// it's reloaded once a day while it's in use. Otherwise a fresh install
    /// starts with onboarding; choose "Explore with a Sample Family" there to
    /// load The Parkers.
    static func seedSampleDataIfNeeded(in context: ModelContext, session: HouseholdSession) {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-FamilyResetAllData") {
            resetAll(in: context)
        }
        let households = (try? context.fetch(FetchDescriptor<Household>())) ?? []
        let isSample = households.count == 1 && households.first?.id == SampleHousehold.IDs.household
        let loadedDay = UserDefaults.standard.object(forKey: sampleDayKey) as? Date
        let isStale = loadedDay != Calendar.current.startOfDay(for: .now)

        if arguments.contains("-FamilySampleData") || (isSample && isStale) {
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
