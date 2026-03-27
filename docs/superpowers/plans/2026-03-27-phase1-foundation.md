# Phase 1 Foundation (Tasks 100/110/200/210) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a runnable SwiftUI iOS app skeleton (5 tabs), a minimal AppCore DI/service protocol boundary, v1 domain models, and a SwiftData persistence/repository layer that compiles and can be built via `xcodebuild`.

**Architecture:** Start document-first, then introduce an Xcode SwiftUI app under `ios-app/App/` with a strict boundary: SwiftUI views depend on Domain + AppCore protocols, not on Apple frameworks directly. Data persistence uses SwiftData with repositories.

**Tech Stack:** SwiftUI, XCTest, SwiftData (iOS 17+), `xcodebuild` (CLI build/verify).

---

## File Structure (Locked In)

This plan introduces app code under `ios-app/App/` only. Keep docs under repo root + `ios-app/tasks/`.

```text
ios-app/
  App/
    CoupleLife/                      # Xcode project root folder
      CoupleLife.xcodeproj
      CoupleLife/
        CoupleLifeApp.swift
        AppCore/
          AppContainer.swift
          AppServices.swift
          Routing.swift
        Domain/
          Models/
            Record.swift
            TaskItem.swift
            HealthMetricSnapshot.swift
            SharedEnums.swift
        Data/
          Persistence/
            ModelContainerFactory.swift
          Repositories/
            RecordRepository.swift
            TaskRepository.swift
            HealthSnapshotRepository.swift
        UI/
          Root/
            RootTabView.swift
          Tabs/
            HomeTab.swift
            CalendarTab.swift
            PlanningTab.swift
            FitnessTab.swift
            ProfileTab.swift
      CoupleLifeTests/
        Data/
          RecordRepositoryTests.swift
          TaskRepositoryTests.swift
```

Notes:
- `Task` is a Swift concurrency type; use `TaskItem` as the model name to avoid collisions.
- Keep Apple frameworks (EventKit/HealthKit/etc.) out of Phase 1 code paths; they appear later behind `Integration` services.

## Global Conventions

- Deployment target: iOS 17.0 (SwiftData).
- Bundle id suggestion: `com.ar1shadow.CoupleLife` (adjustable).
- No permissions prompts on launch (per Task 100 non-goals).

---

### Task 1: Create The Xcode SwiftUI App Skeleton (Prereq For Task 100)

**Files:**
- Create (via Xcode): `ios-app/App/CoupleLife/CoupleLife.xcodeproj` and default SwiftUI app files
- Modify: `ios-app/App/CoupleLife/CoupleLife/CoupleLifeApp.swift`

- [ ] **Step 1: Create the project in Xcode (one-time, explicit UI steps)**

In Xcode:
1. `File` -> `New` -> `Project...`
2. Template: `iOS` -> `App`
3. Product Name: `CoupleLife`
4. Interface: `SwiftUI`
5. Language: `Swift`
6. Use Core Data: `No`
7. Include Tests: `Yes`
8. Organization Identifier: `com.ar1shadow` (or your own)
9. Save location: `<repo>/ios-app/App/` (so the folder becomes `ios-app/App/CoupleLife/`)

Then in the project settings:
1. Set iOS Deployment Target to `17.0`
2. Ensure the scheme `CoupleLife` exists and is shared if needed

- [ ] **Step 2: Verify CLI build works**

Run (from repo root):
```bash
cd ios-app/App/CoupleLife
xcodebuild -project CoupleLife.xcodeproj -scheme CoupleLife -destination 'generic/platform=iOS Simulator' build
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add ios-app/App/CoupleLife
git commit -m "chore: add Xcode SwiftUI app skeleton"
```

---

### Task 2: Task 100 App Scaffold And Tabs

**Files:**
- Create: `ios-app/App/CoupleLife/CoupleLife/UI/Root/RootTabView.swift`
- Create: `ios-app/App/CoupleLife/CoupleLife/UI/Tabs/HomeTab.swift`
- Create: `ios-app/App/CoupleLife/CoupleLife/UI/Tabs/CalendarTab.swift`
- Create: `ios-app/App/CoupleLife/CoupleLife/UI/Tabs/PlanningTab.swift`
- Create: `ios-app/App/CoupleLife/CoupleLife/UI/Tabs/FitnessTab.swift`
- Create: `ios-app/App/CoupleLife/CoupleLife/UI/Tabs/ProfileTab.swift`
- Modify: `ios-app/App/CoupleLife/CoupleLife/CoupleLifeApp.swift`
- Update doc: `ios-app/tasks/app-core/100-app-scaffold-and-tabs.md`

- [ ] **Step 1: Implement the tab scaffold**

Create `ios-app/App/CoupleLife/CoupleLife/UI/Root/RootTabView.swift`:

```swift
import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            HomeTab()
                .tabItem { Label("首页", systemImage: "house") }

            CalendarTab()
                .tabItem { Label("日历", systemImage: "calendar") }

            PlanningTab()
                .tabItem { Label("计划", systemImage: "checklist") }

            FitnessTab()
                .tabItem { Label("运动", systemImage: "figure.walk") }

            ProfileTab()
                .tabItem { Label("我的", systemImage: "person") }
        }
    }
}
```

Create `ios-app/App/CoupleLife/CoupleLife/UI/Tabs/HomeTab.swift`:
```swift
import SwiftUI

struct HomeTab: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("首页", systemImage: "house", description: Text("Phase 1: 占位页面"))
                .navigationTitle("首页")
        }
    }
}
```

Create `ios-app/App/CoupleLife/CoupleLife/UI/Tabs/CalendarTab.swift`:
```swift
import SwiftUI

struct CalendarTab: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("日历", systemImage: "calendar", description: Text("Phase 1: 占位页面"))
                .navigationTitle("日历")
        }
    }
}
```

Create `ios-app/App/CoupleLife/CoupleLife/UI/Tabs/PlanningTab.swift`:
```swift
import SwiftUI

struct PlanningTab: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("计划", systemImage: "checklist", description: Text("Phase 1: 占位页面"))
                .navigationTitle("计划")
        }
    }
}
```

Create `ios-app/App/CoupleLife/CoupleLife/UI/Tabs/FitnessTab.swift`:
```swift
import SwiftUI

struct FitnessTab: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("运动", systemImage: "figure.walk", description: Text("Phase 1: 占位页面"))
                .navigationTitle("运动")
        }
    }
}
```

Create `ios-app/App/CoupleLife/CoupleLife/UI/Tabs/ProfileTab.swift`:
```swift
import SwiftUI

struct ProfileTab: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("我的", systemImage: "person", description: Text("Phase 1: 占位页面"))
                .navigationTitle("我的")
        }
    }
}
```

- [ ] **Step 2: Wire RootTabView into the app entry**

Modify `ios-app/App/CoupleLife/CoupleLife/CoupleLifeApp.swift` to:

```swift
import SwiftUI

@main
struct CoupleLifeApp: App {
    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
    }
}
```

- [ ] **Step 3: Verify build and manual run**

```bash
cd ios-app/App/CoupleLife
xcodebuild -project CoupleLife.xcodeproj -scheme CoupleLife -destination 'generic/platform=iOS Simulator' build
```

Manual check (Simulator):
- Launch app, switch all 5 tabs, each tab shows its own navigation title.

- [ ] **Step 4: Update the task doc (minimal)**

Update `ios-app/tasks/app-core/100-app-scaffold-and-tabs.md`:
- Set `状态: Done`
- Add `验证记录` with the `xcodebuild` command and the 5-tab manual check
- Keep notes to 1-3 lines

- [ ] **Step 5: Commit**

```bash
git add ios-app/App/CoupleLife ios-app/tasks/app-core/100-app-scaffold-and-tabs.md
git commit -m "feat: add root tabs scaffold"
```

---

### Task 3: Task 110 AppCore DI, Routing, And Service Protocols

**Files:**
- Create: `ios-app/App/CoupleLife/CoupleLife/AppCore/AppServices.swift`
- Create: `ios-app/App/CoupleLife/CoupleLife/AppCore/AppContainer.swift`
- Create: `ios-app/App/CoupleLife/CoupleLife/AppCore/Routing.swift`
- Modify: `ios-app/App/CoupleLife/CoupleLife/CoupleLifeApp.swift`
- Update doc: `ios-app/tasks/app-core/110-di-routing-and-appcore-services.md`

- [ ] **Step 1: Define service protocols**

Create `ios-app/App/CoupleLife/CoupleLife/AppCore/AppServices.swift`:

```swift
import Foundation

enum ServiceAvailability: Equatable {
    case available
    case notAuthorized
    case notSupported
    case failed(String)
}

protocol CalendarSyncService {
    func availability() async -> ServiceAvailability
}

protocol HealthDataService {
    func availability() async -> ServiceAvailability
}

protocol NotificationScheduler {
    func availability() async -> ServiceAvailability
}

protocol CloudSyncService {
    func availability() async -> ServiceAvailability
}

struct NoopCalendarSyncService: CalendarSyncService {
    func availability() async -> ServiceAvailability { .notSupported }
}

struct NoopHealthDataService: HealthDataService {
    func availability() async -> ServiceAvailability { .notSupported }
}

struct NoopNotificationScheduler: NotificationScheduler {
    func availability() async -> ServiceAvailability { .notSupported }
}

struct NoopCloudSyncService: CloudSyncService {
    func availability() async -> ServiceAvailability { .notSupported }
}
```

- [ ] **Step 2: Create an app container and an EnvironmentKey**

Create `ios-app/App/CoupleLife/CoupleLife/AppCore/AppContainer.swift`:

```swift
import SwiftUI

struct AppContainer {
    let calendarSync: CalendarSyncService
    let healthData: HealthDataService
    let notifications: NotificationScheduler
    let cloudSync: CloudSyncService

    static let `default` = AppContainer(
        calendarSync: NoopCalendarSyncService(),
        healthData: NoopHealthDataService(),
        notifications: NoopNotificationScheduler(),
        cloudSync: NoopCloudSyncService()
    )
}

private struct AppContainerKey: EnvironmentKey {
    static let defaultValue: AppContainer = .default
}

extension EnvironmentValues {
    var appContainer: AppContainer {
        get { self[AppContainerKey.self] }
        set { self[AppContainerKey.self] = newValue }
    }
}
```

- [ ] **Step 3: Add minimal routing primitives**

Create `ios-app/App/CoupleLife/CoupleLife/AppCore/Routing.swift`:

```swift
import Foundation

enum AppRoute: Hashable {
    case home
    case calendar
    case planning
    case fitness
    case profile
}
```

- [ ] **Step 4: Inject the container at the app root**

Modify `ios-app/App/CoupleLife/CoupleLife/CoupleLifeApp.swift`:

```swift
import SwiftUI

@main
struct CoupleLifeApp: App {
    private let container = AppContainer.default

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(\.appContainer, container)
        }
    }
}
```

- [ ] **Step 5: Verify build**

```bash
cd ios-app/App/CoupleLife
xcodebuild -project CoupleLife.xcodeproj -scheme CoupleLife -destination 'generic/platform=iOS Simulator' build
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Update the task doc (minimal)**

Update `ios-app/tasks/app-core/110-di-routing-and-appcore-services.md`:
- Set `状态: Done`
- Record the protocol boundary decision and how views access `appContainer`
- Add the verification command

- [ ] **Step 7: Commit**

```bash
git add ios-app/App/CoupleLife ios-app/tasks/app-core/110-di-routing-and-appcore-services.md
git commit -m "feat: add AppCore service protocols and DI container"
```

---

### Task 4: Task 200 Domain Models v1 (SwiftData @Model)

**Files:**
- Create: `ios-app/App/CoupleLife/CoupleLife/Domain/Models/SharedEnums.swift`
- Create: `ios-app/App/CoupleLife/CoupleLife/Domain/Models/Record.swift`
- Create: `ios-app/App/CoupleLife/CoupleLife/Domain/Models/TaskItem.swift`
- Create: `ios-app/App/CoupleLife/CoupleLife/Domain/Models/HealthMetricSnapshot.swift`
- Update doc: `ios-app/tasks/data/200-domain-models-v1.md`

- [ ] **Step 1: Add shared enums**

Create `ios-app/App/CoupleLife/CoupleLife/Domain/Models/SharedEnums.swift`:

```swift
import Foundation

enum Visibility: String, Codable, CaseIterable {
    case `private`
    case coupleShared
}

enum DataSource: String, Codable, CaseIterable {
    case manual
    case systemCalendar
    case healthKit
}

enum RecordType: String, Codable, CaseIterable {
    case water
    case bowelMovement
    case menstruation
    case sleep
    case activity
    case custom
}

enum TaskStatus: String, Codable, CaseIterable {
    case todo
    case done
    case cancelled
}

enum PlanLevel: String, Codable, CaseIterable {
    case day
    case week
    case month
    case year
}
```

- [ ] **Step 2: Add Record model**

Create `ios-app/App/CoupleLife/CoupleLife/Domain/Models/Record.swift`:

```swift
import Foundation
import SwiftData

@Model
final class Record {
    @Attribute(.unique) var id: UUID

    var typeRaw: String
    var note: String?
    var tags: [String]

    var startAt: Date
    var endAt: Date?

    var ownerUserId: String
    var coupleSpaceId: String?
    var visibilityRaw: String
    var sourceRaw: String

    var createdAt: Date
    var updatedAt: Date
    var version: Int

    init(
        id: UUID = UUID(),
        type: RecordType,
        note: String? = nil,
        tags: [String] = [],
        startAt: Date,
        endAt: Date? = nil,
        ownerUserId: String,
        coupleSpaceId: String? = nil,
        visibility: Visibility = .private,
        source: DataSource = .manual,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        version: Int = 1
    ) {
        self.id = id
        self.typeRaw = type.rawValue
        self.note = note
        self.tags = tags
        self.startAt = startAt
        self.endAt = endAt
        self.ownerUserId = ownerUserId
        self.coupleSpaceId = coupleSpaceId
        self.visibilityRaw = visibility.rawValue
        self.sourceRaw = source.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.version = version
    }

    var type: RecordType {
        get { RecordType(rawValue: typeRaw) ?? .custom }
        set { typeRaw = newValue.rawValue }
    }

    var visibility: Visibility {
        get { Visibility(rawValue: visibilityRaw) ?? .private }
        set { visibilityRaw = newValue.rawValue }
    }

    var source: DataSource {
        get { DataSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }
}
```

- [ ] **Step 3: Add TaskItem model**

Create `ios-app/App/CoupleLife/CoupleLife/Domain/Models/TaskItem.swift`:

```swift
import Foundation
import SwiftData

@Model
final class TaskItem {
    @Attribute(.unique) var id: UUID

    var title: String
    var detail: String?

    var startAt: Date?
    var dueAt: Date?
    var isAllDay: Bool

    var priority: Int
    var statusRaw: String
    var planLevelRaw: String

    var ownerUserId: String
    var coupleSpaceId: String?
    var visibilityRaw: String
    var sourceRaw: String

    var systemCalendarEventId: String?

    var createdAt: Date
    var updatedAt: Date
    var version: Int

    init(
        id: UUID = UUID(),
        title: String,
        detail: String? = nil,
        startAt: Date? = nil,
        dueAt: Date? = nil,
        isAllDay: Bool = false,
        priority: Int = 0,
        status: TaskStatus = .todo,
        planLevel: PlanLevel = .day,
        ownerUserId: String,
        coupleSpaceId: String? = nil,
        visibility: Visibility = .private,
        source: DataSource = .manual,
        systemCalendarEventId: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        version: Int = 1
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.startAt = startAt
        self.dueAt = dueAt
        self.isAllDay = isAllDay
        self.priority = priority
        self.statusRaw = status.rawValue
        self.planLevelRaw = planLevel.rawValue
        self.ownerUserId = ownerUserId
        self.coupleSpaceId = coupleSpaceId
        self.visibilityRaw = visibility.rawValue
        self.sourceRaw = source.rawValue
        self.systemCalendarEventId = systemCalendarEventId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.version = version
    }

    var status: TaskStatus {
        get { TaskStatus(rawValue: statusRaw) ?? .todo }
        set { statusRaw = newValue.rawValue }
    }

    var planLevel: PlanLevel {
        get { PlanLevel(rawValue: planLevelRaw) ?? .day }
        set { planLevelRaw = newValue.rawValue }
    }

    var visibility: Visibility {
        get { Visibility(rawValue: visibilityRaw) ?? .private }
        set { visibilityRaw = newValue.rawValue }
    }

    var source: DataSource {
        get { DataSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }
}
```

- [ ] **Step 4: Add HealthMetricSnapshot model**

Create `ios-app/App/CoupleLife/CoupleLife/Domain/Models/HealthMetricSnapshot.swift`:

```swift
import Foundation
import SwiftData

@Model
final class HealthMetricSnapshot {
    @Attribute(.unique) var id: UUID

    var dayStart: Date
    var ownerUserId: String
    var coupleSpaceId: String?
    var visibilityRaw: String
    var sourceRaw: String

    var steps: Double?
    var distanceMeters: Double?
    var activeEnergyKcal: Double?
    var exerciseMinutes: Double?
    var standMinutes: Double?

    var restingHeartRate: Double?
    var sleepSeconds: Double?

    var createdAt: Date
    var updatedAt: Date
    var version: Int

    init(
        id: UUID = UUID(),
        dayStart: Date,
        ownerUserId: String,
        coupleSpaceId: String? = nil,
        visibility: Visibility = .private,
        source: DataSource = .healthKit,
        steps: Double? = nil,
        distanceMeters: Double? = nil,
        activeEnergyKcal: Double? = nil,
        exerciseMinutes: Double? = nil,
        standMinutes: Double? = nil,
        restingHeartRate: Double? = nil,
        sleepSeconds: Double? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        version: Int = 1
    ) {
        self.id = id
        self.dayStart = dayStart
        self.ownerUserId = ownerUserId
        self.coupleSpaceId = coupleSpaceId
        self.visibilityRaw = visibility.rawValue
        self.sourceRaw = source.rawValue
        self.steps = steps
        self.distanceMeters = distanceMeters
        self.activeEnergyKcal = activeEnergyKcal
        self.exerciseMinutes = exerciseMinutes
        self.standMinutes = standMinutes
        self.restingHeartRate = restingHeartRate
        self.sleepSeconds = sleepSeconds
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.version = version
    }

    var visibility: Visibility {
        get { Visibility(rawValue: visibilityRaw) ?? .private }
        set { visibilityRaw = newValue.rawValue }
    }

    var source: DataSource {
        get { DataSource(rawValue: sourceRaw) ?? .healthKit }
        set { sourceRaw = newValue.rawValue }
    }
}
```

- [ ] **Step 5: Verify build**

```bash
cd ios-app/App/CoupleLife
xcodebuild -project CoupleLife.xcodeproj -scheme CoupleLife -destination 'generic/platform=iOS Simulator' build
```

- [ ] **Step 6: Update the task doc (minimal)**

Update `ios-app/tasks/data/200-domain-models-v1.md`:
- Set `状态: Done`
- Record key naming choice (`TaskItem`) and why
- Add verification command

- [ ] **Step 7: Commit**

```bash
git add ios-app/App/CoupleLife ios-app/tasks/data/200-domain-models-v1.md
git commit -m "feat: add domain models v1"
```

---

### Task 5: Task 210 SwiftData Container And Repositories

**Files:**
- Create: `ios-app/App/CoupleLife/CoupleLife/Data/Persistence/ModelContainerFactory.swift`
- Create: `ios-app/App/CoupleLife/CoupleLife/Data/Repositories/RecordRepository.swift`
- Create: `ios-app/App/CoupleLife/CoupleLife/Data/Repositories/TaskRepository.swift`
- Create: `ios-app/App/CoupleLife/CoupleLife/Data/Repositories/HealthSnapshotRepository.swift`
- Create tests: `ios-app/App/CoupleLife/CoupleLifeTests/Data/RecordRepositoryTests.swift`
- Create tests: `ios-app/App/CoupleLife/CoupleLifeTests/Data/TaskRepositoryTests.swift`
- Modify: `ios-app/App/CoupleLife/CoupleLife/CoupleLifeApp.swift` (wire ModelContainer)
- Update doc: `ios-app/tasks/data/210-swiftdata-store-and-repositories.md`

- [ ] **Step 1: Add a model container factory**

Create `ios-app/App/CoupleLife/CoupleLife/Data/Persistence/ModelContainerFactory.swift`:

```swift
import Foundation
import SwiftData

enum ModelContainerFactory {
    static func make() throws -> ModelContainer {
        let schema = Schema([
            Record.self,
            TaskItem.self,
            HealthMetricSnapshot.self
        ])

        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
```

- [ ] **Step 2: Add repositories**

Create `ios-app/App/CoupleLife/CoupleLife/Data/Repositories/RecordRepository.swift`:

```swift
import Foundation
import SwiftData

protocol RecordRepository {
    func create(_ record: Record) throws
    func delete(_ record: Record) throws
    func records(from start: Date, to end: Date) throws -> [Record]
}

final class SwiftDataRecordRepository: RecordRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func create(_ record: Record) throws {
        context.insert(record)
        try context.save()
    }

    func delete(_ record: Record) throws {
        context.delete(record)
        try context.save()
    }

    func records(from start: Date, to end: Date) throws -> [Record] {
        let predicate = #Predicate<Record> { $0.startAt >= start && $0.startAt < end }
        let descriptor = FetchDescriptor<Record>(predicate: predicate, sortBy: [SortDescriptor(\.startAt, order: .forward)])
        return try context.fetch(descriptor)
    }
}
```

Create `ios-app/App/CoupleLife/CoupleLife/Data/Repositories/TaskRepository.swift`:

```swift
import Foundation
import SwiftData

protocol TaskRepository {
    func create(_ task: TaskItem) throws
    func delete(_ task: TaskItem) throws
    func tasks(status: TaskStatus?) throws -> [TaskItem]
}

final class SwiftDataTaskRepository: TaskRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func create(_ task: TaskItem) throws {
        context.insert(task)
        try context.save()
    }

    func delete(_ task: TaskItem) throws {
        context.delete(task)
        try context.save()
    }

    func tasks(status: TaskStatus?) throws -> [TaskItem] {
        if let status {
            let predicate = #Predicate<TaskItem> { $0.statusRaw == status.rawValue }
            let descriptor = FetchDescriptor<TaskItem>(predicate: predicate, sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
            return try context.fetch(descriptor)
        } else {
            let descriptor = FetchDescriptor<TaskItem>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
            return try context.fetch(descriptor)
        }
    }
}
```

Create `ios-app/App/CoupleLife/CoupleLife/Data/Repositories/HealthSnapshotRepository.swift`:

```swift
import Foundation
import SwiftData

protocol HealthSnapshotRepository {
    func upsert(_ snapshot: HealthMetricSnapshot) throws
    func snapshot(dayStart: Date, ownerUserId: String) throws -> HealthMetricSnapshot?
}

final class SwiftDataHealthSnapshotRepository: HealthSnapshotRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func upsert(_ snapshot: HealthMetricSnapshot) throws {
        context.insert(snapshot)
        try context.save()
    }

    func snapshot(dayStart: Date, ownerUserId: String) throws -> HealthMetricSnapshot? {
        let predicate = #Predicate<HealthMetricSnapshot> { $0.dayStart == dayStart && $0.ownerUserId == ownerUserId }
        let descriptor = FetchDescriptor<HealthMetricSnapshot>(predicate: predicate)
        return try context.fetch(descriptor).first
    }
}
```

- [ ] **Step 3: Wire the ModelContainer into the app**

Modify `ios-app/App/CoupleLife/CoupleLife/CoupleLifeApp.swift`:

```swift
import SwiftUI
import SwiftData

@main
struct CoupleLifeApp: App {
    private let container = AppContainer.default
    private let modelContainer: ModelContainer

    init() {
        modelContainer = (try? ModelContainerFactory.make()) ?? ModelContainer(for: Schema([]))
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(\.appContainer, container)
        }
        .modelContainer(modelContainer)
    }
}
```

- [ ] **Step 4: Add repository tests (in-memory SwiftData)**

Create `ios-app/App/CoupleLife/CoupleLifeTests/Data/RecordRepositoryTests.swift`:

```swift
import XCTest
import SwiftData
@testable import CoupleLife

final class RecordRepositoryTests: XCTestCase {
    func testCreateAndFetchByDateRange() throws {
        let schema = Schema([Record.self, TaskItem.self, HealthMetricSnapshot.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let repo = SwiftDataRecordRepository(context: context)

        let start = Date(timeIntervalSince1970: 0)
        let record = Record(type: .water, startAt: start.addingTimeInterval(60), ownerUserId: "u1")
        try repo.create(record)

        let results = try repo.records(from: start, to: start.addingTimeInterval(3600))
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.type, .water)
    }
}
```

Create `ios-app/App/CoupleLife/CoupleLifeTests/Data/TaskRepositoryTests.swift`:

```swift
import XCTest
import SwiftData
@testable import CoupleLife

final class TaskRepositoryTests: XCTestCase {
    func testCreateAndFetchByStatus() throws {
        let schema = Schema([Record.self, TaskItem.self, HealthMetricSnapshot.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let repo = SwiftDataTaskRepository(context: context)

        let t1 = TaskItem(title: "t1", status: .todo, ownerUserId: "u1")
        let t2 = TaskItem(title: "t2", status: .done, ownerUserId: "u1")
        try repo.create(t1)
        try repo.create(t2)

        let todos = try repo.tasks(status: .todo)
        XCTAssertEqual(todos.count, 1)
        XCTAssertEqual(todos.first?.title, "t1")
    }
}
```

- [ ] **Step 5: Run tests**

```bash
cd ios-app/App/CoupleLife
xcodebuild -project CoupleLife.xcodeproj -scheme CoupleLife -destination 'generic/platform=iOS Simulator' test
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 6: Update the task doc (minimal)**

Update `ios-app/tasks/data/210-swiftdata-store-and-repositories.md`:
- Set `状态: Done`
- Record repository boundaries and the in-memory test approach
- Add `xcodebuild ... test` command

- [ ] **Step 7: Commit**

```bash
git add ios-app/App/CoupleLife ios-app/tasks/data/210-swiftdata-store-and-repositories.md
git commit -m "feat: add SwiftData container and repositories"
```

---

## Self-Review Checklist (Plan Author)

- Spec coverage: This plan covers Phase 1 foundation tasks 100/110/200/210 only. Calendar/Planning/Fitness feature pages and Apple integrations are explicitly out of scope for this plan.
- Placeholder scan: All steps include explicit paths, code, and commands. The only manual part is Xcode project creation, described as exact UI steps.
- Type consistency: `TaskItem` is used consistently to avoid `Task` collision. Repositories match model names.

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-03-27-phase1-foundation.md`. Two execution options:

1. Subagent-Driven (recommended) - dispatch a specialist subagent per task, review between tasks
2. Inline Execution - execute tasks in this session using executing-plans with checkpoints

