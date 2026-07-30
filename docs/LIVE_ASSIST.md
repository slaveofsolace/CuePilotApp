# Live Assist

Live Assist uses Apple system capture and presentation APIs to show shot
guidance while the billiards game remains under the player's control.

## User flow

1. Open CuePilot and choose **Start Live Assist**.
2. Start the CuePilot broadcast from Apple's system broadcast picker.
3. Start Picture in Picture from CuePilot.
4. Return to the billiards game and take each shot manually.
5. Stop the broadcast or Picture in Picture when guidance is no longer needed.

CuePilot cannot start capture silently, inject controls into another app, or
perform a shot.

## Data flow

The Broadcast Upload Extension accepts complete ReplayKit video frames,
downsamples them to a bounded working size, and analyzes them on the device. It
publishes compact guidance state through an App Group. The host app validates
sequence numbers, checksums, and freshness before presenting that state in
Picture in Picture.

Raw frames are not written to the shared container. When analysis falls behind,
newer frames replace stale work instead of creating a frame queue.

## Picture in Picture

Picture in Picture is a system-managed video window. Its position, size,
controls, and lifetime are controlled by iOS. It is not a transparent overlay
attached to another application.

Guidance is cleared when:

- the broadcast stops;
- state becomes stale or invalid;
- table or shot confidence falls below the presentation threshold;
- the app can no longer provide current guidance safely.

Screenshot analysis remains available when live capture or Picture in Picture
is unavailable.

## Release checks

Live Assist should be exercised on a signed physical iPhone because the
simulator does not reproduce ReplayKit broadcast extensions, App Group signing,
or Picture in Picture background behavior. See [Validation](VALIDATION.md) for
the live test matrix.
