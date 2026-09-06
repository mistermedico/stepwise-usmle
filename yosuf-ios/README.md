# Yosuf: Card Game (iOS)

A polished, native SwiftUI implementation of Yosuf — the classic Israeli card game (Yaniv-style: get your hand's value to 7 or below, declare "Yosuf!", or get caught with "Asaf!"). Single-player against rule-based computer opponents and local Pass & Play, with a from-day-one architecture ready for networked multiplayer later.

## Project layout

```
yosuf-ios/
├── project.yml                  XcodeGen spec — generates Yosuf.xcodeproj (never commit the .xcodeproj itself)
├── Packages/YosufEngine/        Pure Swift game engine — zero UIKit/SwiftUI imports, testable with `swift test`
│   ├── Sources/YosufEngine/
│   │   ├── Models/              Card, Deck, Meld, Player, RuleProfile, GameState, GameError, PartyEventCard...
│   │   ├── Engine/               GameEngine (the single state-mutating authority), MeldDetector, HandEvaluator, TableReader
│   │   ├── AI/                   OpponentEngine (rule-based decision tree), OpponentDifficulty, OpponentPersonality
│   │   ├── Ranking/               SkillRating (Elo-style), RankTier
│   │   └── DailyChallenge/       Deterministic daily scenario generator
│   └── Tests/YosufEngineTests/   Full unit test suite (see Testing below)
├── YosufApp/                     The SwiftUI app target (MVVM)
│   ├── App/                      App entry point, AppDelegate (AdMob/UMP boot), RootView (navigation root)
│   ├── DesignSystem/              Theme, CardFaceView, PlayerAvatarView, button styles, EmptyStateView
│   ├── Managers/                  SoundManager, HapticsManager, AdManager, AchievementEvaluator
│   ├── Persistence/                Core Data model + repositories (match history, achievements, player profile)
│   ├── ViewModels/                One view model per screen, MVVM
│   ├── Views/                     One folder per screen (Home, RuleProfiles, Game, Achievements, History, Settings, DailyChallenge, Onboarding)
│   └── Resources/                 he.lproj / en.lproj Localizable.strings + InfoPlist.strings, Assets.xcassets
├── fastlane/                      Automated signing + TestFlight upload (see APPLE_SETUP.md / SECRETS.md)
├── AppStoreMetadata/               Ready-to-paste App Store Connect listing text (he-IL, en-US)
├── Legal/                          Privacy policy (he, en)
├── APPLE_SETUP.md                  The only steps that require a human with Apple Developer access
└── SECRETS.md                      Exact list of GitHub Actions secrets needed for CI/CD
```

## Architecture

**Strict separation of pure logic from UI**, per the project's core quality requirement:

- `YosufEngine` is a standalone Swift Package with **no dependency on SwiftUI, UIKit, or Foundation networking**. It compiles and its full test suite runs with plain `swift test` — no simulator, no Xcode project needed. Every game rule (dealing, drawing, discarding/melding, Yosuf/Asaf resolution, scoring, match end, the AI opponent's decisions, the Daily Challenge's deterministic seeding) lives here.
- `YosufApp` is a thin SwiftUI/MVVM layer on top: view models call into `GameEngine`/`OpponentEngine` and publish `@Published` state; views only render what they're given. No game rule is duplicated in the UI layer.
- **Type safety**: colors, ranks, game phases, rule profiles, opponent difficulty/personality, and every error condition are closed Swift `enum`s — never raw strings or magic numbers.
- **No `print`**: the engine uses a small `EngineLogger` wrapping `os.Logger` (with a Linux/CI-safe fallback); the app layer uses `os.Logger` directly.

## Multiplayer roadmap (not implemented yet, by design)

Per the product plan, the first release ships **local-only**: play against bots, or Pass & Play on one device. The architecture already separates the pure game engine (`YosufEngine`) from any transport, so adding real-time networked multiplayer later means:

1. Add a new module (e.g. `YosufNetworking`) that depends on `YosufEngine` but adds nothing to it — the engine's `GameState`/`GameEngine` API doesn't change.
2. Stand up a thin relay (Firebase Realtime Database/Firestore, or a custom WebSocket service) that serializes `GameState`-driving *actions* (draw, discard, declare) between clients, with one client (or a server function) as the authoritative `GameEngine` runner.
3. Add a `RemoteOpponent`/`RemotePlayer` concept in the app layer that feeds actions from the network into the same `GameEngine` calls the local human/bot paths already use — `GameTableViewModel` would gain a "who controls this seat" concept (local human / bot / remote), but its core loop stays the same.
4. Firebase Auth (or Game Center) would provide player identity or, for anonymous quick-match, a generated Firebase Anonymous Auth UID.

None of this is implemented — this section exists purely so a future session (human or AI) knows where the seam is.

## Testing

```bash
cd Packages/YosufEngine
swift test --parallel
```

The suite covers: card/deck mechanics (including joker wildcards and full-deck edge cases), meld detection (sets, runs, boundary cases at Ace/King, invalid inputs), hand evaluation, the full `GameEngine` rule set (turn validation, every `GameError`, Yosuf/Asaf resolution including ties, deck-exhaustion reshuffling, match-end scoring), the rule-based AI opponent (threshold/caution-delay/personality behavior, meld-vs-single-card discard priority), the public-information-only table reader, skill rating, the deterministic Daily Challenge generator, and party event-card modifiers — plus `GameSimulationTests.swift`, which auto-plays several **complete matches start to finish** (every difficulty combination, every rule profile) purely through the public engine + AI API, asserting the match always converges to a valid, card-conserving conclusion.

CI (`.github/workflows/yosuf-ios-tests.yml`) runs this on every push/PR, then generates the Xcode project with XcodeGen and builds the full app for both the smallest supported simulator (iPhone SE) and the largest (iPhone 16 Pro Max), catching layout issues at the extremes.

**Known limitation of this development environment:** the engine and its full test suite were written and reasoned through carefully, but could not be executed locally in this session (no Apple/Swift toolchain available in this Linux container, and the corporate network policy blocks downloading one). The CI workflow is the first actual compiler/test run this code will get — treat the first CI run's results as the real verification, and fix forward from there if anything surfaces.

## Rule profiles

Five presets ship, all defined in `RuleProfile.swift` — every numeric knob is visible there, not hidden magic numbers:

| Profile | Yosuf threshold | Asaf penalty | Match ends at | Notes |
|---|---|---|---|---|
| Classic | 7 | 30 | 100 | The standard experience |
| Quick | 7 | 20 | 50 | Shorter matches |
| Grandma's Rules | 5 | 40 | 150 | Aces count as 15, stricter threshold |
| Street | 7 | 30 | 100 | Party event cards each round |
| Custom | user-defined | user-defined | user-defined | Sliders in-app, clamped to sane ranges |

## Local development

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).
2. From `yosuf-ios/`, run `xcodegen generate`.
3. Open `Yosuf.xcodeproj` in Xcode 16+.
4. Build & run on iOS 16+ simulator or device.

The generated `Yosuf.xcodeproj` is intentionally **not** committed — regenerate it any time from `project.yml`, which is the actual source of truth for project settings.
