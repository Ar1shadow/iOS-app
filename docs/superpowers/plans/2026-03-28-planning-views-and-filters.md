# Planning Views and Filters v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a plan/list view toggle and date-range filtering to Planning without resetting existing filters.

**Architecture:** Keep the state in `PlanningViewModel` so view mode, plan level, status, and date range remain in sync across view switches. Build plan-view sections from scheduled dates (`dueAt ?? startAt`) and keep list view grouped by status with the existing quick actions.

**Tech Stack:** SwiftUI, XCTest, existing SharedUI components, existing Planning service/repository layer.

---

### Task 1: Cover filtering and grouping in tests

**Files:**
- Create: `ios-app/App/CoupleLife/CoupleLifeTests/Planning/PlanningViewModelTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
@MainActor
final class PlanningViewModelTests: XCTestCase {
    func testPlanViewGroupsScheduledTasksByStartOfDayAndKeepsUnscheduledOnlyInAllRange() async { }
    func testDateRangeFiltersHideUnscheduledTasksOutsideAll() async { }
    func testSwitchingViewModesDoesNotResetFilters() async { }
}
```

- [ ] **Step 2: Run the new test file and verify it fails**

Run: `cd ios-app/App/CoupleLife && xcodebuild -project CoupleLife.xcodeproj -scheme CoupleLife -destination 'platform=iOS Simulator,id=5EF18BBB-1C49-45C8-BBD4-A831BDDA53B6' -derivedDataPath /tmp/CoupleLifeDerivedData510-tests CODE_SIGNING_ALLOWED=NO test -only-testing:CoupleLifeTests/PlanningViewModelTests`
Expected: fail because the new APIs and grouping logic do not exist yet.

- [ ] **Step 3: Add the smallest production code to satisfy the tests**

```swift
// PlanningViewModel gains viewMode/dateRange state and computed plan/list sections.
// Plan view groups by startOfDay(dueAt ?? startAt); list view keeps status sections.
```

- [ ] **Step 4: Re-run the test file and confirm it passes**

Run: `cd ios-app/App/CoupleLife && xcodebuild -project CoupleLife.xcodeproj -scheme CoupleLife -destination 'platform=iOS Simulator,id=5EF18BBB-1C49-45C8-BBD4-A831BDDA53B6' -derivedDataPath /tmp/CoupleLifeDerivedData510-tests CODE_SIGNING_ALLOWED=NO test -only-testing:CoupleLifeTests/PlanningViewModelTests`
Expected: PASS.

### Task 2: Wire the Planning tab UI

**Files:**
- Modify: `ios-app/App/CoupleLife/CoupleLife/UI/Tabs/PlanningTab.swift`
- Modify: `ios-app/App/CoupleLife/CoupleLife/Planning/Presentation/PlanningViewModel.swift`
- Modify: `ios-app/App/CoupleLife/CoupleLife/Planning/Presentation/PlanningDisplaySupport.swift`

- [ ] **Step 1: Add the new view mode and date-range controls**

```swift
// Segmented picker for 计划视图 / 列表视图.
// Menu picker for All / Today / Next 7 / Next 30 / Custom.
// Show custom start/end DatePickers when Custom is selected.
```

- [ ] **Step 2: Render plan sections and list sections from the shared filter state**

```swift
// List view keeps grouped status cards and quick actions.
// Plan view groups tasks by date section plus an All-only "未排期" section.
```

- [ ] **Step 3: Re-run the focused Planning tests**

Run: `cd ios-app/App/CoupleLife && xcodebuild -project CoupleLife.xcodeproj -scheme CoupleLife -destination 'platform=iOS Simulator,id=5EF18BBB-1C49-45C8-BBD4-A831BDDA53B6' -derivedDataPath /tmp/CoupleLifeDerivedData510-ui CODE_SIGNING_ALLOWED=NO test -only-testing:CoupleLifeTests/PlanningViewModelTests -only-testing:CoupleLifeTests/PlanningTaskServiceTests`
Expected: PASS.

### Task 3: Update the task record and finish

**Files:**
- Modify: `ios-app/tasks/planning/510-planning-views-and-filters.md`

- [ ] **Step 1: Fill in status, last update, implementation record, and verification record**

```markdown
- 状态: Done
- 最后更新: 2026-03-28
```

- [ ] **Step 2: Run the full app test suite**

Run: `cd ios-app/App/CoupleLife && xcodebuild -project CoupleLife.xcodeproj -scheme CoupleLife -destination 'platform=iOS Simulator,id=5EF18BBB-1C49-45C8-BBD4-A831BDDA53B6' -derivedDataPath /tmp/CoupleLifeDerivedData510 CODE_SIGNING_ALLOWED=NO test`
Expected: PASS.

- [ ] **Step 3: Commit the implementation**

```bash
git add ios-app/App/CoupleLife ios-app/tasks/planning/510-planning-views-and-filters.md docs/superpowers/plans/2026-03-28-planning-views-and-filters.md
git commit -m "feat: add planning views and date filters"
```
