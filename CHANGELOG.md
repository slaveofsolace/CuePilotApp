# Changelog

All notable changes to CuePilot are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## Unreleased

### Added

- iPhone screenshot analysis with manual table, pocket, ball, classification,
  turn, group, and called-pocket correction.
- Legal 8-ball recommendations for direct shots, two-ball combinations, and
  one-rail banks.
- Confidence-aware shot paths, power guidance, scratch warnings, and match
  controls.
- ReplayKit Live Assist with compact App Group state and Picture in Picture
  presentation.
- Native Mac companion with explicit iPhone Mirroring window selection,
  ScreenCaptureKit analysis, and a click-through guidance panel.
- Local calibration, session, diagnostics, App Intents, privacy manifests, and
  deterministic test coverage.
- Original application icon and interface assets.

### Fixed

- Added framework metadata required to embed the App Intents target in simulator
  and device builds.
- Made generated Xcode project output reproducible from a clean checkout.
- Updated UI tests for Swift concurrency isolation.
- Updated simulator-runtime detection in the verification script.

### Security

- Restricted capture to explicit user actions and public Apple APIs.
- Kept frame analysis on the device without analytics or advertising services.
- Added credential, privacy, private-API, and dependency checks.
