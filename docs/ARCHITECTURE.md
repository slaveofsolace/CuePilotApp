# Architecture

## Status

`Package.swift` and `project.yml` declare the target and module boundaries
described here. XcodeGen 2.46.0 has generated the project and workspace, shared
modules passed a strict Swift 6 compilation checkpoint, the iPhone application
and extension source sets typechecked against the iOS Simulator SDK, and
`swift build --target CuePilotMac` passed after the release fixes. Fresh Xcode
workspace builds are recorded separately in `TEST_REPORT.md`.

No target has been signed, installed on an iPhone, exercised through live
iPhone Mirroring, uploaded to TestFlight, or notarized. Runtime statements
remain requirements unless the test report records direct evidence.

## Product topology

```text
                       CuePilot suite
                             |
            +----------------+----------------+
            |                                 |
        iPhone path                        macOS path
            |                                 |
  ReplayKit Broadcast Extension      ScreenCaptureKit stream
            |                                 |
      compact App Group state          selected-window metadata
            |                                 |
   iOS app + user-started PiP        click-through AppKit overlay
            \                                 /
             +------- shared packages -------+
```

The shared pipeline converts platform frames into a canonical table state,
produces legal shot candidates, estimates robust aim and power ranges, updates
match state, and emits presentation-neutral guidance.

## Application targets

| Target | Responsibility | Declared platform |
| --- | --- | --- |
| `CuePilot` | iPhone screenshot review, manual rules state, live setup, settings, in-memory calibration controls, and PiP ownership | iOS 18.0 |
| `CuePilotBroadcast` | ReplayKit sample handling and bounded live analysis | iOS 18.0 |
| `CuePilotAppIntents` | Explicit shortcuts into supported CuePilot actions | iOS 18.0 |
| `CuePilotMac` | Window selection, capture, analysis status, calibration tools, and overlay ownership | macOS 15.0 |

The XcodeGen configuration embeds the Broadcast Upload Extension in the iPhone
application and gives the iPhone app and extension the same App Group
identifier. Signing must confirm that the final entitlements use an authorized
team and provisioning profile.

## Shared modules

| Module | Ownership |
| --- | --- |
| `CueGeometry` | Vectors, points, segments, circles, table geometry, pockets, cushions, projective transforms, and path clearance |
| `CuePhysics` | Equal-mass collision response, friction, restitution, rail response, cue-ball continuation, and trajectory simulation |
| `CueStrategy` | 8-ball legality, candidate generation, shot ranking, robust corridors, power ranges, and guidance states |
| `CueCalibration` | Local versioned profiles, conservative outcome updates, reset, confidence decay, and persistence |
| `CueSession` | Match lifecycle, board reconciliation, turn/group state, required pocket, and prior shot outcomes |
| `CuePresentation` | Platform-neutral live state, overlays, warnings, target identifiers, and accessibility text |
| `CueDiagnostics` | Bounded numeric counters and latency summaries; the iPhone export action is not yet wired |
| `CueVision` | Frame normalization, table/ball/cue/power detection, temporal tracking, and confidence |
| `CueTestSupport` | Synthetic boards, fixtures, seeded random inputs, and shared assertions |

Dependencies flow inward. Geometry has no dependency on platform capture or UI.
Physics depends on geometry. Strategy depends on geometry and physics. Vision
produces geometry models. Session coordinates strategy and calibration.
Presentation consumes output models without owning the solver.

## Capture abstraction

Platform capture should conform to a small boundary such as:

```swift
protocol ScreenFrameProvider: Sendable {
    var frames: AsyncThrowingStream<ScreenFrame, Error> { get }
    func start() async throws
    func stop() async
}
```

`ScreenFrame` should own its accepted pixel storage, timestamp, orientation,
pixel dimensions, color information, and coordinate metadata. ReplayKit and
ScreenCaptureKit adapters remain in their application targets. The core modules
must not import ReplayKit, ScreenCaptureKit, AppKit, or UIKit merely to process
a table.

This boundary allows ReplayKit to remain the stable iOS 18 implementation while
an iOS ScreenCaptureKit provider can be evaluated after the API becomes stable.

## Live pipeline

```text
Frame provider
    |
    +-- validate status and timestamp
    +-- discard stale or duplicate work
    +-- crop and normalize table
    |
    v
Vision observation
    |
    +-- confidence gate
    +-- temporal association
    +-- manual-correction merge
    |
    v
Rules + geometry + physics + strategy
    |
    +-- legal candidate set
    +-- scratch/foul analysis
    +-- robust corridor and power range
    |
    v
Session reconciliation + optional calibration model
    |
    v
Compact presentation state
```

Every stage carries a sequence number and timestamp. A downstream result is
discarded when a newer board revision supersedes it. Green guidance requires
legal state, sufficient confidence, a robust interval, consecutive agreement,
and no active foul or scratch warning.

## Concurrency and back pressure

- Shared session and calibration stores use actor isolation.
- Current iPhone screens do not yet write those durable stores.
- Capture adapters publish owned, bounded frame values.
- Static board solving and high-rate cue/power tracking use separate task
  classes or priorities.
- At most one full solve is pending for a board revision.
- New frames may replace stale unstarted work.
- Cancellation is checked between expensive stages.
- The broadcast callback returns quickly after copying only required data.
- Presentation reads immutable snapshots.

No component should accumulate a frame history to improve throughput. If the
consumer falls behind, it skips stale frames and preserves the newest state.

## Coordinate systems

The core uses a canonical 2:1 table coordinate space. Capture-specific transforms
map source pixels to canonical points. Presentation-specific transforms map
canonical points to PiP or overlay coordinates.

Required transforms:

1. source pixels to detected quadrilateral;
2. quadrilateral to canonical table;
3. canonical table to output surface;
4. for macOS, output points to global screen coordinates using per-frame
   ScreenCaptureKit metadata.

Transforms are versioned with their observations so points from different frame
registrations cannot be combined.

## Persistence

The shared modules provide local persistence for:

- calibration profiles;
- match sessions;
- bounded numeric diagnostics;

The current iPhone UI does not write the calibration or session stores and its
diagnostic export button is a placeholder. The Mac app persists presentation,
manual rule state, and calibration controls in user defaults.

Raw frames and recordings are transient. The Broadcast Upload Extension shares
only compact analytical state; it does not publish a screenshot or frame
archive.

## Platform presentation

The iPhone app uses standard SwiftUI navigation, controls, sheets, search, and
accessibility behavior. PiP is a system-managed media surface, never described
as a true overlay.

The Mac app uses conventional window and toolbar structure. The assist surface
is a separate transparent `NSPanel` with `ignoresMouseEvents = true`.
Calibration controls remain in a normal interactive window.

Custom Liquid Glass is optional and availability-gated. It must not replace
standard sidebars, toolbars, sheets, or controls.

## Security boundaries

- Public Apple APIs only.
- No runtime injection or private target-game API.
- No automated control of another application.
- Explicit user action for capture and PiP.
- No frame upload or analytics SDK.
- No secrets, personal fixtures, or signing material in source control.
- Network access is not required for analysis.

## Verification gates

Architecture is accepted only after:

1. Swift package tests pass.
2. The Xcode workspace generates without manual file repair.
3. iOS app and extension build together with valid App Group signing.
4. macOS app builds with expected sandbox and capture behavior.
5. source and binary scans find no private APIs or secrets.
6. signed-device feasibility matrices are complete.
7. latency, memory, energy, and stability results are recorded.

Project generation and subsystem checkpoints have completed. The remaining
build, signing, live-capture, performance, and distribution gates are tracked
individually in `TEST_REPORT.md`.
