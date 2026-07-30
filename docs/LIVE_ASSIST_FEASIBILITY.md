# iPhone Live Assist Feasibility

Status: candidate public-API workflow; signed-device proof not completed

## Verdict

A normal iPhone can provide user-approved full-screen frames to a Broadcast
Upload Extension through ReplayKit. A foreground app can prepare sample-buffer
Picture in Picture content. These are public APIs, but their availability does
not prove that:

- the active third-party game appears as usable pixels;
- the extension remains within memory and thermal limits;
- PiP remains visible and updates after the host app backgrounds;
- PiP is not recursively captured;
- the workflow meets latency and stability targets;
- the presentation is accepted in App Review.

Xcode 26.6 and the iOS 26.5 SDK are now installed. The iPhone app, Broadcast
Upload Extension, App Group transport, and Picture in Picture guide are
implemented in source. There is still no signed physical-iPhone build,
provisioning profile, or development team available, so Live Assist remains
unverified at runtime.

## Stable architecture

```text
System broadcast picker
        |
        v
ReplayKit Broadcast Upload Extension
        |
        +-- bounded frame acquisition
        +-- table/cue/power vision
        +-- rules, geometry, and guidance
        |
        v
Versioned compact state in App Group
        |
        +-- host application status/session UI
        +-- sample-buffer visual feed for user-started PiP
        +-- system-managed visual PiP guide
```

ReplayKit callbacks are serial. The supplied sample buffer cannot be retained
after the callback returns. The current extension gates frames before
conversion, downsamples accepted input to a maximum analysis dimension of 720
pixels, limits acceptance to 10 Hz, keeps at most one analysis task active, and
does not retain a frame history. Physical-device memory and thermal behavior
still require measurement.

## Start and stop behavior

1. The person taps the system-owned broadcast picker.
2. The person confirms the CuePilot extension.
3. The extension creates a session and begins publishing compact state.
4. The person starts PiP through an explicit CuePilot action when PiP is
   supported and possible.
5. The person returns to the game and controls it manually.
6. Ending the broadcast clears transient state and releases buffers.

There is no silent-start capture path. App Groups provide shared storage and
IPC; they do not grant background execution or wake a suspended host app.

## Compact transport

The implemented transport is a compact, versioned, two-slot file transport
with:

- schema version, sequence number, and monotonic timestamp;
- orientation and canonical table transform;
- table, cue, power, and rules confidence;
- turn and group assignment;
- current and required angles;
- signed angular error and valid corridor;
- recommended and visible power;
- target ball and pocket;
- alignment state and warning flags.

The writer publishes a complete slot and advances a monotonic sequence. Readers
validate the schema and checksum, reject stale state, and can fall back from a
corrupt newest slot. A writer-restart smoke published sequence `101` after an
existing sequence `100`; the current encoded state was `128` bytes.
`UserDefaults(suiteName:)` carries low-rate manual configuration, not
frame-rate guidance state. No frame preview is stored in the App Group.

## Picture in Picture

`AVPictureInPictureController.ContentSource` can use an
`AVSampleBufferDisplayLayer`. The presentation should be a real continuously
changing visual feed, such as an annotated table crop or a rendered live table
view driven by current detector state.

PiP is not:

- transparent;
- attached to table coordinates;
- guaranteed to remain in a chosen location;
- free of system playback controls;
- permission to run arbitrary background work;
- permission to control the game.

The annotated crop is easier to defend as media but costs bandwidth and can
create recursive capture. A rendered table is lighter but may appear to use PiP
as generic utility UI. Both require review in the feasibility build.

## Adaptive processing plan

| Work | Intended cadence |
| --- | --- |
| Scene-change detection | Every accepted frame |
| Static table and ball solve | On meaningful board change |
| Cue tracking | Approximately 8–15 FPS |
| Power tracking while changing | Approximately 10–20 FPS |
| Opponent turn | Reduced cadence |
| PiP preview | Lower than analytical state unless profiling proves headroom |

Targets are not measurements:

- initial solve near or below 1 second;
- median visible response at or below about 250 ms;
- P95 response at or below about 400 ms;
- at least 15 minutes of continuous stable operation.

## Required signed-device test

| Check | Result |
| --- | --- |
| System picker starts the extension | Not run |
| Active game board produces usable frames | Not run |
| Protected or blank-frame behavior | Not run |
| PiP starts only from user interaction | Not run |
| PiP remains visible after backgrounding | Not run |
| PiP updates continuously | Not run |
| Recursive PiP capture | Not run |
| Orientation and interruption recovery | Not run |
| Capture-to-guidance median/P95 | Not measured |
| Dropped frames and extension memory | Not measured |
| Battery and thermal effect | Not measured |
| 15-minute stability | Not run |
| No retained recording or network transfer | Not runtime-audited |

## Failure modes and fallback

- Blank or unavailable frames: stop live guidance and offer screenshot analysis.
- PiP unavailable: keep the broadcast state visible in CuePilot and offer audio
  guidance only while the supported lifecycle allows it.
- Recursive capture: mask the known PiP region only if the region can be
  identified reliably; otherwise disable the visual PiP route.
- Low confidence: show `SEARCHING` or `DO NOT SHOOT`; never reuse a stale green
  state.
- Extension pressure: reduce cadence and preview resolution, then stop cleanly
  before correctness degrades.

## Official references

- [RPSystemBroadcastPickerView](https://developer.apple.com/documentation/replaykit/rpsystembroadcastpickerview)
- [RPBroadcastSampleHandler](https://developer.apple.com/documentation/replaykit/rpbroadcastsamplehandler)
- [Processing broadcast sample buffers](https://developer.apple.com/documentation/replaykit/rpbroadcastsamplehandler/processsamplebuffer(_:with:))
- [Configuring app groups](https://developer.apple.com/documentation/xcode/configuring-app-groups)
- [AVPictureInPictureController](https://developer.apple.com/documentation/avkit/avpictureinpicturecontroller)
- [Adopting Picture in Picture in a Custom Player](https://developer.apple.com/documentation/avkit/adopting-picture-in-picture-in-a-custom-player)
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
