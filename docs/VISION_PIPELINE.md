# Vision Pipeline

## Status

The deterministic vision pipeline is implemented and passed strict Swift 6
compilation plus synthetic smoke checks. At 384 × 240, the recorded smoke
detected 6 balls in a clean fixture and 5 in a dark fixture, with 93.64 ms
median and 97.94 ms P95 analysis duration.

End-to-end accuracy has not been measured on a reviewed screenshot corpus,
ReplayKit frames, or an iPhone Mirroring stream.

## Inputs and outputs

Inputs:

- ReplayKit video sample buffers;
- ScreenCaptureKit window frames and metadata;
- user-selected screenshots;
- synthetic test boards;
- manual corrections.

Primary output:

```text
VisionObservation
  frame sequence and timestamp
  source-to-canonical transform
  table, cushion, pocket, and jaw geometry
  balls with kind, center, radius, confidence, and track identity
  cue direction and confidence
  visible aiming-line evidence
  normalized power and movement state
  spin, turn, group, highlighted-pocket, and terminal-state evidence
  warnings and correction provenance
```

## Pipeline stages

### 1. Frame admission

- Accept only complete, monotonic frames.
- Reject malformed dimensions and unsupported pixel formats.
- Hash or compare a reduced luminance sample to skip duplicates.
- Keep the newest eligible frame when analysis is backlogged.
- Preserve orientation, crop, color, and ScreenCaptureKit scale metadata.

### 2. Region isolation

- Detect the probable play region from color, edge, contour, and aspect-ratio
  evidence.
- Suppress known operating-system chrome and CuePilot presentation regions.
- Require a plausible convex table quadrilateral.
- Carry multiple candidates when confidence is ambiguous.

### 3. Perspective normalization

- Order the four detected table corners.
- Solve a homography into the canonical 2:1 table.
- Warp only the required luminance and color channels.
- Derive point and radius scale from local transform behavior.
- Reject ill-conditioned transforms.

### 4. Static table model

Detect or infer:

- playable cushion boundaries;
- four corner pockets and two side pockets;
- pocket mouths and jaw points;
- table orientation and rail gaps;
- expected ball-radius range.

The table model is cached until meaningful scene change, a strong geometry
residual, orientation change, or manual reset invalidates it.

### 5. Ball candidates

Use deterministic circle and blob evidence first:

- local contrast and color segmentation;
- circularity across scales;
- edge support;
- expected radius in canonical coordinates;
- rail and pocket proximity;
- temporal continuity.

A lightweight classifier may distinguish cue, 8-ball, solid, stripe, and
unknown. Unknown is a valid state and should trigger correction or conservative
strategy, not a forced classification.

Touching and partly occluded balls need multi-circle fitting and temporal
evidence. A candidate becomes a stable track only after spatial and appearance
agreement.

### 6. Cue and aiming evidence

- Search for long narrow cue-stick edges outside the cue ball.
- Detect any visible game aiming line as independent evidence.
- Estimate the current angle in canonical coordinates.
- Fuse cue-stick and aiming-line estimates only when their confidence and
  geometry agree.
- Smooth angle on the circle, not with a linear average across ±180 degrees.
- Mark the cue unavailable rather than extrapolating a stale direction.

### 7. Power and spin

Within a calibrated UI region:

- detect the usable power track;
- detect the handle or pullback location;
- normalize position to `[0, 1]`;
- identify whether the control is changing;
- report confidence and last-change timestamp.

Spin is reported only when the control is visible and its mapping is calibrated.
No universal power percentage is inferred from screen distance alone.

### 8. Game-state evidence

The vision layer may expose evidence for:

- current turn;
- open/solids/stripes group state;
- highlighted required pocket;
- ball-in-hand presentation;
- win, loss, or interrupted state.

Rules remain in `CueStrategy` and `CueSession`. Vision observations never decide
that a shot is legal on their own.

### 9. Temporal tracking and scene change

Static and dynamic work run at different rates:

| Signal | Scheduling |
| --- | --- |
| Table and pocket geometry | On initial frame and material scene change |
| Ball layout | On board change and after a shot |
| Cue angle | Approximately 8–15 FPS when aiming |
| Power control | Approximately 10–20 FPS while moving |
| Turn/UI state | Low-cost observation at accepted frame cadence |
| Opponent turn | Reduced processing |

Track association uses position, radius, kind likelihood, and a bounded motion
model. A shot transition invalidates tracks that cannot be reconciled.

## Confidence

Every important observation carries calibrated confidence. Overall board
confidence should decrease when:

- the table transform is unstable;
- expected pockets are missing;
- ball count or radius is implausible;
- tracks overlap ambiguously;
- the cue is occluded;
- the power control is unavailable;
- the visual style changes from the calibration profile.

Low confidence produces `SEARCHING`, `ANALYZING`, or `DO NOT SHOOT`. It cannot
produce a green lock.

## Manual correction

The current screenshot-review UI can correct:

- table corners and pockets;
- missed, false, or misplaced balls by adding, removing, or moving them;
- ball classification;
- current group and turn;
- required 8-ball pocket.

The manual correction model is value-semantic. A new screenshot begins a new
review; the current iPhone UI does not persist correction provenance across a
durable match session.

## Test fixtures

Synthetic fixtures should randomize:

- legal ball layouts and touching clusters;
- table color, brightness, shadow, and compression;
- perspective, scale, orientation, and crop;
- rail and pocket highlights;
- cue angle, cue presence, and obstruction;
- power-track visibility and position;
- operating-system overlays and partial occlusion.

Personal screenshots remain ignored by Git and outside release artifacts.
Third-party artwork is not bundled.

## Acceptance targets

These are targets, not current results:

- ball-center error below approximately 0.2 ball radii on golden fixtures;
- near-perfect cue-ball and 8-ball classification on golden fixtures;
- at least 95% solid/stripe classification where visually discernible;
- no unrecoverable workflow from one imperfect automatic detection;
- initial full solve near or below one second on supported devices.

Measurements belong in `TEST_REPORT.md` and `PERFORMANCE_REPORT.md`.
