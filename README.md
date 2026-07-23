# EMBER — iOS (SwiftUI)

Native SwiftUI port of the EMBER adaptive rest platform. Two evidence-based
protocol engines (Thermal Wind-Down + CBT-I Sleep Efficiency), a calendar-aware
adaptation agent, an accountability pod with Blue Box rewards, and a grounded
Rest Coach — with **Apple Health** sleep import.

## Requirements
- Xcode 15+ (iOS 16.0 deployment target — needed for HealthKit sleep-stage
  categories and Swift Charts)
- A physical device or simulator. HealthKit authorization prompts only work on
  device / a simulator with Health data.

## Open the project

This repo uses **XcodeGen** so the `.xcodeproj` isn't checked in (keeps the repo
clean and merge-friendly). Two options:

### Option A — generate the Xcode project (recommended)
```bash
brew install xcodegen         # one-time
cd EmberiOS
xcodegen generate             # creates Ember.xcodeproj
open Ember.xcodeproj
```

### Option B — no XcodeGen
1. Xcode → File → New → Project → iOS App → name it **Ember**, interface
   **SwiftUI**, language **Swift**.
2. Delete the auto-generated `ContentView.swift` and `EmberApp.swift`.
3. Drag the entire `Ember/` folder from this repo into the project
   (check "Copy items if needed", create groups).
4. Set the target's **Info.plist** to `Ember/Info.plist`.
5. Signing & Capabilities → **+ Capability → HealthKit**.
6. Build & run.

## HealthKit
- Usage strings live in `Ember/Info.plist` (`NSHealthShareUsageDescription`).
- `HealthManager` requests read access to `sleepAnalysis` and sums the last 24h
  of "asleep" samples into total sleep time, shown on the Today screen.
- The app never writes to Health.
- On the simulator, add sleep samples via the Health app to see live data;
  otherwise the app runs entirely on the bundled validated seed.

## Data
- All screens are driven by `Ember/Resources/seed.json` — the exact validated
  trajectories from the web build (12 thermal nights across 4 titration blocks;
  28 CBT-I nights across 4 weekly prescriptions; 3 calendar adaptations; a
  4-member pod). Every prescription in the seed obeys its titration rule.
- Apple Health, once authorized, augments this with your real last-night sleep.

## Architecture
```
Ember/
  EmberApp.swift            App entry, injects DataStore + HealthManager
  Models/Models.swift       Codable domain models (mirror the web schema)
  Algorithms/
    RestAlgorithms.swift    Pure engines: computeSE, nextTIB, nextOffset, adapt()
    RestCoach.swift         Grounded coach (drop-in point for a live LLM)
  Data/
    DataStore.swift         Observable store, loads seed
    Formatters.swift        Duration/time/date helpers
  Health/HealthManager.swift  HealthKit sleep import
  Views/                    Home, Thermal, CBTI, Calendar, Pod, Coach + components
  Theme/Theme.swift         Warm-ember dark palette + card styling
  Resources/seed.json       Validated seed data
```

## Swapping the Coach for a live LLM
`RestCoach.answer(to:store:)` is a pure function that returns grounded text from
the user's own data. To go live, replace its body with an async call to your LLM
endpoint, passing the same `store` context as structured JSON. The UI already
handles async replies.

## Notes / honest limitations
- Written without a local Xcode toolchain, so it is **not compile-verified**.
  Expect to resolve a small number of trivial issues on first build (imports,
  a Charts axis modifier name across Xcode versions). The architecture and
  algorithms are complete and self-consistent.
- iOS design: native `TabView`, `NavigationStack`, SF Symbols, `.ultraThinMaterial`
  cards, Swift Charts, Dynamic Type-friendly text styles, dark-mode-first palette.
