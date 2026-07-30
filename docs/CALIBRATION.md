# Calibration

`CueCalibration` implements a versioned calibration profile, bounded outcome
updates, confidence decay, normalized power parameters, and actor-isolated JSON
storage.

The iPhone screen maintains session-local calibration and applies a small
angular correction for **Missed left** and **Missed right**. The shared durable
profile store is independent of that screen.

The Mac application persists manual aim bias and overlay display scale in user
defaults and applies them to guidance and overlay presentation.

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
size, and every parameter is clamped. Automated tests cover bounded updates and
value semantics.

## Persistence

`CalibrationStore` can list, create, update, upsert, remove, and reset profiles
in an atomically replaced local JSON envelope. It contains no networking API.

The iPhone calibration screen uses session-local state rather than this store:

- applying an outcome on iPhone does not create a durable shared profile;
- leaving or terminating the app can discard the current iPhone correction;
- **Reset Calibration** clears current iPhone runtime correction state, not a
  durable profile database;
- the Settings copy describes reset behavior as session-local.

The Mac calibration controls use a separate local user-defaults path.

## User controls

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

The shared model also supports profile creation, selection, confidence,
sample-history metadata, full outcome learning, and sanitized numeric export.

Calibration accuracy measurements should identify the profile, device class,
sample count, outcome provenance, and measured residual error.
