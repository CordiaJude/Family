#if DEBUG
import Foundation
import SwiftData
import FamilyCore

/// "The Parkers": a realistic week of family life for previews and the
/// Simulator. Every date is relative to `now`, so the data always looks current.
public enum SampleHousehold {
    public enum IDs {
        public static let household = UUID(uuidString: "0A000000-0000-4000-8000-000000000001")!
        public static let sam = UUID(uuidString: "0B000000-0000-4000-8000-000000000001")!
        public static let alex = UUID(uuidString: "0B000000-0000-4000-8000-000000000002")!
        public static let emma = UUID(uuidString: "0B000000-0000-4000-8000-000000000003")!
        public static let liam = UUID(uuidString: "0B000000-0000-4000-8000-000000000004")!
        public static let biscuit = UUID(uuidString: "0B000000-0000-4000-8000-000000000005")!
        public static let groceryList = UUID(uuidString: "0C000000-0000-4000-8000-000000000001")!
        public static let home = UUID(uuidString: "0D000000-0000-4000-8000-000000000001")!
    }

    /// An in-memory container filled with the sample household, for previews.
    @MainActor
    public static func previewContainer(now: Date = .now) -> ModelContainer {
        do {
            let container = try FamilyStore.makeContainer(inMemory: true)
            load(into: container.mainContext, now: now)
            return container
        } catch {
            fatalError("Could not create preview container: \(error)")
        }
    }

    /// Deletes every record and inserts the sample household.
    @MainActor
    public static func load(into context: ModelContext, now: Date = .now, calendar: Calendar = .current) {
        resetAll(in: context)
        var builder = Builder(context: context, now: now, calendar: calendar)
        builder.build()
        try? context.save()
    }

    @MainActor
    public static func resetAll(in context: ModelContext) {
        for model in FamilySchemaV1.models {
            try? context.delete(model: model)
        }
        try? context.save()
    }
}

private struct Builder {
    let context: ModelContext
    let now: Date
    let calendar: Calendar
    let hh = SampleHousehold.IDs.household
    typealias ID = SampleHousehold.IDs

    var places: [String: UUID] = [:]
    var coordinates: [String: (Double, Double)] = [:]

    init(context: ModelContext, now: Date, calendar: Calendar) {
        self.context = context
        self.now = now
        self.calendar = calendar
    }

    var today: Date { calendar.startOfDay(for: now) }

    func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: today)!
    }

    func at(_ dayOffset: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day(dayOffset))!
    }

    /// The first `weekday` on or after the date `daysBack` days ago, at the given time.
    func firstWeekday(_ weekday: Weekday, daysBack: Int, hour: Int, minute: Int = 0) -> Date {
        var date = day(-daysBack)
        while calendar.component(.weekday, from: date) != weekday.rawValue {
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date)!
    }

    mutating func build() {
        buildHousehold()
        buildPlaces()
        buildEvents()
        buildLists()
        buildChores()
        buildMeals()
        buildBoard()
        buildLocations()
    }

    // MARK: Household

    func buildHousehold() {
        context.insert(Household(id: hh, name: "The Parkers", createdAt: day(-120), ownerMemberID: ID.sam))
        let members = [
            Member(id: ID.sam, householdID: hh, name: "Sam Parker", role: .adult, color: .blue,
                   avatarKind: .emoji, avatarEmoji: "🧔🏻", phone: "+1 (555) 010-2001",
                   locationSharing: .sharing, sortOrder: 0),
            Member(id: ID.alex, householdID: hh, name: "Alex Parker", role: .adult, color: .orange,
                   avatarKind: .emoji, avatarEmoji: "👩🏽", phone: "+1 (555) 010-2002",
                   locationSharing: .sharing, sortOrder: 1),
            Member(id: ID.emma, householdID: hh, name: "Emma Parker", role: .teen, color: .purple,
                   avatarKind: .emoji, avatarEmoji: "👧🏼", birthday: calendar.date(byAdding: .year, value: -15, to: day(-40)),
                   phone: "+1 (555) 010-2003", locationSharing: .sharing, canDrive: false, sortOrder: 2),
            Member(id: ID.liam, householdID: hh, name: "Liam Parker", role: .child, color: .green,
                   avatarKind: .emoji, avatarEmoji: "👦🏻", birthday: calendar.date(byAdding: .year, value: -9, to: day(75)),
                   locationSharing: .sharing, sortOrder: 3),
            Member(id: ID.biscuit, householdID: hh, name: "Biscuit", role: .child, color: .yellow,
                   avatarKind: .emoji, avatarEmoji: "🐶", isPet: true, sortOrder: 4),
        ]
        members.forEach(context.insert)
    }

    // MARK: Places (around Palo Alto, CA)

    mutating func buildPlaces() {
        let list: [(String, Double, Double, Double, String, Bool, UUID?)] = [
            ("Home", 37.4419, -122.1430, 120, "house.fill", false, ID.home),
            ("Lincoln High", 37.4363, -122.1290, 200, "graduationcap.fill", false, nil),
            ("Maple Elementary", 37.4461, -122.1535, 150, "backpack.fill", false, nil),
            ("Riverside Park", 37.4510, -122.1180, 200, "soccerball", false, nil),
            ("Aquatic Center", 37.4285, -122.1395, 120, "figure.pool.swim", false, nil),
            ("Trader Joe’s", 37.4390, -122.1600, 100, "cart.fill", true, nil),
            ("Paws Vet Clinic", 37.4330, -122.1505, 100, "pawprint.fill", false, nil),
            ("Sam’s Office", 37.4440, -122.1610, 150, "building.2.fill", false, nil),
        ]
        for (name, lat, lon, radius, symbol, isStore, fixedID) in list {
            let place = Place(id: fixedID ?? UUID(), householdID: hh, name: name, latitude: lat, longitude: lon,
                              radius: radius, symbol: symbol, isStore: isStore)
            places[name] = place.id
            coordinates[name] = (lat, lon)
            context.insert(place)
        }
    }

    // MARK: Events

    func buildEvents() {
        func event(
            _ title: String, _ start: Date, minutes: Int, at place: String? = nil, address: String? = nil,
            repeats: RecurrenceRule? = nil, who: [UUID], dropoff: Bool = false, pickup: Bool = false,
            notes: String = "", allDay: Bool = false, by creator: UUID = ID.alex
        ) -> Event {
            let coordinate = place.flatMap { coordinates[$0] }
            let e = Event(
                householdID: hh, title: title, start: start,
                end: start.addingTimeInterval(TimeInterval(minutes * 60)),
                isAllDay: allDay, locationName: place, locationAddress: address,
                latitude: coordinate?.0, longitude: coordinate?.1,
                recurrence: repeats, attendeeIDs: who, needsDropoff: dropoff, needsPickup: pickup,
                notes: notes, reminderOffsets: [30], createdByID: creator
            )
            context.insert(e)
            return e
        }

        func claim(_ e: Event, _ occurrence: Date, _ leg: RideLeg, _ member: UUID, hoursAgo: Double = 20) {
            context.insert(RideClaim(householdID: hh, eventID: e.id, occurrenceDate: occurrence, leg: leg,
                                     memberID: member, claimedAt: now.addingTimeInterval(-hoursAgo * 3600)))
        }

        // Recurring activities.
        let soccerStart = firstWeekday(.tuesday, daysBack: 28, hour: 17)
        let soccer = event("Soccer practice", soccerStart, minutes: 90, at: "Riverside Park",
                           repeats: .weekly(on: [.tuesday, .thursday]), who: [ID.emma], pickup: true,
                           notes: "Bring shin guards and a full water bottle.")
        let swimStart = firstWeekday(.monday, daysBack: 28, hour: 16)
        let swim = event("Swim team", swimStart, minutes: 60, at: "Aquatic Center",
                         repeats: .weekly(on: [.monday, .wednesday]), who: [ID.liam], dropoff: true, pickup: true)
        let piano = event("Piano lesson", firstWeekday(.friday, daysBack: 28, hour: 15, minute: 45), minutes: 45,
                          address: "212 Hamilton Ave", repeats: .weekly(on: [.friday]), who: [ID.liam], dropoff: true)
        _ = event("Book club", firstWeekday(.thursday, daysBack: 28, hour: 19, minute: 30), minutes: 120,
                  address: "Maria’s house", repeats: RecurrenceRule(frequency: .monthly, weekdays: [.thursday], monthlyOrdinal: -1),
                  who: [ID.sam], by: ID.sam)

        // Claims for this week's recurring legs.
        let engine = RecurrenceEngine(calendar: calendar)
        let week = DateInterval(start: day(-1), end: day(7))
        for (index, occurrence) in engine.occurrences(of: soccer.recurrence, seriesStart: soccer.start, duration: soccer.duration, overlapping: week).enumerated() where index.isMultiple(of: 2) {
            claim(soccer, occurrence, .pickup, ID.sam)
        }
        for occurrence in engine.occurrences(of: swim.recurrence, seriesStart: swim.start, duration: swim.duration, overlapping: week) {
            claim(swim, occurrence, .dropoff, ID.alex)
        }
        if let nextPiano = engine.nextOccurrence(of: piano.recurrence, seriesStart: piano.start, onOrAfter: today) {
            claim(piano, nextPiano, .dropoff, ID.alex)
        }

        // Today: an unclaimed pickup and a deliberate double booking for Alex.
        let study = event("Study group", at(0, 14, 30), minutes: 90, address: "Palo Alto Library",
                          who: [ID.emma], pickup: true, by: ID.emma)
        claim(study, study.start, .pickup, ID.alex, hoursAgo: 5)
        let haircut = event("Haircut", at(0, 16), minutes: 30, address: "Snip Kids, 340 California Ave",
                            who: [ID.liam], dropoff: true)
        claim(haircut, haircut.start, .dropoff, ID.alex, hoursAgo: 3)
        _ = event("Playdate at Noah’s", at(0, 17), minutes: 90, address: "48 Waverley St",
                  who: [ID.liam], pickup: true, notes: "Noah’s mom: Priya, (555) 010-3381")

        // The rest of the week.
        _ = event("Dentist", at(2, 15, 30), minutes: 45, address: "Bright Smiles Dental",
                  who: [ID.emma, ID.alex], notes: "Six-month cleaning.")
        _ = event("Vet checkup", at(3, 9), minutes: 30, at: "Paws Vet Clinic",
                  who: [ID.biscuit, ID.sam], notes: "Annual shots. Bring the vaccine card.", by: ID.sam)
        _ = event("Fall concert", at(4, 18, 30), minutes: 60, at: "Maple Elementary",
                  who: [ID.sam, ID.alex, ID.emma, ID.liam], dropoff: true,
                  notes: "Liam needs to be there by 6:00 in a white shirt.")
        _ = event("Dinner at Grandma’s", at(5, 17), minutes: 180, address: "1120 Oak Knoll Dr",
                  who: [ID.sam, ID.alex, ID.emma, ID.liam, ID.biscuit])
        _ = event("Early dismissal", day(1), minutes: 24 * 60, at: "Maple Elementary",
                  who: [ID.liam], notes: "School ends at 12:30.", allDay: true)
        _ = event("Parent–teacher conference", at(6, 8, 15), minutes: 30, at: "Lincoln High",
                  who: [ID.alex, ID.emma])
    }

    // MARK: Lists

    func buildLists() {
        let grocery = FamilyList(id: ID.groceryList, householdID: hh, name: "Groceries", kind: .grocery, color: .green, sortOrder: 0)
        let camping = FamilyList(householdID: hh, name: "Camping Trip", kind: .packing, color: .orange, sortOrder: 1)
        let todos = FamilyList(householdID: hh, name: "Weekend To-Dos", kind: .todo, color: .blue, sortOrder: 2)
        [grocery, camping, todos].forEach(context.insert)

        let groceries: [(String, Double?, String?, GrocerySection, UUID, Bool)] = [
            ("Bananas", nil, nil, .produce, ID.liam, false),
            ("Baby spinach", nil, nil, .produce, ID.alex, false),
            ("Avocados", 3, nil, .produce, ID.alex, false),
            ("Honeycrisp apples", nil, nil, .produce, ID.emma, true),
            ("Milk", 2, "gallons", .dairy, ID.sam, false),
            ("Greek yogurt", nil, nil, .dairy, ID.emma, false),
            ("Shredded cheddar", nil, nil, .dairy, ID.alex, true),
            ("Chicken thighs", 2, "lb", .meat, ID.alex, false),
            ("Sourdough bread", nil, nil, .bakery, ID.sam, false),
            ("Frozen peas", nil, nil, .frozen, ID.alex, false),
            ("Waffles", nil, nil, .frozen, ID.liam, false),
            ("Pasta", 2, "boxes", .pantry, ID.alex, false),
            ("Peanut butter", nil, nil, .pantry, ID.liam, true),
            ("Dog food", nil, nil, .household, ID.sam, false),
            ("Paper towels", nil, nil, .household, ID.alex, false),
            ("Toothpaste", nil, nil, .personalCare, ID.emma, false),
        ]
        for (index, item) in groceries.enumerated() {
            let entry = ListItem(householdID: hh, listID: grocery.id, text: item.0, quantity: item.1, unit: item.2,
                                 section: item.3, addedByID: item.4,
                                 addedAt: now.addingTimeInterval(-Double(index) * 2_700), sortOrder: index)
            if item.5 { entry.setChecked(true, by: ID.sam, at: now.addingTimeInterval(-3_600)) }
            entry.dirtyFields = []
            context.insert(entry)
        }

        let packing = ["Tent", "Sleeping bags", "Headlamps", "Camp stove", "Marshmallows", "Bug spray", "Rain jackets"]
        for (index, text) in packing.enumerated() {
            let entry = ListItem(householdID: hh, listID: camping.id, text: text, addedByID: ID.sam, sortOrder: index)
            if index < 2 { entry.setChecked(true, by: ID.emma) }
            entry.dirtyFields = []
            context.insert(entry)
        }

        let chores = [("Fix the garden gate latch", ID.sam), ("Return library books", ID.emma), ("Book Liam’s haircut", ID.alex), ("Clean out the garage", ID.sam)]
        for (index, item) in chores.enumerated() {
            context.insert(ListItem(householdID: hh, listID: todos.id, text: item.0, addedByID: item.1, sortOrder: index))
        }
    }

    // MARK: Chores and allowance

    func buildChores() {
        let feed = Chore(householdID: hh, title: "Feed Biscuit", symbol: "pawprint.fill", assigneeID: ID.liam,
                         recurrence: .daily, startDate: day(-30), valueKind: .money, value: 50, dueMinutes: 7 * 60 + 30)
        let bed = Chore(householdID: hh, title: "Make your bed", symbol: "bed.double.fill", assigneeID: ID.liam,
                        recurrence: .daily, startDate: day(-30), valueKind: .points, value: 1, dueMinutes: 8 * 60)
        let dishes = Chore(householdID: hh, title: "Empty the dishwasher", symbol: "dishwasher.fill", assigneeID: ID.emma,
                           recurrence: .daily, startDate: day(-30), valueKind: .money, value: 100, dueMinutes: 19 * 60)
        let trash = Chore(householdID: hh, title: "Take out trash & recycling", symbol: "trash.fill", assigneeID: ID.emma,
                          recurrence: .weekly(on: [.thursday]), startDate: day(-30), valueKind: .money, value: 200,
                          dueMinutes: 20 * 60, requiresPhotoProof: true)
        let walk = Chore(householdID: hh, title: "Walk Biscuit", symbol: "figure.walk", assigneeID: ID.emma,
                         recurrence: .weekly(on: [.saturday, .sunday]), startDate: day(-30), valueKind: .money, value: 300)
        [feed, bed, dishes, trash, walk].forEach(context.insert)

        // Liam has fed Biscuit four days running (a streak) and today too.
        for offset in -4...0 {
            let completion = ChoreCompletion(householdID: hh, choreID: feed.id, occurrenceDate: day(offset),
                                             memberID: ID.liam, completedAt: at(offset, 7, 20),
                                             approval: offset == 0 ? .pending : .approved)
            if offset < 0 {
                completion.approvedByID = ID.alex
                context.insert(AllowanceEntry(householdID: hh, memberID: ID.liam, amountMinor: 50,
                                              reason: "Feed Biscuit", date: at(offset, 7, 20), completionID: completion.id))
            }
            context.insert(completion)
        }
        for offset in [-3, -2] {
            context.insert(ChoreCompletion(householdID: hh, choreID: bed.id, occurrenceDate: day(offset),
                                           memberID: ID.liam, completedAt: at(offset, 7, 50), approval: .approved))
        }
        let dishesDone = ChoreCompletion(householdID: hh, choreID: dishes.id, occurrenceDate: day(-1),
                                         memberID: ID.emma, completedAt: at(-1, 18, 40))
        context.insert(dishesDone)
        for offset in [-3, -2] {
            let done = ChoreCompletion(householdID: hh, choreID: dishes.id, occurrenceDate: day(offset),
                                       memberID: ID.emma, completedAt: at(offset, 18, 30), approval: .approved)
            done.approvedByID = ID.sam
            context.insert(done)
            context.insert(AllowanceEntry(householdID: hh, memberID: ID.emma, amountMinor: 100,
                                          reason: "Empty the dishwasher", date: done.completedAt, completionID: done.id))
        }

        // Last week's allowance was paid out.
        context.insert(AllowanceEntry(householdID: hh, memberID: ID.emma, amountMinor: -1_200, reason: "Paid",
                                      date: day(-6), isPaid: true))
        context.insert(AllowanceEntry(householdID: hh, memberID: ID.liam, amountMinor: -350, reason: "Paid",
                                      date: day(-6), isPaid: true))
    }

    // MARK: Meals

    func buildMeals() {
        let dinners: [(String, UUID?, [String], String?)] = [
            ("Sheet-pan chicken & veggies", ID.alex, ["Chicken thighs", "Baby carrots", "Red potatoes", "Olive oil"], nil),
            ("Tacos", ID.sam, ["Ground beef", "Tortillas", "Shredded cheddar", "Salsa", "Avocados"], nil),
            ("Pasta night", ID.emma, ["Pasta", "Marinara sauce", "Parmesan", "Baby spinach"], nil),
            ("Leftovers", nil, [], nil),
            ("Homemade pizza", ID.sam, ["Pizza dough", "Mozzarella", "Pepperoni", "Marinara sauce"],
             "https://www.example.com/recipes/homemade-pizza"),
            ("Dinner at Grandma’s", nil, [], nil),
            ("Salmon, rice & green beans", ID.alex, ["Salmon fillets", "Jasmine rice", "Green beans", "Lemons"], nil),
        ]
        for (offset, dinner) in dinners.enumerated() {
            context.insert(MealPlanEntry(householdID: hh, date: day(offset), title: dinner.0,
                                         recipeURL: dinner.3, ingredients: dinner.2, cookID: dinner.1))
        }
    }

    // MARK: Board

    func buildBoard() {
        let notes = [
            BoardNote(householdID: hh, title: "Wi-Fi", body: "Network: Parkers-Home\nPassword: biscuit-loves-walks-42",
                      symbol: "wifi", color: .blue, isPinned: true, isSensitive: true, sortOrder: 0),
            BoardNote(householdID: hh, title: "Babysitter", body: "Maya Chen\n(555) 010-4412\nAvailable weeknights after 5.",
                      symbol: "person.crop.circle.badge.checkmark", color: .pink, isPinned: true, sortOrder: 1),
            BoardNote(householdID: hh, title: "Garage code", body: "4417 then #",
                      symbol: "door.garage.closed", color: .orange, isPinned: true, isSensitive: true, sortOrder: 2),
            BoardNote(householdID: hh, title: "Emergency contacts",
                      body: "Grandma Parker: (555) 010-7720\nDr. Okafor (pediatrician): (555) 010-6100\nPoison Control: (800) 222-1222",
                      symbol: "staroflife.fill", color: .red, isPinned: true, sortOrder: 3),
            BoardNote(householdID: hh, title: "Vet hours",
                      body: "Paws Vet Clinic\nMon–Fri 8 AM–6 PM, Sat 9 AM–1 PM\n(555) 010-5150\n1450 Alma St, Palo Alto",
                      symbol: "pawprint.fill", color: .green, sortOrder: 4),
            BoardNote(householdID: hh, title: "School lunch menu",
                      body: "Mon: Pizza · Tue: Tacos · Wed: Pasta · Thu: Chicken wrap · Fri: Grilled cheese",
                      symbol: "fork.knife", color: .yellow, sortOrder: 5),
        ]
        notes.forEach(context.insert)
    }

    // MARK: Locations

    func buildLocations() {
        func snapshot(_ member: UUID, _ place: String?, lat: Double, lon: Double, minutesAgo: Double,
                      label: String, driving: Bool = false, battery: Double? = nil) {
            context.insert(LocationSnapshot(
                householdID: hh, memberID: member, latitude: lat, longitude: lon,
                timestamp: now.addingTimeInterval(-minutesAgo * 60),
                placeID: place.flatMap { places[$0] }, label: label, isDriving: driving, batteryLevel: battery
            ))
        }
        snapshot(ID.sam, "Sam’s Office", lat: 37.4441, lon: -122.1608, minutesAgo: 6, label: "At Sam’s Office", battery: 0.71)
        snapshot(ID.alex, nil, lat: 37.4382, lon: -122.1488, minutesAgo: 1, label: "Driving", driving: true, battery: 0.55)
        snapshot(ID.emma, "Lincoln High", lat: 37.4365, lon: -122.1293, minutesAgo: 9, label: "At Lincoln High", battery: 0.42)
        snapshot(ID.liam, "Maple Elementary", lat: 37.4460, lon: -122.1532, minutesAgo: 14, label: "At Maple Elementary")
    }
}
#endif
