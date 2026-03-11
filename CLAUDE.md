# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

This is a Swift Package Manager macOS app (Swift 6.0, macOS 15+).

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

MetaCog is a macOS productivity app that enforces focus during task work. It monitors foreground apps, blocks unauthorized app switches with escalating penalties (exponential timer + Anki flashcard challenges), and tracks time per-app.

### Core Layers

**App** (`Sources/MetaCog/App/`) — `MetaCogApp` delegates to `AppDelegate`, which manages window lifecycle (HUD panel, dashboard window), initializes services, and recovers interrupted tasks on relaunch.

**Services** (`Sources/MetaCog/Services/`) — Four singletons, all `@MainActor`:
- `AppState.shared` — Central state machine with `@Published` properties. All UI and services coordinate through this, not through each other.
- `TimeTracker` — Monitors app switches via `NSWorkspace` notifications and screen lock via `DistributedNotificationCenter`. Runs a 1-second timer, creates `AppUsageLog` entries, guards against sleep time jumps (>5s).
- `CheckInScheduler` — Polls every 5 seconds, triggers check-ins at cumulative 50% and 90% of sub-goal duration.
- `InterventionManager` — Three-phase flow on unauthorized app switch: exponential penalty timer (`15 * 2^count` seconds) → Anki card challenge (SM-2 algorithm) → return to task. Manages daily override budget (3/day).

**Models** (`Sources/MetaCog/Models/`) — GRDB record types conforming to `FetchableRecord`, `PersistableRecord`, and `Codable`. Key relationships:
- `TaskRecord` → many `SubGoal`, `AppPermission`, `Intervention`
- `SubGoal` → many `CheckIn`
- `AppPermission` supports `linkedGroupId` for grouped apps (switching within a group doesn't trigger interventions)
- `DailyOverride` is keyed by date string ("yyyy-MM-dd")

**Database** (`Sources/MetaCog/Database/DatabaseManager.swift`) — GRDB SQLite with migrations, foreign keys enabled, cascading deletes. Single migration "v1" creates all 11 tables.

**Views** (`Sources/MetaCog/Views/`):
- `HUD/` — Always-visible floating NSPanel with task timer and sub-goal progress
- `Planning/` — 7-step wizard (title → justification → apps → groups → sub-goals → duration → confirm)
- `Intervention/` — Modal overlay for penalty timer and Anki challenge
- `Dashboard/` — 4-tab analytics (Analytics, Tasks, Cards, Database browser)

### Task Lifecycle

`planning → active → [paused ↔ active] → debriefing → [completed | abandoned]`

### Key Conventions

- All services and state are `@MainActor` isolated — maintain this when adding new services
- Services coordinate through `AppState.shared`, never directly with each other
- GRDB dependency for all persistence — use its query interface, not raw SQL
- SwiftUI views receive state via `@EnvironmentObject` of `AppState`
- `AppDelegate` manages AppKit windows (NSPanel for HUD, NSWindow for dashboard)