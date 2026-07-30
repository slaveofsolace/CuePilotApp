# Validation

CuePilot uses deterministic tests and platform builds to protect the shot
engine, capture boundaries, and primary user journeys.

## Automated coverage

| Area | Coverage |
| --- | --- |
| Geometry and physics | Coordinate transforms, collision response, cushion reflection, bank geometry, scratch detection, and ghost-ball placement |
| Rules and strategy | Legal target selection, group assignment, called-pocket handling, direct shots, combinations, one-rail banks, and deterministic ranking |
| Session and calibration | Match transitions, calibration bounds, persistence round trips, live-state sequencing, and checksum rejection |
| Vision | Synthetic table detection, ball classification, perspective and lighting changes, touching balls, rails, and duplicate-frame handling |
| iPhone UI | Home navigation, Live Assist setup, privacy details, match controls, and calibration flow |
| Platform integration | iPhone app, Broadcast Upload Extension, App Intents framework, and native Mac app |
| Repository safety | Privacy, credential, private-API, and dependency checks |

The shared suite currently contains 52 XCTest cases. The iPhone UI suite contains
four end-to-end journeys and runs against an installed simulator application.

## Reproduce the checks

Run the complete local gate from the repository root:

```sh
./script/verify.sh
```

The script runs the shared tests, regenerates the Xcode project, builds the
iPhone and Mac targets, and performs repository safety scans.

Run the iPhone UI suite from Xcode with the `CuePilot` scheme, or from the
command line with a simulator destination:

```sh
xcodebuild \
  -workspace CuePilot.xcworkspace \
  -scheme CuePilot \
  -destination 'platform=iOS Simulator,name=<simulator>' \
  test
```

## Physical-device checks

ReplayKit broadcasts, Picture in Picture behavior, App Group signing, system
interruptions, and iPhone Mirroring capture depend on Apple services that are
not emulated by the simulator. A release candidate should therefore be tested
on a signed iPhone and with a live iPhone Mirroring window before distribution.

The recommended live matrix covers:

- broadcast start, stop, interruption, and stale-state recovery;
- Picture in Picture backgrounding, resizing, and orientation changes;
- nonblank iPhone Mirroring capture and explicit source selection;
- overlay alignment, click-through input, window movement, and display changes;
- sustained-session memory, thermal, energy, and latency behavior.
