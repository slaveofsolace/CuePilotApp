# Test Report

Report date: 2026-07-30
Release candidate: pre-release source
Overall result: partial pass; not release-qualified

## Environment boundary

Xcode 26.6 build 17F113, Swift 6.3.3, XcodeGen 2.46.0, and the iOS 26.5
and macOS 26.5 SDKs are installed. No iOS Simulator runtime is installed, so
simulator unit tests, UI tests, and simulator screenshots remain blocked.

No valid signing identity, provisioning profile, physical-iPhone test, live
iPhone Mirroring capture, TestFlight upload, or notarized Mac path is available.

## Recorded results

These results were produced during implementation. Results marked
**checkpoint** predate the current first-pass source freeze.

| Check | Result | Evidence and boundary |
| --- | --- | --- |
| Legacy ZIP integrity and inspection | Pass | Archive integrity and regular-file inspection completed; reference files remain outside shipping source |
| Strict Swift 6 module compilation | Pass, checkpoint | Shared modules compiled under strict Swift 6 checks |
| Compatibility test runner | Pass, checkpoint | 31 checks passed |
| Randomized legality property boards | Pass, checkpoint | 80 deterministic seeds; no illegal recommended target observed |
| Randomized path/ghost-clearance boards | Pass, checkpoint | 60 deterministic seeds; clear paths and ghost centers satisfied checked invariants |
| Live-state support smoke | Pass, checkpoint | Restarted writer published sequence `101`; encoded wire size `128` bytes; stable guidance reached after `240 ms` |
| Synthetic vision smoke | Pass, checkpoint | Clean fixture detected 6 balls; dark fixture detected 5; details in `PERFORMANCE_REPORT.md` |
| Complete iPhone source typecheck | Pass | Typechecked against the iOS Simulator SDK in Swift 6 mode after the iOS release fixes |
| Broadcast Upload Extension typecheck | Pass | Typechecked separately against the iOS Simulator SDK in Swift 6 mode after the extension fixes |
| Swift Package Manager Mac target build | Pass | `swift build --target CuePilotMac` passed after the Mac release fixes |
| Xcode project generation | Pass, checkpoint | XcodeGen 2.46.0 generated the project and workspace; resource phases were inspected |
| Target privacy-manifest syntax | Pass | iPhone app, Broadcast Upload Extension, and Mac manifests pass `plutil -lint` |
| Current iOS SDK build | Pass | Xcode compiled and linked the app, Broadcast Upload Extension, and App Intents framework; the asset-catalog phase was skipped because no simulator runtime was installed |
| Broadcast Upload Extension integration | Pass | The extension compiled, linked, embedded in the app, and passed Xcode embedded-binary validation |
| Current Xcode Mac build | Pass | Native `CuePilotMac.app` built and passed Xcode bundle validation |
| Current Swift package test suite | Pass | 52 XCTest cases passed |
| Static analysis | Pass | Xcode `analyze` passed for the iOS target graph and Mac scheme |
| Private-API and jailbreak-framework scan | Pass | No prohibited implementation was found in shipping sources |
| Secret and privacy scans | Pass | No credential signature, local user path, personal email, Xcode user data, or development-tool attribution was found |
| SwiftLint | Pass | Strict lint passed using the repository policy |
| iOS simulator tests | Blocked | No installed CoreSimulator runtime |
| iOS UI tests | Blocked | No installed CoreSimulator runtime |
| Physical iPhone install/launch | Not run | No signed device path |
| ReplayKit game capture | Not run | Requires signed physical-device testing |
| Picture in Picture | Not run | Requires signed physical-device testing |
| Mac iPhone Mirroring capture | Not run | Requires Screen Recording permission and a live mirrored source |
| Mac overlay click-through/alignment | Not run live | Source implementation exists; live window evidence is pending |
| Fifteen-minute stability | Not run | Neither live route has been qualified |
| Release archive | Not run | Signing unavailable |
| TestFlight upload/install | Not run | Signing and App Store Connect path unavailable |

The synthetic and compatibility checks validate bounded subsystems. They do not
establish live-capture accuracy, App Review acceptance, physical-device
reliability, or distribution readiness.

## First-pass build record

| Final command | Configuration/destination | Result | Artifact or log |
| --- | --- | --- | --- |
| `swift test --parallel` | macOS host | Pass, 52 tests | Swift Package test bundle |
| `swift build -c release` | macOS host | Pass | Release `CuePilotMac` product and shared modules |
| `xcodebuild … -target CuePilot … build` | iOS 26.5 simulator SDK, arm64, assets excluded | Pass | Unsigned app with embedded extension and framework under `DerivedData/Target-iOS-NoAssets` |
| `xcodebuild … CuePilotMac … build` | macOS, arm64 | Pass | `DerivedData/Mac-Release/Build/Products/Debug/CuePilotMac.app` |
| `xcodebuild … analyze` | iOS target graph and Mac scheme | Pass | `DerivedData/Analyze-iOS` and `DerivedData/Analyze-macOS` |
| `swiftlint lint --strict --quiet` | Publishable source, generated and build output excluded | Pass | Repository lint policy |

Record the exact destination, SDK, configuration, exit code, warning count, and
artifact path. A generic SDK build must not be reported as a simulator launch,
signed-device run, or installation.

## Automated suite coverage in source

### Geometry and physics

- vector normalization, angle wrapping, and rotation;
- segment and line-circle intersections;
- ghost-ball construction;
- pocket-mouth and jaw clearance;
- bank reflection and physical cushion contact;
- ball collision response, combinations, and scratch routes;
- projective coordinate transforms.

### Rules, strategy, and session

- open-table and assigned-group target legality;
- early 8-ball rejection and required final pocket;
- ball in hand, scratches, turn changes, and terminal states;
- deterministic candidate ranking;
- direct, combination, and one-rail bank candidates;
- before/after board reconciliation;
- explicit opponent 8-ball legality;
- value-semantic manual corrections.

### Transport and presentation

- compact-state encode/decode and checksum rejection;
- recovery from a corrupt newest slot;
- monotonic sequence across a writer restart;
- stable aim and power requirements before ready guidance;
- bounded aggregate-only diagnostics.

### Vision

- synthetic clean, perspective, dark, compressed, touching-ball, and rail cases;
- cue and power controls present or absent;
- table, pocket, ball, and classification output;
- manual correction value semantics;
- duplicate-frame skip behavior without retaining the source frame.

### User interface

UI-test source covers Home and primary destinations, Settings and Privacy,
manual match controls, and the calibration surface. These UI tests have not run
because no simulator runtime is installed.

## Signed iPhone acceptance matrix

| Requirement | Result |
| --- | --- |
| Explicit system broadcast start | Not run |
| Visible game frames from the intended game | Not run |
| Bounded extension memory | Not measured |
| Picture in Picture after app backgrounding | Not run |
| Recursive capture handling | Not run |
| Cue and power tracking | Not measured live |
| Manual shot control only | Source-reviewed; runtime audit pending |
| Orientation and interruption recovery | Not run |
| Fifteen-minute stability | Not run |

## Mac acceptance matrix

| Requirement | Result |
| --- | --- |
| Screen Recording permission flow | Not run |
| Explicit Mirroring-window selection | Implemented; not run live |
| Selected stream returns nonblank pixels | Not run |
| Overlay registers to captured content | Implemented; not run live |
| Overlay follows move, resize, and display scale | Implemented; not run live |
| Input passes through the overlay | Implemented; not run live |
| Stale or invalid capture hides guidance | Implemented; not run live |
| Fifteen-minute stability | Not run |

## Release decision

Do not distribute this checkout as a qualified binary release. The first-pass
source builds, tests, analysis, lint, and scans pass, but simulator UI evidence
has not yet been produced. A normal iPhone release also requires signed-device
ReplayKit/Picture in Picture evidence and a successful archive. A normal Mac
release requires live Mirroring capture evidence, Developer ID signing,
Hardened Runtime review, notarization, packaging, and a clean-install test.
