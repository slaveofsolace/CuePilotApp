# Physics and Strategy

This document records the solver contract. Geometry, physics,
8-ball rules, direct shots, two-ball combinations, one-rail banks, ranking,
robust corridors, and normalized power guidance are implemented.

## Canonical model

The solver operates on:

- cue and object-ball centers and radii;
- cushion segments;
- pocket mouths, jaws, aim points, and capture regions;
- obstacle balls;
- current group and legal target set;
- required 8-ball pocket;
- turn and ball-in-hand state;
- calibration and detection uncertainty.

All positions are in the canonical 2:1 table coordinate space. Screen
coordinates do not enter physics calculations directly.

## Direct-shot geometry

For cue-ball center `C`, target center `T`, pocket aim point `P`, and ball
radius `r`:

```text
u = normalize(P - T)
G = T - 2r * u
```

`G` is the ghost-ball center required for ideal equal-radius contact. The cue
ball aims from `C` toward `G`, not toward `T`, unless the shot is straight.

A candidate is rejected unless:

- `G` is reachable inside the playable region;
- the cue-center path to `G` clears all obstacle balls with uncertainty margin;
- the target-center path crosses the pocket mouth between expanded jaws;
- the path reaches the effective capture region;
- cushion, jaw, and unrelated ball collisions are absent;
- first contact and target choice are legal;
- scratch and foul risk remain below the configured threshold.

Pockets are openings with jaws, not point targets.

## Combinations and banks

Two-object-ball combinations are solved backward:

1. choose the final ball and pocket;
2. solve the final contact normal;
3. place the intermediary ghost contact;
4. solve the cue ball's required ghost center;
5. validate every center path, contact, clearance, and legal-first-contact rule.

Bank candidates mirror the pocket across a cushion, intersect the theoretical
line with the physical cushion segment, and then validate the real path,
restitution, jaws, and obstacles. Banks rank below a reliable direct shot unless
their expected outcome is clearly stronger.

## Collision model

For an equal-mass ball collision, relative incident velocity is decomposed into
normal and tangential components at contact. The normal component transfers to
the object ball subject to restitution; the cue ball retains the tangential
component. Rolling friction reduces speed with travel. Cushion response reflects
the normal component with cushion restitution.

The current implementation supports:

- straight and cut shots;
- thin cuts;
- simple combinations;
- one-rail banks;
- cue-ball continuation and scratch paths.

Spin is optional and should be introduced only after center-ball behavior is
calibrated. A model that cannot estimate spin reliably should enlarge
uncertainty rather than invent precision.

Multi-rail shots, spin-aware trajectories, caroms, cluster breakouts,
dedicated safeties, and deep look-ahead are outside the current
release-qualified candidate set.

## Rules

The rules engine owns:

- open table;
- solids or stripes assignment;
- remaining legal targets;
- legal first contact;
- early 8-ball prohibition;
- required final pocket;
- ball in hand;
- turn transition;
- win and loss state.

The strategy layer requests legal targets from the rules engine. It does not
filter illegal candidates after ranking. An early 8-ball candidate must never
enter the candidate set.

## Candidate generation

For each legal target:

1. enumerate plausible pockets;
2. generate direct shots;
3. generate simple combinations where appropriate;
4. generate bank or safety candidates only when useful;
5. reject geometric and legal failures;
6. estimate power and post-contact cue-ball path;
7. evaluate uncertainty through deterministic seeded perturbation;
8. rank the survivors.

Candidate identity is stable for an unchanged board so repeated solves remain
deterministic.

## Robust alignment corridor

A shot is not represented by one exact angle. The solver perturbs:

- ball centers and radius;
- cue angle;
- power;
- rolling friction;
- ball and cushion restitution;
- pocket tolerance;
- calibration bias.

The valid interval is the contiguous angle range whose simulated outcomes meet
the legal pocketing threshold. Nearby obstacles, jaw clearance, cut angle, and
human touch jitter narrow the range.

The corridor may be marked locked only when:

- the shot remains legal;
- all required paths are clear;
- detector confidence is sufficient;
- estimated success exceeds the configured threshold;
- multiple consecutive frames agree;
- the cue remains inside the interval for roughly 200–300 ms;
- no scratch or foul warning is active.

## Direction guidance

The current cue angle is compared with the valid circular interval. The output
contains:

- current and required angle;
- minimum and maximum valid angle;
- signed shortest angular correction;
- clockwise or counterclockwise instruction;
- confidence and estimated success;
- `SEARCHING`, `ANALYZING`, `ROTATE LEFT`, `ROTATE RIGHT`,
  `FINE ALIGNMENT`, `AIM LOCKED`, `MORE POWER`, `LESS POWER`, `READY`,
  or `DO NOT SHOOT`.

Presentation must test the sign convention with explicit screen-coordinate and
canonical-coordinate fixtures so left/right instructions cannot silently
invert.

## Power guidance

Power is a normalized interval, not a falsely exact universal value. Inputs
include:

- cue-to-contact and target-to-pocket travel;
- cut angle;
- collisions and rails;
- desired cue-ball position;
- pocket tolerance;
- cluster requirements;
- calibration profile and uncertainty.

The visible power status becomes ready only when the measured control lies
inside the recommended interval and aim is independently safe. CuePilot never
releases the shot.

## Full-match strategy

The longer-term match strategy is:

1. reconcile the board with the previous observation;
2. confirm turn and legal target set;
3. generate and filter candidates;
4. estimate pot, scratch, foul, and next-position outcomes;
5. search additional plies only where reliable;
6. choose the highest-percentage legal plan;
7. guide aim and power;
8. observe and record the result.

Priority:

1. reliable direct pot with useful position;
2. reliable direct pot;
3. simple combination;
4. productive safety;
5. bank or kick only when necessary.

On an open table, compare group clearance, clusters, pocket access, and future
8-ball access. During the opponent's turn, suppress shot guidance. Before the
final 8-ball, require complete group clearance, the correct pocket, clear paths,
legal contact, controlled power, no scratch path, and high confidence.

The iPhone UI supplies manual group, turn, and called-pocket state. It does not
persist prior shots or perform multi-ply match planning.

## Test coverage

- exact vector, ghost-ball, line-circle, segment, jaw, and bank fixtures;
- legal-state transitions and early 8-ball rejection;
- randomized layouts with no illegal recommendations;
- no obstacle intersection for a candidate marked clear;
- no overlapping ghost position;
- deterministic ranking for identical state and seed;
- corridor contraction as uncertainty grows;
- analytical collision conservation and restitution checks within tolerance;
- sign-correct left/right guidance around angle wrap;
- calibrated power monotonicity and bounded output.
