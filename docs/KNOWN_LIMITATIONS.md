# Known Limitations

## iPhone Live Assist

- The player must start capture through Apple's system broadcast picker.
- Picture in Picture is a system-managed video window, not a transparent overlay
  anchored to another app.
- iOS controls Picture in Picture placement, size, controls, and lifecycle.
- Live guidance clears when capture stops or shared state becomes stale.

## Mac overlay

- The Mac app depends on Apple's separate iPhone Mirroring app.
- Screen Recording permission and explicit source confirmation are required.
- Apple does not guarantee that every iPhone Mirroring window will return
  nonblank ScreenCaptureKit frames.
- The guidance panel is a separate click-through window and cannot bypass
  system capture restrictions.

## Detection

- Occlusion, touching balls, compression, unusual lighting, perspective, and
  game-interface changes can reduce detection confidence.
- Manual review is recommended whenever table geometry, ball classification, or
  called-pocket state is uncertain.
- The original screenshot remains in the user's photo library; CuePilot does not
  delete it.

## Shot planning

- The solver covers direct shots, two-ball combinations, and one-rail banks with
  center-ball guidance.
- Multi-rail routes, spin-aware trajectories, caroms, cluster breakouts,
  dedicated safety play, and deep multi-shot search are outside the current
  solver.
- Power is expressed as a range, not a universal exact percentage.
- A ready state is guidance, not a guarantee that a shot will succeed.

## Calibration and match state

- The iPhone calibration screen applies session-local aim correction; the shared
  durable calibration store is not connected to that screen.
- The iPhone match screen exposes manual state controls but does not persist a
  shot history.
- Mac presentation and calibration preferences are stored locally in user
  defaults.

## Platform policy

CuePilot does not use private APIs, jailbreak frameworks, hidden game state, or
input automation. It cannot reveal information that is not visible to the user
or override restrictions imposed by iOS, macOS, ReplayKit, Picture in Picture,
or ScreenCaptureKit.
