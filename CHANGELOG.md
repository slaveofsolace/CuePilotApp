# Changelog

All notable changes to CuePilot will be recorded here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
The project uses semantic versioning for planned releases.

## Unreleased

### Added

- SwiftUI iPhone application with screenshot selection, on-device analysis,
  table/pocket/ball correction, ball classification, 8-ball rule controls,
  recommendation display, Live Assist setup, settings, and calibration
  surfaces.
- ReplayKit Broadcast Upload Extension with bounded frame acceptance,
  downsampling, on-device analysis, sequence-checked App Group transport, and
  stale-state handling.
- System Picture in Picture guidance owned by CuePilot and started through an
  explicit action.
- Native SwiftUI/AppKit Mac application with ScreenCaptureKit window discovery,
  explicit start/stop analysis, a click-through overlay panel, stale-frame
  shutdown, registration tracking, and local overlay controls.
- Shared implementations for vision, geometry, physics, 8-ball legality, direct
  and bank/combination candidates, ranking, calibration, session
  reconciliation, presentation, diagnostics, and deterministic test support.
- Swift package, XcodeGen project, workspace, App Intents, privacy manifests,
  Fastlane configuration, and locked Ruby dependencies.
- Original CuePilot design concepts and application icon assets.
- Legacy audit, public-API feasibility research, architecture, privacy, testing,
  performance, installation, and distribution documentation.

### Validation

- Passed a strict Swift 6 module-compilation checkpoint.
- Passed 31 compatibility checks, 80 seeded legality boards, and 60 seeded
  path/ghost-clearance boards.
- Recorded a synthetic 384 × 240 vision smoke at 93.64 ms median and 97.94 ms
  P95.
- Typechecked the complete iPhone application source set and Broadcast Upload
  Extension separately against the iOS Simulator SDK in Swift 6 mode after the
  release fixes.
- Passed `swift build --target CuePilotMac` after the Mac release fixes.
- Passed 52 Swift package tests, release compilation, strict lint, and Xcode
  static analysis for the iPhone target graph and Mac scheme.
- Passed Xcode compilation and linking for the iPhone app, embedded Broadcast
  Upload Extension, App Intents framework, and native Mac application.

### Security

- Established public-API-only, no-injection, no-input-automation, and
  on-device-processing boundaries.
- Adopted an MIT-licensed clean-room source and original-asset policy.

### Known limitations

- Xcode 26.6 and Apple SDKs are installed, but no iOS Simulator runtime is
  installed; simulator and UI tests remain blocked.
- Simulator UI validation remains blocked until the iOS runtime is installed.
- Live ReplayKit/Picture in Picture and ScreenCaptureKit/iPhone Mirroring
  behavior remain pending signed-device and live-window testing.
- The iPhone calibration and match screens are not wired to their durable
  shared stores.
- The public GitHub remote is configured, but no release tag, TestFlight build,
  notarized Mac artifact, or installable package has been produced.
