# Mac Overlay

CuePilot for Mac analyzes a user-selected iPhone Mirroring window and displays
guidance in a separate click-through panel.

## User flow

1. Open Apple's iPhone Mirroring app and display the billiards game.
2. Open CuePilot for Mac.
3. Grant Screen Recording permission when macOS requests it.
4. Refresh the source list and select the intended iPhone Mirroring window.
5. Confirm the selection and choose **Start Analysis**.
6. Choose **Stop Analysis** before switching to unrelated content.

Capture never starts simply because CuePilot discovers a likely window.

## Window selection

CuePilot limits its source list to likely iPhone Mirroring windows and requires
explicit confirmation. ScreenCaptureKit supplies window frames and registration
metadata; CuePilot uses that metadata to map canonical table coordinates into
screen coordinates.

The overlay:

- covers only the selected content region;
- ignores mouse and trackpad input;
- follows window movement and resizing;
- updates for display-scale and registration changes;
- hides when capture stops or frames become stale;
- never becomes the key or main application window.

## Platform behavior

Apple does not provide a public guarantee that every iPhone Mirroring window is
capturable or that protected content produces nonblank pixels. CuePilot does not
attempt to bypass system redaction or capture restrictions.

If the selected source disappears, changes identity, or stops producing valid
frames, CuePilot clears guidance and returns to source selection. Screenshot
analysis remains available as a fallback.

See [Mac installation](MAC_INSTALLATION.md) for setup and
[Validation](VALIDATION.md) for the live test matrix.
