# Family — Implementation Plan

Status: **draft for approval.** No app code is written until this is approved.

---

## 0. Build environment (read first)

I work in a Linux cloud container with **no Xcode, no iOS SDK and no Simulator**. I can't run `xcodebuild` or read the SDK's `.swiftinterface` files here. I don't want to fake that step, so the plan is:

**Proposed: a GitHub Actions macOS runner as my build machine.**
- `.github/workflows/ios.yml` runs on every push. It selects the newest Xcode on the runner and prints its version. It then runs `xcodebuild build` for the app and every extension on an iPhone Simulator destination, runs `xcodebuild test`, and **treats warnings as errors** (CI-only build settings), so a green run means zero warnings.
- `.github/workflows/sdk-probe.yml` runs on demand. It greps the installed SDK's `.swiftinterface` files for the symbols I'm about to use (for example `glassEffectID`, `tabViewBottomAccessoryPlacement`, `CLMonitor.CircularGeographicCondition`, `LanguageModelSession`) and prints the real declarations to the log. This is how I'll "inspect the SDK instead of guessing."
- I read the logs through the GitHub integration, fix the errors, and push again until it's green. Then I report the phase.
- Cost: macOS Actions minutes count at 10× on private repos. A full build-and-test run is roughly 8–15 minutes.

**Alternative:** you build each phase on your Mac and paste me the errors. This works, but it's slower and puts you in the loop on every fix.

**Toolchain note:** today is Oct 2026, so Xcode 27 / iOS 27 SDK is current. We **build with the newest SDK** with a deployment target of **iOS 26.0**. Any iOS 27-only API is wrapped in `if #available(iOS 27, *)` with an iOS 26 fallback. TestFlight requires a recent SDK anyway.

**Linux bonus:** the pure-logic module (recurrence, conflicts, allowance, merge rules, parsing) depends only on Foundation. I'll also run its tests here with a Linux Swift toolchain, which gives me a fast inner loop before CI.

---

## 1. Architecture

```
┌──────────────────────── SwiftUI Views (App, Widgets, Share Ext) ────────────────────────┐
│  Feature screens  ←  @Observable feature models (TodayModel, CalendarModel, ListModel…) │
└──────────────────────────────────────┬──────────────────────────────────────────────────┘
                                       │ @Environment(…) injection
┌──────────────────────────────────────▼──────────────────────────────────────────────────┐
│ Services (protocols + live / preview implementations)                                   │
│ SyncService · LocationService · NotificationService · CalendarService ·                 │
│ IntelligenceService · WeatherService · AuthService · SpotlightService · ScreenTimeService│
└──────────────────────────────────────┬──────────────────────────────────────────────────┘
                                       │
┌──────────────────────────────────────▼──────────────────────────────────────────────────┐
│ FamilyData: SwiftData @Model types, Repository (@ModelActor for background writes),     │
│ CKRecord ⇄ model mapping, Outbox (changes made by extensions)                          │
└──────────────────────────────────────┬──────────────────────────────────────────────────┘
┌──────────────────────────────────────▼──────────────────────────────────────────────────┐
│ FamilyCore (Foundation only, Linux-testable): value types, RecurrenceEngine,            │
│ ConflictDetector, AllowanceCalculator, MergePolicy, QuantityParser, GroceryCategorizer  │
└──────────────────────────────────────────────────────────────────────────────────────────┘
```

- **@Observable models per feature** (MVVM-ish). Views read SwiftData with `@Query` where that's simplest. Feature models own the derived state: today's timeline, the needs-attention list, and conflicts.
- **Dependency injection:** an `AppEnvironment` holds every service behind a protocol and is injected with `.environment(...)`. Previews and tests use `.preview` (sample Parkers data, in-memory store, fake location and weather). DEBUG builds without iCloud use `.sampleOnly`.
- **Swift 6 strict concurrency:** UI and feature models are `@MainActor`. Background SwiftData writes go through a `@ModelActor` repository. Services that touch Core Location or CKSyncEngine are actors or `@MainActor` classes with `Sendable` boundaries. No `@unchecked Sendable` except where an Apple type forces it, and each such case gets a comment.
- **Feature flags:** `SYNC_ENABLED` (a Swift compilation condition, on in Release, off by default in the DEBUG Simulator scheme) and `SAMPLE_DATA` (DEBUG only).

---

## 2. Targets and project layout

| Target | Kind | Notes |
|---|---|---|
| `Family` | iOS app | iPhone + iPad; iCloud (CloudKit), Push, App Groups, Background Modes (remote-notification, location, fetch), WeatherKit, Communication Notifications, Time-Sensitive Notifications |
| `FamilyWidgets` | Widget extension | Widgets, Live Activities (Arrive Safely, On My Way), Control Center controls |
| `FamilyShare` | Share extension | "Add to Family" for links, addresses and text |
| `FamilyKit` | Local Swift package (in-repo, Apple tooling only) | Library products shared by all three targets |
| `FamilyTests` | Unit tests | Plus `FamilyKit` package tests |
| `FamilyWatch` | watchOS app | Phase 8, optional |

The Xcode project file is hand-written using Xcode 16+ **file-system-synchronized groups**. The `.pbxproj` stays small and doesn't list every source file, which makes it practical to maintain from here. No XcodeGen, Tuist or other third-party tools.

```
Family/
├─ Family.xcodeproj
├─ Config/
│  ├─ Shared.xcconfig            # deployment target, Swift 6, strict concurrency
│  ├─ Signing.xcconfig           # ← YOU EDIT: DEVELOPMENT_TEAM, BUNDLE_ID_PREFIX
│  ├─ Family.entitlements, FamilyWidgets.entitlements, FamilyShare.entitlements
│  └─ Info plists (usage strings)
├─ App/
│  ├─ FamilyApp.swift, AppDelegate.swift (push, share acceptance, notification actions)
│  ├─ Root/            RootTabView, SidebarAdaptable, NextUpAccessory, QuickAddMenu
│  ├─ Features/
│  │  ├─ Today/        TodayView, NeedsAttentionSection, TimelineRow, TomorrowPeek, WeatherHeader
│  │  ├─ Calendar/     Day/Week/Month views, MemberFilterBar, EventDetail, EventEditor, QuickAdd
│  │  ├─ Rides/        LegClaimButton (glass morph), SwapRequest, ClaimConflictBanner
│  │  ├─ Map/          FamilyMapView, MemberChipsBar, MemberDetailSheet, ArriveSafely
│  │  ├─ Home/         Lists/, Chores/, Allowance/, Meals/, Board/
│  │  ├─ Search/
│  │  ├─ ChildMode/    MyDay, MyChores, WheresMyRide
│  │  ├─ Onboarding/   Welcome, CreateHousehold, AddPlaces, Invite, Join, PermissionPrePrompts
│  │  └─ Settings/     Household, Places, Notifications, Location, CalendarMirroring, Chores,
│  │                   Appearance, Privacy, WhatMyFamilyCanSee, SyncStatus, About, Debug
│  └─ Resources/       Assets.xcassets (icon light/dark/tinted, member colors),
│                      Localizable.xcstrings, PrivacyInfo.xcprivacy
├─ Widgets/            Schedule, NextRide, Grocery, LockScreen, LiveActivities, Controls
├─ ShareExtension/
├─ Packages/FamilyKit/
│  ├─ Sources/FamilyCore/      # Foundation only
│  ├─ Sources/FamilyData/      # SwiftData models, mapping, sample household, outbox
│  ├─ Sources/FamilyServices/  # the services listed above
│  ├─ Sources/FamilyDesign/    # design system
│  ├─ Sources/FamilyIntents/   # AppEntities + AppIntents shared by app & widgets
│  └─ Tests/                   # FamilyCoreTests, FamilyDataTests
├─ FamilyTests/
├─ .github/workflows/          ios.yml, sdk-probe.yml
├─ README.md
└─ docs/PLAN.md
```

**Bundle IDs and containers** (set once in `Signing.xcconfig`):
- App `$(BUNDLE_ID_PREFIX).family`, widgets `….family.widgets`, share `….family.share`
- App Group `group.$(BUNDLE_ID_PREFIX).family`
- CloudKit container `iCloud.$(BUNDLE_ID_PREFIX).family`

---

## 3. Design system (FamilyDesign)

- **MemberColor:** a curated enum of 10 system colors (`.red, .orange, .yellow, .green, .mint, .teal, .blue, .indigo, .purple, .pink`). Each has a solid tint, a soft fill for row bars, and an Increase Contrast variant.
- **AvatarView:** photo, emoji on a member-color circle, or initials. Sizes `.mini` (16 pt, for "added by"), `.small`, `.regular`, `.large` and `.pin` (map). `AvatarStack` has overlapping borders.
- **Rows:** `EventRow` (leading 4 pt member color bar, or a striped bar for several attendees; time with `.monospacedDigit()`; attendee avatars; location; driver status). `ListItemRow`, `ChoreRow`, `NoteCard`. All rows are solid content, never glass.
- **Glass components** (custom floating controls only): `ClaimLegButton` uses `GlassEffectContainer`, `glassEffectID` and `.regular.tint(member).interactive()` and morphs into `MemberChip`. Also `MemberChipsBar` on the map and the Arrive Safely control. Everything else uses system bars, toolbars, sheets and `.glass` / `.glassProminent` button styles.
- **Accessibility wrappers:** `@Environment(\.accessibilityReduceMotion)`, `\.accessibilityReduceTransparency`, and `\.colorSchemeContrast`. A `FamilyMotion.animation(_:)` helper returns `.easeInOut` fades when Reduce Motion is on. The zoom transition is skipped in that case too.
- **Haptics:** one `FamilyHaptic` enum mapped to `.sensoryFeedback` triggers (claim → `.success`, chore → `.success`, check → `.selection`, arrival → `.impact`, error → `.error`).

---

## 4. Data model

All models are SwiftData `@Model` classes with:
- `id: UUID` (also the CloudKit `recordName`)
- `householdID: UUID`
- `modifiedAt: Date`
- `ckSystemFields: Data?` (the encoded `CKRecord` system fields, which carry the change tag)
- `dirtyFields: [String]` (fields changed locally since the last successful send; used for per-field merging)

**Relationships are stored as UUID foreign keys, not SwiftData relationships.** Records arrive from CloudKit in any order (an Event can arrive before its Member). Foreign keys make that safe, keep the mapping 1:1 with CKRecord fields, and avoid cascade surprises. Lookups go through indexed fetches in the repository.

| Model | Key fields |
|---|---|
| `Household` | name, createdAt, ownerMemberID |
| `Member` | name, role (`adult/teen/child`), color, avatar (kind + emoji/initials + photo CKAsset), birthday, phone, locationSharing (`on/paused/off`), canDrive (teen license override), ckParticipantID, shareBusyTimes |
| `Event` | title, start, end, isAllDay, timeZoneID, location (name, address, coordinate, MKMapItem identifier), recurrence (`RecurrenceRule?` Codable), attendeeIDs, needsDropoff, needsPickup, notes, reminderOffsets, ekIdentifier (local-only, never synced), seriesID / splitFrom (for "this and future") |
| `EventException` | eventID, occurrenceDate, isCancelled, overrides (title, start, end, location, notes) |
| `RideClaim` | eventID, occurrenceDate, leg (`dropoff/pickup`), memberID, claimedAt, status (`active/released/swapRequested`), swapTargetID |
| `BusyBlock` | memberID, start, end (no titles; opt-in "share my busy times") |
| `FamilyList` | name, symbol, color, kind (`grocery/packing/todo/custom`), sortOrder |
| `ListItem` | listID, text, quantity, unit, section, addedByID, isChecked, checkedByID, checkedAt, checkStateChangedAt |
| `Chore` | title, assigneeID, recurrence, valueKind (`points/money`), value (Decimal as minor units Int), dueTime, requiresPhotoProof |
| `ChoreCompletion` | choreID, occurrenceDate, memberID, completedAt, photo (CKAsset), approval (`pending/approved/rejected`), approvedByID |
| `AllowanceEntry` | memberID, amountMinor, reason, date, isPaid, completionID? |
| `MealPlanEntry` | date, mealType, title, recipeURL, ingredients [String], cookID |
| `BoardNote` | title, body, symbol, isPinned, isSensitive (sensitive body stored in `encryptedValues`) |
| `Place` | name, coordinate, radius (≥ 100 m), symbol, isStore |
| `PlaceAlert` | memberID (who is located), watcherID, placeID, onArrive, onDepart |
| `LocationSnapshot` | memberID, coordinate, timestamp, placeID, label, battery (coordinate in `encryptedValues`) |
| `ArriveSafelySession` | memberID, destination, expectedArrival, startedAt, state (`active/arrived/overdue/cancelled`) |
| `SwapRequest` | folded into `RideClaim.status`, so no separate model |

Local-only (not synced): `DeviceSettings` (role, notification prefs, mirroring calendar ID, recent searches) in a separate SwiftData store, and the CKSyncEngine state blob.

**Store location:** App Group container, so widgets and the share extension can read it. Extensions never talk to CloudKit. They write to the shared store and append to an **Outbox** table, and the app's SyncService drains the Outbox on its next activation or background refresh.

---

## 5. Sync design

**Engines.** One `CKSyncEngine` for the database this device uses:
- **Owner:** private database, custom zone `Household-<uuid>`, plus a **zone-wide `CKShare`** (`CKShare(recordZoneID:)`).
- **Participant:** shared database, where the same zone appears under the owner's ID.

`DeviceSettings.role` and the zone ID are stored so the right engine is created on launch. Engine state serialization comes back in `.stateUpdate` events and is persisted on every update.

**Mapping.** `RecordMapper` turns each model into `CKRecord(recordType: "Event", recordID: (id, zoneID))`. It starts from the stored system fields so change tags are kept. Large or private values use `encryptedValues`: sensitive notes, location coordinates, phone numbers. That gives end-to-end encryption on the user's iCloud Keychain key. Photos become `CKAsset` files staged in Caches. Unit tests cover the round trip for every type.

**Sending.** Local writes mark `dirtyFields`, bump `modifiedAt` and call `engine.state.add(pendingRecordZoneChanges:)`. `nextRecordZoneChangeBatch` builds records from the current model.

**Conflicts** (`serverRecordChanged`):
- **Default: per-field last writer wins.** Take the server record, overlay only our `dirtyFields`, and resend. Fields we didn't touch take the server value, so concurrent edits to different fields both survive.
- **Ride claims never conflict.** Each claim is its own record (`RideClaim`, keyed by claimer). If Sam and Alex both claim Emma's pickup, two records exist. `ConflictDetector` sees two active claims on one leg, and the UI shows a **"Sam also claimed this"** banner with "Keep mine" / "Let Sam take it". The earlier `claimedAt` is the provisional primary. Nothing is silently dropped.
- **List item `isChecked`:** a timestamped register (`checkStateChangedAt`, tie-break on member ID). This is deterministic on every device, and the losing toggle still shows in the item's history line ("Checked by Liam, unchecked by Sam").

**Receiving.** `fetchedRecordZoneChanges` upserts by ID through the `@ModelActor`. Deletions remove the record. Then:
- the `NotificationService` diff runs (new claim → "Alex got Emma's pickup")
- widget timelines reload
- Spotlight reindexes

**Push.** CKSyncEngine creates the database subscription itself. Silent pushes need the `remote-notification` background mode, and `application(_:didReceiveRemoteNotification:)` forwards them to the engine.

**Account and lifecycle:**
- `accountChange`: sign-out → wipe local household data (after confirmation UI) and engine state; switch account → same, then onboarding.
- Zone deleted or share revoked (`zoneNotFound`, `userDeletedZone`, the participant removed): delete local data, show "You're no longer part of The Parkers", return to onboarding.
- Owner **transfers ownership**: CloudKit can't transfer a zone. Implemented as: the new owner creates a new zone and share, copies all records, and invites everyone. The old share is then removed. This is documented as a deliberate multi-step flow.

**Invitations.** The owner uses `ShareLink` with a `CKShare` (system sharing sheet, Messages preselected via a `UICloudSharingController` wrapper where needed). The share has `publicPermission = .none` and participant permission `.readWrite`. Acceptance is handled in `windowScene(_:userDidAcceptCloudKitShareWith:)` (scene delegate adaptor) → `CKAcceptSharesOperation` → the participant engine starts → the join flow (name, color, avatar, role). The role is proposed by the inviter, and an adult can change it later.

**Offline.** The local store is the source of truth, so the UI never waits on the network. Settings shows the sync status: last synced, pending changes, and account state.

**Roles** are enforced in the app, not by CloudKit. A zone-wide share gives every participant the same read/write permission, so a child can't edit others' events through the UI, but the CloudKit permission itself is household-wide. This is documented in the README and on the Privacy screen.

---

## 6. Feature notes

**Recurrence.** `RecurrenceRule` supports daily, weekly (by weekday), monthly (by day or nth weekday) and yearly, with interval, count/until and `EventException`s.
- "This event": write an exception.
- "All future events": end the original series the day before (`until`), then create a new series with `splitFrom`. Claims and exceptions after the split are moved to the new series.
- `RecurrenceEngine.occurrences(in: DateInterval)` is pure, DST-safe through `Calendar`, and heavily tested.

**ConflictDetector** (pure, tested). Inputs: occurrences, active claims, adults, BusyBlocks and an injected `TravelTimeProvider` (MapKit ETA live, a fixed table in tests). Outputs:
- `doubleBooked(adult, legA, legB)` — the same adult on two overlapping legs
- `noAvailableDriver(leg)` — every adult who can drive is busy
- `impossibleTravel(adult, legA, legB, needed, available)`
- `duplicateClaim(leg, claims)` — two active claims on one leg

**Rides.**
- A dropoff leg's time is the event start. A pickup leg's time is the event end.
- A claim adds the leg to the claimer's Today and notifies the household.
- Unclaimed reminders: each adult device schedules local notifications for 7 PM the evening before (configurable) and 2 h before. Every sync reschedules them, and a claim cancels them. This doesn't depend on push arriving in time. A `BGAppRefreshTask` tries to sync shortly before 7 PM so the device doesn't fire a stale reminder.
- Swap: set the claim's status to `swapRequested` with a target. The target gets a notification with an **Accept** action, and accepting moves the claim.

**Quick add (Foundation Models).**
- Check `SystemLanguageModel.default.availability`.
- If available: `LanguageModelSession` with instructions that include member names, places and today's date, and `respond(to:generating: ParsedEvent.self)`. `ParsedEvent` is a `@Generable` struct with `@Guide`s.
- Relative dates and weekdays are resolved in code, not by the model.
- Always open a confirmation sheet. If the model is unavailable or errors, show the regular form prefilled by a small rule-based parser.

**Lists.**
- `QuantityParser` handles "2 gallons milk" → (2, gallon, "milk").
- `GroceryCategorizer` uses a keyword map of about 400 items, and Foundation Models classifies only unknown items, with the result cached.
- `@FocusState` keeps the add field focused between entries.
- "Clear completed" uses `UndoManager` plus a toast.

**Chores and allowance.**
- `AllowanceCalculator` (pure, Decimal-safe in minor units) computes:
  - the balance: approved, unpaid earnings minus payments
  - the weekly summary
  - streaks: consecutive due occurrences completed
- Auto-approve is a household setting.
- **Pay** writes an `AllowanceEntry(isPaid)` and opens `sms:` with a prefilled body. iOS supports a body in `sms:` URLs. Apple Cash is sent manually by the parent.

**Meals.** A weekly grid. "Add ingredients to Grocery" de-duplicates against unchecked items using the normalized name. "Suggest dinners" uses a `@Generable` array of three suggestions, with the busy nights from the week passed in.

**Board.**
- Sensitive notes need `LAContext` `.deviceOwnerAuthentication` to reveal, and they relock on background.
- A privacy cover view hides the app-switcher snapshot when `scenePhase != .active` while a sensitive note is visible.
- Sensitive notes never appear in widgets, Spotlight or notifications.
- Phone numbers, addresses and Wi-Fi passwords are detected and turned into quick actions.

**Map and location.**
- `CLServiceSession(authorization: .whenInUse)` while the Map is visible. Alerts and Arrive Safely request an `.always` goal, explained by a pre-prompt.
- `CLMonitor("family-places")` with `CircularGeographicCondition`: Places capped at 20, minimum radius 100 m, recreated on launch.
- `CLLocationUpdate.liveUpdates()` only while the Map is open or Arrive Safely is active. Otherwise only monitor events plus significant location changes.
- Labels: in a Place → "At School since 8:12". Speed > 7 m/s for two consecutive updates → "Driving". Otherwise the neighborhood from reverse geocoding (`MKReverseGeocodingRequest` on iOS 26).
- Snapshots upload only when the label changes or at most every 15 minutes. Snapshots older than 24 h are deleted by the device that wrote them.
- "Location paused" is a Member state, so other members see a paused chip rather than a stale pin.

**Arrive Safely.**
- The traveler's device holds a `CLBackgroundActivitySession` (as a property, only while active) and runs a Live Activity on its own Lock Screen and Dynamic Island.
- Watchers' devices schedule a local `.timeSensitive` "overdue" notification at the ETA plus a grace period when the session record arrives. Arrival syncs and cancels it.
- Overdue detection on the traveler's device: past the ETA and the distance to the destination isn't shrinking.

**Notifications.**
- Categories:
  - `RIDE_UNCLAIMED`: action I've Got It
  - `SWAP_REQUEST`: Accept
  - `CHORE_DONE`: Approve
  - `ARRIVE_OVERDUE`: Call
  - `ARRIVAL`, `CLAIMED`, `LIST`
- Communication-style notifications (member avatar) via an `INSendMessageIntent` donation for member-initiated events such as claims, swaps and chore completions.
- Interruption levels: arrival `.active`, overdue `.timeSensitive`, everything else `.passive` or `.active`. Never `.critical`.
- Each category has a toggle in Settings.

**Weather.** WeatherKit `WeatherService.shared.weather(for: home)`. The required Apple Weather mark and legal link come from `WeatherService.shared.attribution`.

**Calendar mirroring (EventKit).**
- `requestFullAccessToEvents` is called only when the user turns mirroring on.
- The user picks a writable calendar, for example "Family". Each device mirrors only events it creates or edits, keyed by the local `ekIdentifier`, to avoid duplicates.
- A read-only overlay can show any calendar (such as a school subscription).
- BusyBlocks come from the user's own calendars, as an opt-in that shares busy times only.

**Search.** In-memory index over events, items, notes (non-sensitive titles only, unless unlocked), chores and members. Recent searches and suggestion chips (members, "This week", "Needs driver").

**Child mode.** The root switches to `ChildRootView` when the device's member role is `.child`: "My day", "My chores", "Where's my ride?" with larger type and simpler rows, using the same components.

**Widgets, intents and system.**
- Widgets: Schedule (S/M/L), Next Ride with an interactive I've Got It (an `AppIntent` that writes the claim to the shared store and Outbox), Grocery check-off, Lock Screen accessories, and `widgetAccentedRenderingMode` on avatars.
- App Shortcuts: add to list, who's picking up, where's [member], today's calendar, claim pickup.
- `AppEntity` for Member, FamilyList and Event.
- `ControlWidget`s: Start Arrive Safely, Add to Grocery.
- Spotlight: `CSSearchableIndex` for events and list names only.

**ScreenTimeService.** A protocol plus a no-op implementation, and a README section on the Family Controls entitlement path.

---

## 7. Sample household (DEBUG)

`SampleHousehold.load(into:)` creates The Parkers:
- People: Sam (adult, blue), Alex (adult, orange), Emma (15, teen, purple, no license), Liam (9, child, green), and Biscuit the dog (a household "pet" pseudo-member, avatar 🐶, no device).
- **Places:** Home, Lincoln High, Maple Elementary, Riverside Park, Trader Joe's (store), Paws Vet.
- **Week of events** relative to "now":
  - Emma soccer Tue/Thu 5–6:30 with pickup needed
  - Liam swim Mon/Wed with dropoff and pickup
  - a dentist appointment
  - Biscuit's vet visit
  - a family dinner at Grandma's
  - a school concert
  - Mix of claimed, unclaimed and one deliberate double-booking, so conflicts show up.
- **Lists:** Groceries (~15 items across aisles, some checked), Camping packing, Weekend to-dos.
- **Chores:** Feed Biscuit (Liam, daily, 1 point), Empty dishwasher (Emma, $2), Make bed, Take out trash (with photo proof), plus completions, approvals and a 4-day streak.
- **Meals:** 7 dinners. **Board:** Wi-Fi (sensitive), babysitter, garage code (sensitive), vet hours, emergency contacts.
- **Locations:** Sam at work, Alex driving home, Emma at Lincoln High, Liam at home, and an Arrive Safely session.

---

## 8. Tests

- `FamilyCoreTests`: RecurrenceEngine (DST, month-end, nth weekday, exceptions, splits), ConflictDetector (each conflict kind), AllowanceCalculator (balances, weekly, streaks, rounding), MergePolicy (per-field, checked register, claim duplicates), QuantityParser, GroceryCategorizer.
- `FamilyDataTests`: CKRecord round trip for every model, `encryptedValues` placement, system fields kept, unknown field tolerance (forward compatibility).
- These run on CI (xcodebuild). FamilyCore tests also run on Linux here.

---

## 9. Build order

| Phase | Contents | Verified by |
|---|---|---|
| **1** | Project, targets, entitlements, App Group, CI workflows, design system, all models, sample household, TabView shell (Tab API, search tab, minimize on scroll, bottom accessory, sidebarAdaptable), Today toolbar + quick-add menu, previews | CI green with 0 warnings, screenshots from a CI Simulator run |
| **2** | Today, Calendar (day/week/month), events + editor, recurrence + exceptions, rides/claims with glass morph, swap, ConflictDetector, Foundation Models quick add with fallback, tests | CI + tests |
| **3** | Lists, Chores + allowance + Pay, Meals, Board with Face ID and privacy cover, Search | CI + tests |
| **4** | CKSyncEngine, zone + zone-wide share, invites and acceptance, join flow, roles, offline, conflict handling, Outbox, account and revocation handling, plus a **two-Simulator test script** in the README | CI + manual test steps for you |
| **5** | Map, Places, CLMonitor, labels, alerts, Arrive Safely + Live Activity, notifications with actions | CI + Simulator location GPX |
| **6** | Widgets, App Intents/Siri/Shortcuts, Controls, Spotlight, Share Extension, EventKit mirroring + overlay | CI |
| **7** | Onboarding, all Settings, Privacy + "What my family can see", accessibility pass, iPad polish, performance pass, app icon (light/dark/tinted PNGs + Icon Composer notes), README, TestFlight guide | CI + checklist |
| **8** | (optional) watchOS app | CI |

After each phase I'll report what was built, the CI run link, any API I had to adjust after probing the SDK, and what's next.

---

## 10. Known deviations (decided up front)

1. **I can't build locally.** CI on a macOS runner is the build machine (section 0).
2. **Other members' Live Activities.** Starting or updating a Live Activity on another person's phone needs an APNs push from a server, and a no-server app can't send one. Arrive Safely and On My Way show a Live Activity **on the traveler's own phone**. The household sees the ETA in the app, the widgets and notifications.
3. **Cross-device alerts depend on CloudKit silent pushes**, which are best effort and throttled in Low Power Mode. Time-critical alerts (unclaimed rides, overdue Arrive Safely) are **pre-scheduled locally on each watcher's device** from synced data, so they fire even if a push is late. A device that hasn't synced recently may occasionally show a stale reminder.
4. **Roles are enforced in the app, not by CloudKit** (see section 5).
5. **Ownership transfer** is a migrate-and-reinvite flow, because CloudKit zones can't change owner.
6. **"Driving" detection** uses GPS speed. Core Motion activity would need another permission prompt, so it's left out of v1.
7. **App icon** is generated as PNGs (light/dark/tinted) by a script. The layered Liquid Glass `.icon` file has to be made by you in Icon Composer; I'll give you exact layer instructions.
8. **Personal calendar busy times** for conflict detection are shared only as start/end blocks, opt-in per adult. One device can't read another person's calendar.

---

## 11. What I need from you

1. **OK on this plan**, and a choice of build loop: CI on GitHub Actions macOS (recommended) or you build locally.
2. If CI: confirm Actions is enabled for `CordiaJude/Family` and that macOS minutes are OK.
3. Before Phase 4 (not needed now): your Team ID and a bundle ID prefix (e.g. `com.yourname`), which go in `Config/Signing.xcconfig`.
