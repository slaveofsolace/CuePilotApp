# Mac Installation

## Current status

The source contains a native SwiftUI/AppKit Mac application and a development
bundle script. No signed, notarized, or packaged release exists. There is no
DMG, release ZIP, Developer ID artifact, checksum, or notarization ticket.

The manual bundle produced by `script/build_and_run.sh` is for local smoke
testing only. It is not equivalent to an Xcode release build, Developer ID
signature, Hardened Runtime qualification, notarization, or clean-account
installation.

## Requirements

- macOS 15 or later;
- Xcode 26.6 or a compatible supported Xcode for development builds;
- a Mac and iPhone that satisfy Apple's iPhone Mirroring requirements;
- Apple's iPhone Mirroring application open with the intended game visible;
- macOS Screen Recording permission for CuePilot;
- an explicitly selected iPhone Mirroring window that produces nonblank
  ScreenCaptureKit frames;
- a properly signed and notarized CuePilot build for normal distribution.

Live Mirroring-window capture remains unverified.

## Development run with Xcode

1. Run `xcodegen generate` from the repository root.
2. Open `CuePilot.xcworkspace`.
3. Select the `CuePilotMac` scheme and **My Mac**.
4. Build and run the foreground application.
5. Open iPhone Mirroring and display the billiards game.
6. In CuePilot, grant Screen Recording permission if macOS requests it. Restart
   CuePilot if macOS requires a restart after permission changes.
7. Refresh the source list and confirm the intended iPhone Mirroring window.
8. Choose **Start Analysis**.
9. Verify that the preview contains the expected window before enabling or
   trusting the overlay.

CuePilot does not start capture when it merely opens or discovers a likely
window. The source selection and **Start Analysis** action are explicit.

## Development smoke script

For a quick local compilation/bundle check:

```sh
./script/build_and_run.sh --verify
```

Review the script output and generated bundle path. Treat the result only as a
development smoke artifact. Do not distribute it, bypass Gatekeeper for it, or
describe it as signed or notarized.

## Screen Recording permission

CuePilot enumerates and captures shareable windows with ScreenCaptureKit. macOS
controls Screen Recording permission under:

**System Settings → Privacy & Security → Screen & System Audio Recording**

The person may revoke access at any time. When permission is absent, the source
is unavailable, or frames become stale, CuePilot should keep the overlay hidden
and show a factual paused or permission state.

## Release installation

Only after a signed release is produced:

1. obtain it from the owner's authenticated private release;
2. verify the published SHA-256 checksum;
3. move CuePilot to `/Applications`;
4. open it normally and verify macOS reports the expected developer;
5. grant Screen Recording permission;
6. open iPhone Mirroring, select its window in CuePilot, and start analysis;
7. confirm that the overlay is aligned and click-through before controlling the
   mirrored iPhone.

Do not disable system security, remove quarantine metadata, or install an
unsigned development build presented as a release.

## Required live validation

- selected source returns nonblank frames;
- source switching never captures an unconfirmed window;
- overlay matches the captured content position and scale;
- mouse and trackpad input reaches iPhone Mirroring through the overlay;
- move, resize, minimize, restore, and orientation changes remain aligned;
- Retina and mixed-display scale factors remain aligned;
- stale, blank, or invalid frames hide old guidance;
- sleep/wake and Mirroring reconnect recover safely;
- a 15-minute session records latency, resource use, and stability.

These items have not yet been completed with a live iPhone Mirroring source.
