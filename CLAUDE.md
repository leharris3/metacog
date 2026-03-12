# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

This is a Swift Package Manager macOS app (Swift 6.2, macOS 26+ Tahoe).

```bash
# Build
swift build

# Run
swift run MetaCog

# Build release
swift build -c release
```

There are no tests or linting configured.

## Architecture

MetaCog is a macOS productivity app that enforces focus during task work. It monitors foreground apps, blocks unauthorized app switches with escalating penalties (exponential timer + Anki flashcard challenges), and tracks time per-app. Projects group multiple sequential tasks into long-horizon efforts.

### Core Layers

**App** (`Sources/MetaCog/App/`) — `MetaCogApp` delegates to `AppDelegate`, which manages window lifecycle (HUD panel, planning/debrief/gate windows), initializes services, and recovers interrupted tasks/projects on relaunch. `MenuBarManager` provides a status bar icon with left-click HUD toggle and right-click quick actions.

**Services** (`Sources/MetaCog/Services/`) — Four singletons, all `@MainActor`:
- `AppState.shared` — Central state machine with `@Published` properties. All UI and services coordinate through this, not through each other. Manages both task and project lifecycles.
- `TimeTracker` — Monitors app switches via `NSWorkspace` notifications and screen lock via `DistributedNotificationCenter`. Runs a 1-second timer, creates `AppUsageLog` entries, guards against sleep time jumps (>5s). Enforces 30-minute limit on standalone tasks.
- `CheckInScheduler` — Polls every 5 seconds, triggers check-ins at cumulative 50% and 90% of sub-goal duration.
- `InterventionManager` — Three-phase flow on unauthorized app switch: exponential penalty timer (`15 * 2^count` seconds) → Anki card challenge (SM-2 algorithm) → return to task. Manages daily override budget (3/day).

**Models** (`Sources/MetaCog/Models/`) — GRDB record types conforming to `FetchableRecord`, `PersistableRecord`, and `Codable`. Key relationships:
- `ProjectRecord` → many `TaskRecord` (via `task.projectId`, cascade delete)
- `TaskRecord` → many `SubGoal`, `AppPermission`, `Intervention`, `AppUsageLog`
- `TaskRecord.projectId` is nullable — nil means standalone task (subject to 30-min limit)
- `TaskRecord.projectOrder` defines execution sequence within a project
- `SubGoal` → many `CheckIn`
- `AppPermission` supports `linkedGroupId` for grouped apps (switching within a group doesn't trigger interventions)
- `DailyOverride` is keyed by date string ("yyyy-MM-dd")
- `ProjectDebrief` and `TaskDebrief` store metacognition reflections

**Database** (`Sources/MetaCog/Database/DatabaseManager.swift`) — GRDB SQLite with migrations, foreign keys enabled, cascading deletes. Migration "v1" creates all tables (project, task, appPermission, subGoal, checkIn, intervention, ankiCard, taskDebrief, projectDebrief, dailyOverride, appUsageLog).

**Views** (`Sources/MetaCog/Views/`):
- `HUD/` — Always-visible floating NSPanel (360×130) with project timeline, task timer, and sub-goal progress. Toggle visibility via menu bar icon.
- `Planning/` — Task wizard (7-step), Project wizard (5-step), Anki gate (single-card challenge before wizard), task/project debrief wizards.
- `Intervention/` — Modal overlay for penalty timer and Anki challenge
- `Dashboard/` — 5-tab analytics (Analytics, Projects, Tasks, Cards, Database browser)

### Task Lifecycle

`planning → active → [paused ↔ active] → debriefing → [completed | abandoned]`

### Project Lifecycle

`planning → active → [paused ↔ active] → debriefing → [completed | abandoned]`

Projects contain sequential tasks. Tasks within a project must be completed in order. Users can pause a project to work on standalone tasks. The project debrief auto-triggers when all tasks are complete/abandoned, or on manual abandon.

### Standalone Task Limits

Tasks not belonging to a project (`projectId == nil`) are capped at 30 minutes:
- **Planning wizard:** Duration input clamped to 30 min; warning shown if sub-goal sum exceeds 30 min.
- **Runtime:** `TimeTracker.tick()` auto-triggers debrief when elapsed time hits 30 min.

### Anki Gate

Before creating any task or project, the user must answer a single Anki flashcard correctly. If no cards exist, they must add cards first. The gate view (`AnkiGateView`) uses the same SM-2 flow as interventions.

### Menu Bar

`MenuBarManager` creates a persistent `NSStatusItem` (white cog icon):
- **Left-click:** Toggles HUD panel visibility.
- **Right-click:** Quick actions menu (New Task, Pause/Resume, Dashboard, Settings, Quit).

### Key Conventions

- All services and state are `@MainActor` isolated — maintain this when adding new services
- Services coordinate through `AppState.shared`, never directly with each other
- GRDB dependency for all persistence — use its query interface, not raw SQL
- SwiftUI views receive state via `@EnvironmentObject` of `AppState`
- `AppDelegate` manages AppKit windows (NSPanel for HUD, NSWindow for planning/debrief/gate)
- Window show/hide is driven by `@Published` flags on `AppState`, observed via Combine in `AppDelegate`
- Dismissal from hosted SwiftUI views sets the AppState flag to false (not `@Environment(\.dismiss)`)
