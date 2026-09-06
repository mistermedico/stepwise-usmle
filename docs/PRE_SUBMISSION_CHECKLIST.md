# Pre-submission checklist

Work through this before pressing **Submit for Review**. Items marked
**automated** are already enforced by CI — the box is there so you notice when a
job was skipped, not so you repeat the work by hand.

## Correctness

- [ ] **automated** `swift test --package-path ios/OutbreakEngine` is green.
      Covers every global-response rule at all three tiers, the spread rules,
      determinism, and a full playthrough to victory.
- [ ] **automated** The app test bundle is green on **iPhone SE (3rd gen)** and
      **iPhone 15 Pro Max**.
- [ ] **automated** `python3 ios/tools/check_strings.py` reports no differences
      between the English and Hebrew tables.
- [ ] Play one complete run to victory and one to defeat on a device, not just
      the simulator.
- [ ] Play one Daily Challenge to completion and confirm the report is filed and
      the challenge shows as completed on the home screen.
- [ ] Background the app mid-run and return to it. The clock stops, and nothing
      is double-counted.

## Interface

- [ ] Every screen at the smallest size (iPhone SE) with **Larger Text** at its
      maximum: nothing clipped, nothing overlapping.
- [ ] Every screen at the largest size (Pro Max): no stranded content, no
      stretched controls.
- [ ] Light mode and dark mode, both — including the board, where the infection
      blot and the restriction hatch must stay distinguishable in both.
- [ ] Hebrew, with the layout mirrored: check the control panel, the ability map
      and the report timeline in particular.
- [ ] VoiceOver: swipe through the board and confirm each territory announces
      its name and status; confirm every ability node announces its cost.
- [ ] **Reduce Motion** on: the board stops breathing, the report appears in one
      piece, and nothing is left invisible mid-animation.
- [ ] Every tap target is at least 44×44pt.

## Content and tone

- [ ] No real country, city, organisation or person is named anywhere.
- [ ] No real disease, symptom set, treatment or historical event is referenced.
- [ ] Nothing in the app reads as medical information or advice.
- [ ] Screenshots and metadata carry the same fictional, light tone as the game.

## Ads and privacy

- [ ] Real AdMob unit IDs are in `AdUnits`, and `isUsingTestUnits` is `false`.
- [ ] `GADApplicationIdentifier` in `Info.plist` is the real AdMob app ID.
- [ ] The full `SKAdNetworkItems` list for the linked SDK version is in the plist.
- [ ] The ATT prompt appears once on first launch and never again.
- [ ] Declining tracking still leaves the game fully playable.
- [ ] **Settings → Ad preferences** opens the consent form in an EEA region
      (test with a VPN or a debug geography override).
- [ ] The privacy policy is live at the URL in both App Store Connect and
      `SettingsView.privacyURL`, and both point at the same page.
- [ ] App Privacy answers in App Store Connect match
      [`APP_STORE_METADATA.md`](APP_STORE_METADATA.md#app-privacy-answers).

## Build and store

- [ ] Version and build numbers bumped (`MARKETING_VERSION`,
      `CURRENT_PROJECT_VERSION` in `project.yml`).
- [ ] The app icon has no alpha channel and no rounded corners of its own.
- [ ] Screenshots supplied for 6.7" and 6.5", in both languages.
- [ ] Age rating answers submitted.
- [ ] Support and privacy URLs both resolve in a browser.
- [ ] Review notes pasted from `APP_STORE_METADATA.md`.
- [ ] The TestFlight build installs and launches on a real device from a clean
      install (delete the app first — a fresh install is the path most likely to
      be broken and least likely to be tested).
