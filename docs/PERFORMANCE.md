# Performance

CuePilot is designed for bounded, on-device analysis rather than continuous
full-resolution recording.

## Processing model

- Capture adapters keep only the newest eligible frame.
- Duplicate and incomplete frames are rejected early.
- Broadcast frames are downsampled before expensive analysis.
- Static table geometry is reused only while registration remains valid.
- Full board solving and high-rate cue or power tracking run at separate
  cadences.
- Guidance is cleared instead of presenting stale results.

`CueDiagnostics` records bounded numeric durations and counters for
preprocessing, vision, strategy, state transport, skipped frames, and uncertain
detections. It does not accept screenshots or arbitrary captured content.

## Release measurements

Performance measurements should report the complete capture-to-presentation
path, not vision duration alone:

1. source presentation timestamp;
2. capture callback receipt;
3. bounded frame-copy completion;
4. vision completion;
5. strategy completion;
6. state publication;
7. visible presentation commit.

A release review should cover static and changing boards, cue and power
movement, orientation changes, interruptions, window movement, display changes,
and sustained sessions. Record latency percentiles, skipped frames, memory,
energy, thermal state, and termination reason without collecting personal
screen content.
