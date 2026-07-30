# Known Limitations

Snapshot date: 2026-07-30

## Build and release

- Xcode and the required SDKs are installed, but no iOS Simulator runtime is
  installed. Simulator unit tests, UI tests, and rendered simulator evidence
  are blocked until sufficient disk space is freed and a runtime is installed.
- No valid signing identity, provisioning profile, or development team is
  configured for the command-line build.
- No physical-iPhone installation or launch has been recorded.
- GitHub command-line authentication, the first public source push, and a
  release tag remain pending. The owner-approved public remote is configured.
- No signed iOS archive, TestFlight build, Developer ID Mac artifact,
  notarization, installer package, or checksum exists.
- The manual `script/build_and_run.sh` Mac bundle is a development smoke route.
  It does not replace Xcode target validation, code signing, Hardened Runtime
  review, notarization, or clean-account installation.

## iPhone Live Assist

- ReplayKit and Picture in Picture are implemented in source but have not been
  exercised on a signed physical iPhone.
- A person must start capture through Apple's system broadcast picker.
- CuePilot cannot silently capture another application.
- Picture in Picture is a system-managed video window, not a transparent
  coordinate-anchored overlay.
- Picture in Picture size, position, controls, and lifecycle are controlled by
  the system.
- Recursive Picture in Picture capture, extension memory, battery, thermal
  behavior, interruptions, orientation changes, and 15-minute stability remain
  unmeasured.
- Utility-style Picture in Picture carries App Review risk.
- Live state is intentionally invalidated when packets become stale; the app
  may require the broadcast to be restarted.

## Mac iPhone Mirroring overlay

- The Mac application depends on Apple's separate iPhone Mirroring application;
  it does not replace or emulate that application.
- The person must grant Screen Recording permission, open iPhone Mirroring,
  confirm the desired source window, and choose **Start Analysis**.
- Capture and guidance do not start merely because CuePilot opens or discovers
  a likely source.
- Apple does not document a stable identifier or a guarantee that the
  iPhone Mirroring window will return nonblank ScreenCaptureKit pixels.
- There is no public bypass when the source is absent, redacted, or excluded.
- The click-through panel is a separate cross-process window, not a child of
  the Mirroring window.
- Move/resize tracking, mixed display scale, Spaces, Stage Manager, Mission
  Control, full screen, sleep/wake, and reconnect handling are implemented but
  not verified against a live Mirroring window.
- The overlay hides on stale or invalid input by design; it may pause instead
  of showing an old recommendation.

## Screenshot review

- Automatic table, pocket, ball, cue, and power detection can fail under
  occlusion, touching balls, compression, unusual lighting, perspective, and
  game UI changes.
- The current iPhone UI allows moving table corners, pockets, and balls; adding
  and removing balls; correcting ball classification; and setting group, turn,
  and a called 8-ball pocket.
- Manual review is required before relying on a low-confidence board.
- The selected image is kept in current application memory during the active
  workflow. The app does not create its own screenshot file, but it also does
  not delete the original from the user's photo library.

## Solver

- The rules and candidate engine covers direct shots, two-ball combinations,
  and one-rail banks with center-ball guidance.
- Multi-rail routes, spin-aware guidance, caroms, cluster breakouts, dedicated
  safety play, and deep multi-shot look-ahead are not release-qualified.
- Power is a broad normalized range, not a universal exact percentage.
- Randomized synthetic checks do not prove legality or success for every
  visible board.
- A ready state is guidance, never a guarantee that the shot will succeed.

## Calibration and match state

- `CueCalibration` and `CueSession` contain versioned model/store
  implementations, but the iPhone screens are not wired to those durable
  stores.
- The iPhone calibration screen currently applies a small in-memory angular
  correction for left/right misses. Other listed outcomes do not yet adjust the
  full calibration model through the screen.
- Reset Calibration on iPhone resets current runtime correction state; it is
  not evidence that a durable profile database was deleted.
- The iPhone Match Session screen exposes manual group, turn, and called-pocket
  controls. Its prior-shot list is not populated or persisted by the current UI.
- Mac aim bias, display scale, overlay opacity, group, turn, called pocket, and
  hotkey choices are stored in local user defaults; live calibration accuracy
  remains unmeasured.

## Privacy and policy

- No private or jailbreak API is used in shipping source, and analysis does not
  require networking.
- The privacy manifest still must be checked against each final signed binary.
- The current iPhone Diagnostics export button is a placeholder and does not
  produce a file.
- Final entitlement, background-mode, Photos, App Group, logging, network, and
  linked-binary audits remain required.
- App Review approval has not been requested or predicted.
- CuePilot is not affiliated with Apple or any third-party game developer.

## Deferred tools

Clean-room companion concepts for word, darts, wind, trajectory, mini golf, and
legal Sea Battle analysis are deferred until the primary 8-ball workflow has
live evidence. Hidden-state reveal, score falsification, and automated input
are permanently outside the product.
