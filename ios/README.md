# Strainwave

An abstract strategy puzzle for iOS: evolve a fictional pathogen across twelve
invented territories before a rule-based global response finds a solution.

Everything in the game is invented — the strain, its symptoms, the territories
and the science. Nothing is modelled on a real disease or event.

## Getting it running

```bash
brew install xcodegen
cd ios/Strainwave
xcodegen generate
open Strainwave.xcodeproj
```

The Xcode project is generated rather than committed: `project.yml` is the whole
build configuration in forty readable lines, where a `project.pbxproj` would be
four thousand unreviewable ones.

Run the simulation tests without Xcode at all:

```bash
swift test --package-path ios/OutbreakEngine
```

## How it is laid out

```
ios/
├── OutbreakEngine/           A Swift package. The entire game, minus the pixels.
│   ├── Sources/OutbreakEngine/
│   │   ├── Models/           Regions, traits, strains, state, reports
│   │   ├── Content/          The catalogs: the board, the ability map, the samples
│   │   ├── Rules/            Spread, global response, evolution, objectives
│   │   └── Engine/           The seeded generator and the day loop
│   └── Tests/                ~120 assertions, no simulator required
├── Strainwave/
│   ├── project.yml           XcodeGen specification
│   ├── Sources/
│   │   ├── App/              Entry point, composition root, routing
│   │   ├── Design/           Palette, type, motion, the pathogen glyph
│   │   ├── Views/            SwiftUI screens
│   │   ├── ViewModels/       The two observable models
│   │   ├── Services/         Feedback, ads, consent, logging, localisation
│   │   ├── Persistence/      Core Data, declared in code
│   │   └── Resources/        Strings, assets, Info.plist
│   ├── Tests/                Localisation coverage, persistence, view models
│   └── UITests/              A whole run through the screens, accessibility,
│                             Hebrew, and the text-size extremes
└── tools/                    Icon renderer, strings checker
```

### Why the engine is a separate package

`OutbreakEngine` imports Foundation and nothing else — no SwiftUI, no UIKit. Two
things follow, and both were the point:

- Every rule can be asserted directly against a fixed board, in seconds, with no
  simulator booting in the background. CI runs the whole rule suite as its first
  and fastest job.
- The simulation cannot quietly grow a dependency on the interface. A rule that
  needs a view to work is a rule that cannot be tested, and there is no way to
  write one here.

### Determinism

Every random decision in a run goes through one `SeededGenerator` carried inside
`GameState`. Given the same seed and the same purchases, a run plays out
identically on every device, every time. That is what makes the Daily Challenge
genuinely shared with no server, and what lets the tests assert exact states.

### The global response

`GlobalResponseEngine` is the opponent, and it is a plain decision tree: five
documented rules, evaluated in order, with closed-form arithmetic. There is no
model and no training. Rules 1–3 and 5 touch no randomness at all — rule 5 in
particular returns a solution date you can compute in advance, which is why the
game can always show the player exactly how many days are left.

Each rule has its own group of tests, exercised at all three difficulty tiers.

## The interface tests

`UITests/` drives the real app on a simulator: it plays a run from the control
panel to its report, evolves an ability, checks the clock stops when paused,
leaves a run, walks all twelve territories through VoiceOver, runs the same
script against the Hebrew build, and checks the largest and smallest content
sizes with the primary controls measured against 44pt.

They found four defects the unit tests could not: a finished run that never
reached its summary, a primary action unreachable at large text sizes, a board
that stopped laying out inside a scroll view, and type that silently ignored
Dynamic Type.

Three test affordances live in the app, all read from launch arguments and all
listed in `A11y.LaunchArgument`: reset stored state, skip the consent prompts
(system alerts a test cannot dismiss), and shorten the gap between simulated
days. The last one changes the timer only — the simulation is untouched, so a
run plays out exactly as it would at normal speed.

Apple's accessibility audit runs on three screens and **reports** rather than
fails: it samples a live screen, so a finding can depend on where a scroll view
happens to be. The CI summary prints it on every run.

### Status

The interface suite runs on every push but is **advisory** — CI reports its
result without failing on it. Nine of its twelve checks pass consistently on
both devices; the rest are still timing-sensitive on the smallest simulator
under CI load, where a whole run has to play out inside a fixed budget. A gate
that goes red for that reason is a gate people learn to ignore, so it does not
block yet. The unit suites do.

Finishing this means making the remaining checks deterministic rather than
patient — most likely by letting a test drive the simulated clock directly
instead of waiting on it — and then deleting `continue-on-error` from the
workflow.

## Ads

The ad layer is optional at compile time. Every AdMob file is wrapped in
`#if canImport(GoogleMobileAds)`, so the project builds, the tests pass and the
game plays with the SDK absent — ad slots simply do nothing. See
[`docs/RELEASE.md`](../docs/RELEASE.md#3-switching-the-ad-sdk-on) to switch it
on. The unit IDs currently in the source are Google's public **test** IDs, and a
test fails until they are replaced.

## Regenerating the icon

```bash
python3 ios/tools/make_app_icon.py
```

Dependency-free: the icon is drawn from signed-distance fields and encoded with
`zlib`, so it can be rebuilt anywhere without a design tool.

## Checking the translations

```bash
python3 ios/tools/check_strings.py
```

Compares every `Localizable.strings` table for missing keys, duplicates, empty
values and mismatched format specifiers — the last of which would crash
`String(format:)` at runtime rather than merely looking wrong.

## Before you submit

[`docs/PRE_SUBMISSION_CHECKLIST.md`](../docs/PRE_SUBMISSION_CHECKLIST.md).
