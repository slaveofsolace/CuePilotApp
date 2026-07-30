# Mac Installation

CuePilot for Mac is a native SwiftUI and AppKit application that analyzes an
explicitly selected iPhone Mirroring window.

## Build from source

Requirements:

- a Mac that supports Apple's iPhone Mirroring app;
- an Xcode release that supports the macOS 15 deployment target;
- XcodeGen;
- Screen Recording permission for live window capture.

```sh
brew install xcodegen
./script/generate_project.sh
open CuePilot.xcworkspace
```

Select the `CuePilotMac` scheme and run the app.

For a local development build from the command line:

```sh
./script/build_and_run.sh
```

## First run

1. Open Apple's iPhone Mirroring app and display the billiards game.
2. Launch CuePilot for Mac.
3. Grant Screen Recording permission when macOS requests it.
4. If permission was changed in System Settings, quit and reopen CuePilot.
5. Refresh the source list.
6. Select and confirm the intended iPhone Mirroring window.
7. Choose **Start Analysis**.

The preview should match the selected window before guidance is enabled.

## Permissions

Screen Recording permission is managed in:

**System Settings → Privacy & Security → Screen & System Audio Recording**

CuePilot does not attempt to bypass macOS capture restrictions. If the selected
window disappears or returns invalid frames, guidance is hidden and source
selection is shown again.

## Published packages

Install public packages only from the repository's Releases page. A published
Mac build should be Developer ID signed, notarized by Apple, and accompanied by
a SHA-256 checksum.
