# CuePilot

CuePilot is a clean-room billiards companion for iPhone and Mac. It analyzes
visible pixels on the device, recommends a legal 8-ball shot, and presents aim
and power guidance while the player remains in control.

The repository contains working Swift implementations for screenshot review,
geometry, physics, rules, shot ranking, live-state transport, ReplayKit
broadcast processing, Picture in Picture presentation, and a macOS
ScreenCaptureKit overlay. It is still a pre-release project: signed-device
capture, live iPhone Mirroring capture, TestFlight, notarization, and normal
installation have not been qualified.

## Product boundaries

CuePilot does not:

- inject code into another application;
- use jailbreak frameworks, private APIs, memory patches, or hidden game state;
- automate taps, drags, cursor movement, aim, power, or shot release;
- alter another application's rules, score, statistics, physics, or files;
- silently start screen capture;
- upload screen frames or require a network connection for analysis;
- provide a transparent coordinate-anchored overlay on iPhone.

The iPhone live guide uses a system-managed Picture in Picture window. It
cannot attach a transparent overlay to another iPhone application.

## iPhone workflows

### Screenshot analysis

1. Choose a screenshot with the system photo picker.
2. CuePilot analyzes it on the device.
3. Review and, when needed, move the table corners, six pockets, and detected
   balls.
4. Add or remove balls and correct each ball's classification.
5. Set the player's group, turn, and called 8-ball pocket when required.
6. Continue only after the board passes validation.
7. Review the legal-shot recommendation, path, power range, confidence, and
   scratch or foul warnings.

The current screenshot UI supports those corrections. It does not yet persist
a match history or a durable iPhone calibration profile.

### Live Assist

1. Open CuePilot and choose **Start Live Assist**.
2. Start CuePilot's broadcast through Apple's system broadcast picker.
3. Start Picture in Picture from CuePilot when the system reports it available.
4. Return to the billiards game.
5. The Broadcast Upload Extension analyzes bounded, downsampled frames.
6. Compact guidance state is exchanged through an App Group.
7. The player performs every aim and shot manually.

The source implements this flow, including sequence-checked transport and stale
state handling. It still requires a signed physical-iPhone test for ReplayKit,
Picture in Picture, memory, thermal behavior, interruptions, and stability.
See [Live Assist feasibility](docs/LIVE_ASSIST_FEASIBILITY.md).

## Mac workflow

The Mac application is intended to view the iPhone screen through Apple's
iPhone Mirroring application:

1. Open iPhone Mirroring and show the billiards game.
2. Open CuePilot for Mac.
3. Grant macOS Screen Recording permission when requested.
4. Refresh the source list and explicitly confirm the iPhone Mirroring window.
5. Choose **Start Analysis**.
6. CuePilot captures only that selected window and places a transparent,
   click-through AppKit panel over its visible content.

Capture does not start merely because the application opens or discovers a
window. The current implementation includes stale-frame shutdown, window
registration, move/resize tracking, display-scale adjustment, and explicit
stop controls. Apple does not guarantee that iPhone Mirroring will appear as a
capturable, nonblank ScreenCaptureKit source, so this workflow remains
unverified until it is exercised with a live mirrored iPhone.

See [Mac installation](docs/MAC_INSTALLATION.md) and
[Mac overlay feasibility](docs/MAC_OVERLAY_FEASIBILITY.md).

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
| `Sources/CueCalibration` | Versioned calibration model and local store |
| `Sources/CueSession` | Match-state reconciliation and local store |
| `Sources/CuePresentation` | Guidance stabilization and compact live state |
| `Sources/CueDiagnostics` | Bounded numeric diagnostics |
| `Sources/CueTestSupport` | Synthetic fixtures and deterministic test support |
| `Resources` | Original assets and privacy manifests |
| `docs` | Architecture, evidence, privacy, and release records |

## Toolchain and build status

The project targets iOS 18.0 and macOS 15.0 with Swift 6.

The current Mac has Xcode 26.6 build 17F113 selected, Swift 6.3.3,
XcodeGen 2.46.0, and the iOS 26.5 and macOS 26.5 SDKs. No iOS Simulator runtime
is installed. An iOS runtime download was canceled near completion to avoid
exhausting disk space; allow roughly 15–20 GB of additional free space before
trying again.

Recorded validation includes 52 Swift package tests, strict lint, release
compilation, Xcode static analysis, 80 seeded legality boards, 60 seeded
clearance/ghost-overlap boards, and a synthetic vision performance smoke test.
Xcode also compiles and links the iPhone app, embedded Broadcast Upload
Extension, App Intents framework, and native Mac app. The current SDK-only
iPhone build excludes the asset-catalog phase because no simulator runtime is
installed.

Those checks are not a simulator launch or signed-device run. Exact results
are recorded in [the test report](docs/TEST_REPORT.md); simulator UI tests
remain blocked by the missing runtime.

Generate the project with:

```sh
xcodegen generate
open CuePilot.xcworkspace
```

Use the `CuePilot` scheme for iPhone and `CuePilotMac` for Mac. Signing,
provisioning, App Group capability assignment, and physical-device testing
require an authorized Apple Developer team.

## Documentation

| Area | Documents |
| --- | --- |
| Evidence | [Environment](docs/ENVIRONMENT_REPORT.md), [test report](docs/TEST_REPORT.md), [performance](docs/PERFORMANCE_REPORT.md) |
| Engineering | [Architecture](docs/ARCHITECTURE.md), [vision](docs/VISION_PIPELINE.md), [physics and strategy](docs/PHYSICS_AND_STRATEGY.md), [calibration](docs/CALIBRATION.md) |
| Feasibility | [iPhone Live Assist](docs/LIVE_ASSIST_FEASIBILITY.md), [Mac overlay](docs/MAC_OVERLAY_FEASIBILITY.md) |
| Privacy and release | [Privacy](docs/PRIVACY.md), [distribution](docs/DISTRIBUTION.md), [dependency licenses](docs/DEPENDENCY_LICENSES.md) |
| Installation | [Internal TestFlight](docs/TESTFLIGHT_INSTALLATION.md), [Mac](docs/MAC_INSTALLATION.md) |

## Privacy

Analysis is designed to stay on the device. The source contains no analytics or
advertising SDK and declares no collected data or tracking. Captured frames are
processed as bounded transient buffers, not retained as a screen recording.
The screenshot picker provides only the selected image; the current flow keeps
its decoded working image in application memory and does not create an
application-managed screenshot file.

The final privacy declaration still requires verification against signed
binaries. See [Privacy](docs/PRIVACY.md).

## Release status

There is no installable release yet. No signed iPhone archive, TestFlight build,
Developer ID Mac package, notarization ticket, or release checksum has been
produced. See [Distribution](docs/DISTRIBUTION.md).

## License

Released under the [MIT License](LICENSE).

CuePilot is not affiliated with Apple or any third-party game developer. The
legacy reference archive is not a dependency, and its code, icons, declarations,
and proprietary assets are excluded from this repository.
