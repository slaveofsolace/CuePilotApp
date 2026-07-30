# Calibration

## Current status

`CueCalibration` implements a versioned calibration profile, bounded outcome
updates, confidence decay, normalized power parameters, and actor-isolated JSON
storage. The module passed a strict Swift 6 compilation checkpoint.

The iPhone application screen is not yet wired to that full profile or store.
It currently maintains calibration state in memory and changes only a small
angular correction for **Missed left** and **Missed right**. Other visible
outcomes do not yet drive the shared calibration engine from the UI.

The Mac application persists manual aim bias and overlay display scale in user
defaults and applies them to guidance/overlay presentation. Live convergence
has not been measured.

## Shared calibration model

The shared model can represent:

- aim bias;
- power scale and offset;
- rolling resistance;
- cushion restitution;
- ball-ball restitution;
- pocket tolerance;
- touch-drag scale;
- device display scale;
- a visual game-version label;
- sample count, confidence, and update time.

Separate profiles are intended to prevent observations from one device or
visual layout from silently changing another.

Calibration does not change target legality. Rules are evaluated before
calibration affects uncertainty, simulation, or presentation.

## Outcome model

The shared source recognizes:

- pocketed successfully;
- missed left or right;
- hit the left or right jaw;
- hit a cushion before the pocket;
- too weak or too hard;
- scratched;
- cue ball stopped early or traveled too far;
- unexpected collision.

Its update policy is bounded:

- left/right misses move aim bias in opposite directions;
- weak/hard outcomes change power within clamped limits;
- travel observations can refine power and rolling resistance;
- cushion and unexpected-collision outcomes make conservative parameter
  changes;
- successful shots gradually increase confidence and reduce residual bias.

Observation confidence scales an update, sample count reduces later update
size, and every parameter is clamped. These behaviors are implemented in the
shared source and have test cases, but the final XCTest run must be recorded in
`TEST_REPORT.md`.

## Persistence

`CalibrationStore` can list, create, update, upsert, remove, and reset profiles
in an atomically replaced local JSON envelope. It contains no networking API.

This store is not currently connected to the iPhone calibration screen.
Therefore:

- applying an outcome on iPhone does not create a durable shared profile;
- leaving or terminating the app can discard the current iPhone correction;
- **Reset Calibration** clears current iPhone runtime correction state, not a
  durable profile database;
- the Settings copy must not promise deletion of stored learning until the
  store is wired and tested.

The Mac calibration controls use a separate local user-defaults path.

## Current user controls

### iPhone

- choose one outcome label for the last shot;
- apply a left/right angular adjustment;
- inspect a simple calibrated/needs-samples state;
- reset the current correction.

### Mac

- adjust aim bias between −4° and +4°;
- adjust overlay display scale between 90% and 110%;
- reset both values;
- retain those values locally in user defaults.

Profile creation, profile selection, confidence inspection, sample history,
full outcome learning, and sanitized export are shared-model capabilities, not
completed iPhone UI features.

## Validation status

| Check | Status |
| --- | --- |
| Strict Swift 6 module compilation | Passed at checkpoint |
| Bounded values for declared outcomes | Test source present; final XCTest result pending |
| Session/calibration JSON round trip | Test source present; final XCTest result pending |
| Left/right sign convention | Test source present; final XCTest result pending |
| Weak/hard power monotonicity | Final XCTest result pending |
| Store create/update/remove/reset | Final XCTest result pending |
| Concurrent actor access | Final XCTest result pending |
| iPhone screen-to-store integration | Not implemented |
| Mac preference persistence | Implemented; runtime UI verification pending |
| Real-device convergence | Not run |

Any reported accuracy or convergence must identify the profile, device class,
sample count, outcome provenance, and measured residual error.
