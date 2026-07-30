# Performance Report

Report date: 2026-07-30
Measurement status: synthetic smoke measured; live performance unmeasured

## Current measurements

The recorded vision smoke used generated 384 × 240 RGBA table images on the
development Mac. It did not use ReplayKit, iPhone Mirroring, a physical camera,
or a production screenshot corpus.

| Observation | Recorded value | Scope |
| --- | ---: | --- |
| Clean synthetic fixture | 6 balls detected | One controlled fixture |
| Dark synthetic fixture | 5 balls detected | One controlled fixture |
| Cue-angle absolute error | 0.07057 rad, approximately 4.04° | Synthetic cue line |
| Detected normalized power | 0.5787 | Synthetic visible power control |
| Median analysis duration | 93.64 ms | 384 × 240 synthetic input |
| P95 analysis duration | 97.94 ms | Same smoke run and input class |

These values show that the implemented detector runs and produces plausible
output on controlled fixtures. They are not accuracy claims for a game,
device, screenshot collection, broadcast, or Mirroring stream.

The compatibility pass also covered 80 seeded legality boards and 60 seeded
path/ghost-clearance boards. No invariant failure occurred in that checkpoint.
Those counts are correctness evidence, not frame-rate or end-to-end latency
measurements.

## Product targets

| Metric | Target | Current evidence |
| --- | ---: | --- |
| Initial table solve | Approximately 1 second or less | Synthetic 384 × 240 median 93.64 ms; live input unmeasured |
| Cue-direction update rate | Approximately 8–15 FPS | Not measured live |
| Power update rate while moving | Approximately 10–20 FPS | Not measured live |
| Median capture-to-visible-guidance latency | Approximately 250 ms or less | Not measured |
| P95 capture-to-visible-guidance latency | Approximately 400 ms or less | Not measured |
| Continuous live session | At least 15 minutes | Not run |
| Ball-center error on representative fixtures | Below approximately 0.2 ball radii | Not measured |
| Solid/stripe classification when discernible | At least 95% on a reviewed corpus | Not measured |
| Illegal recommendations | 0 known in randomized rules tests | 80 seeded legality boards passed at checkpoint |

Targets remain design goals unless a row contains a bounded measurement.

## Instrumentation

`CueDiagnostics` accepts bounded numeric latency samples and counters for:

- frame preprocessing;
- table, ball, cue, and power analysis;
- strategy solving;
- state transport;
- analyzed and skipped frames;
- uncertain detections and manual corrections;
- transport failures and session transitions.

The diagnostics data model rejects images and arbitrary captured content. The
current iPhone Diagnostics button is not connected to a file exporter, so no
user-facing export result is claimed.

Capture-to-guidance latency must identify all endpoints:

1. source presentation timestamp;
2. callback receipt;
3. bounded frame-copy completion;
4. vision completion;
5. strategy completion;
6. state publication;
7. presentation commit.

Vision duration alone is not end-to-end visible latency.

## Required live matrix

Future measurements should cover:

- the slowest supported iPhone class and one current iPhone;
- orientation changes, notifications, interruptions, and app backgrounding;
- ReplayKit with Picture in Picture active and inactive;
- static board, cue movement, power movement, and opponent turn;
- Mac portrait and landscape iPhone Mirroring windows;
- Retina and mixed-scale external displays;
- move, resize, minimize, reconnect, sleep, and wake;
- warm and thermally constrained 15-minute sessions.

Record process and extension memory, CPU/GPU use, skipped and stale frames,
queue depth, battery change, energy impact, thermal transitions, termination
reason, and Mac registration error. Apple does not publish a durable ReplayKit
extension memory allowance that can replace physical-device measurement.

## Adaptive behavior

The implementation should continue to:

1. process at most one accepted frame at a time;
2. downsample bounded broadcast frames before analysis;
3. skip duplicate or unnecessary frames;
4. reuse only valid static table state;
5. omit optional expensive candidate types under pressure;
6. clear guidance when state becomes stale or invalid.

Guidance must not remain in a ready state merely to preserve frame rate.

## Final performance insertion

Before release, append the device and live results:

| Platform/source | Device and OS class | Duration | Median/P95 | Memory/thermal | Result |
| --- | --- | ---: | --- | --- | --- |
| ReplayKit + Picture in Picture | Pending | Pending | Pending | Pending | Not run |
| iPhone Mirroring + Mac overlay | Pending | Pending | Pending | Pending | Not run |

No battery, thermal, live latency, live accuracy, or 15-minute stability claim
is currently supported.
