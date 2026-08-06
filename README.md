# CuePilot — work in progress, app is ab 80% complete

CuePilot is an on-device billiards companion for iPhone and Mac. It analyzes a
visible 8-ball table, recommends a legal shot, and presents aim and power
guidance while the player remains in control.

## Features

- Screenshot analysis with editable table corners, pockets, balls, and
  classifications
- 8-ball rules for open tables, solids, stripes, scratches, and called pockets
- Direct-shot, two-ball combination, and one-rail bank candidates
- Confidence-aware aim corridors, power ranges, and scratch warnings
- iPhone Live Assist through ReplayKit and Picture in Picture
- Mac guidance over a user-selected iPhone Mirroring window
- Local calibration, match-state, diagnostics, and accessibility support
- No account, analytics service, advertising SDK, or network requirement

## iPhone

### Screenshot analysis

1. Select a screenshot with the system photo picker.
2. Review the detected table, pockets, and balls.
3. Correct geometry or classification when needed.
4. Set the group, turn, and called 8-ball pocket.
5. Review the recommended path, power range, confidence, and warnings.

### Live Assist

1. Open CuePilot and choose **Start Live Assist**.
2. Start the CuePilot broadcast from Apple's system broadcast picker.
3. Start Picture in Picture.
4. Return to the billiards game and take each shot manually.

The broadcast extension analyzes bounded frames on the device and shares only
compact guidance state with the host app. Picture in Picture is managed by iOS;
it is not a transparent overlay attached to another application.

See [Live Assist](docs/LIVE_ASSIST.md) for platform behavior and privacy
boundaries.

## Mac

CuePilot for Mac works alongside Apple's iPhone Mirroring app:

1. Open iPhone Mirroring and display the billiards game.
2. Open CuePilot for Mac and grant Screen Recording permission.
3. Select and confirm the iPhone Mirroring window.
4. Choose **Start Analysis**.

Guidance appears in a separate click-through panel that follows the selected
window. Capture starts only after explicit confirmation and stops when the
source becomes invalid or stale.

See [Mac installation](docs/MAC_INSTALLATION.md) and
[Mac overlay](docs/MAC_OVERLAY.md).

## Product boundaries

CuePilot does not:

- inject code into another application;
- use jailbreak frameworks, private APIs, memory patches, or hidden game state;
- automate taps, drags, cursor movement, aim, power, or shot release;
- change another application's rules, score, statistics, physics, or files;
- silently start screen capture;
- upload captured frames or retain a screen recording.

## Build

Requirements:

- a Mac with an Xcode release that supports iOS 18 and macOS 15 targets;
- [XcodeGen](https://github.com/yonaskolb/XcodeGen);
- an Apple Developer team for signed device builds and App Group entitlements.

Generate the workspace and open it in Xcode:

```sh
brew install xcodegen
./script/generate_project.sh
open CuePilot.xcworkspace
```

Use the `CuePilot` scheme for iPhone and `CuePilotMac` for Mac.

Run the complete local verification gate with:

```sh
./script/verify.sh
```

The gate runs 52 shared tests, regenerates the project, builds the iPhone and
Mac targets, and checks the repository for private APIs, credentials, personal
paths, and undeclared dependencies. The iPhone UI suite covers four primary
navigation and privacy journeys.

## Repository layout

| Path | Role |
| --- | --- |
| `Apps/iOS/CuePilot` | iPhone application |
| `Extensions/BroadcastUpload` | ReplayKit Broadcast Upload Extension |
| `Apps/iOS/AppIntents` | App Intents and Shortcuts |
| `Apps/macOS/CuePilotMac` | ScreenCaptureKit capture and click-through overlay |
| `Sources/CueVision` | Table, ball, cue, power, and UI-state analysis |
| `Sources/CueGeometry` | Canonical coordinates and billiards geometry |
| `Sources/CuePhysics` | Collision and trajectory modeling |
| `Sources/CueStrategy` | Rules, candidate generation, ranking, and guidance |
| `Sources/CueCalibration` | Calibration model and local store |
| `Sources/CueSession` | Match-state reconciliation and local store |
| `Sources/CuePresentation` | Guidance stabilization and compact live state |
| `Sources/CueDiagnostics` | Bounded numeric diagnostics |
| `Tests` | Deterministic engine and UI coverage |

## Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [Vision pipeline](docs/VISION_PIPELINE.md)
- [Physics and strategy](docs/PHYSICS_AND_STRATEGY.md)
- [Calibration](docs/CALIBRATION.md)
- [Privacy](docs/PRIVACY.md)
- [Performance](docs/PERFORMANCE.md)
- [Validation](docs/VALIDATION.md)
- [Known limitations](docs/KNOWN_LIMITATIONS.md)
- [Distribution](docs/DISTRIBUTION.md)

## Privacy

Analysis is designed to stay on the device. Captured frames are processed as
bounded transient buffers and are not retained as a recording. The screenshot
picker grants access only to the image selected by the user.

See [Privacy](docs/PRIVACY.md) for data handling details.

## License

Released under the [MIT License](LICENSE).

CuePilot is not affiliated with Apple or any third-party game developer.
