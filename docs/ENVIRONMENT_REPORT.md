# Environment Report

Snapshot date: 2026-07-30
Scope: local build and release readiness

## Readiness

The Mac is ready for Xcode project generation and SDK-based iOS and macOS
compilation. Xcode 26.6 is installed, licensed, selected, and has completed its
first-launch checks. The installed Xcode includes iOS and macOS SDKs.

The machine is not ready for simulator UI testing, physical-device signing,
TestFlight, or notarized Mac distribution. No iOS Simulator runtime is
installed, no valid signing identity or provisioning profile was found, and
the GitHub command-line client was not authenticated at this snapshot.

## Host and toolchain

| Check | Finding |
| --- | --- |
| Host | Apple silicon Mac (`arm64`) |
| Active developer directory | `/Applications/Xcode.app/Contents/Developer` |
| Xcode | 26.6, build `17F113` |
| First-launch status | Complete |
| Swift | Apple Swift 6.3.3 |
| Swift target | `arm64-apple-macosx28.0` |
| XcodeGen | 2.46.0 |
| Fastlane | Homebrew Fastlane 2.237.0 |
| SwiftLint | 0.65.0 |
| xcbeautify | 3.2.1 |
| Developer Mode | Disabled |

Sanitized evidence:

```text
$ xcode-select -p
/Applications/Xcode.app/Contents/Developer

$ xcodebuild -version
Xcode 26.6
Build version 17F113

$ swift --version
swift-driver version: 1.148.6 Apple Swift version 6.3.3
Target: arm64-apple-macosx28.0

$ xcodegen --version
Version: 2.46.0
```

## SDK and simulator inventory

Xcode reports these relevant SDKs:

| Platform | SDK |
| --- | --- |
| iPhone device | iOS 26.5 |
| iPhone simulator SDK | iOS 26.5 |
| Mac | macOS 26.5 |

`xcrun simctl list runtimes` returns no installed runtimes. An iOS runtime
download was canceled near completion to avoid exhausting the startup disk.
Additional free space is required before restarting so the installer has room
for both the download and expansion.

Consequences:

- generic device and simulator-SDK compilation can use the installed SDKs;
- no simulator can boot;
- simulator unit tests and UI tests cannot run;
- no simulator screenshots can be used as runtime evidence.

## Device status

No physical iPhone test has been recorded. Developer Mode is currently disabled
on the Mac, and no trusted-device, pairing, installation, or launch result is
claimed.

| Device check | Result |
| --- | --- |
| Physical iPhone build/install | Not run |
| ReplayKit/Picture in Picture | Not run on a device |
| iPhone Mirroring capture | Not run with a live source |

## Signing and Apple accounts

```text
$ security find-identity -v -p codesigning
0 valid identities found
```

No provisioning profiles were found in the standard Xcode user location. No
Apple Development, Apple Distribution, or Developer ID Application identity is
available to the current command-line session.

This blocks:

- physical-device installation;
- signed App Store archive and TestFlight upload;
- Developer ID signing and notarization for Mac.

No credential files or account secrets were inspected or added to the
repository.

## Git and GitHub

| Check | Finding |
| --- | --- |
| Git | Apple Git 2.50.1 |
| Local CuePilot repository | Initialized on `main` |
| Local commits/tags | First source commit pending |
| Git author identity | Repository-local public handle and GitHub no-reply address planned |
| GitHub CLI | 2.96.0 |
| GitHub CLI authentication | Not logged in at this snapshot |
| Remote repository | Public `slaveofsolace/CuePilotApp`, verified through GitHub's API |

Browser sign-in and command-line authentication are separate states. A signed-in
browser profile does not by itself authenticate `gh`; the device authorization
flow must finish and `gh auth status` must pass before repository creation.

## Release tooling

`Gemfile.lock` resolves Fastlane 2.237.0 and records Bundler 4.0.16. Homebrew
Fastlane 2.237.0 is available directly. `bundle exec fastlane` is currently
blocked because Bundler 4.0.16 is not installed for the system Ruby. Either
install the locked Bundler version in an approved Ruby environment or run the
matching Homebrew Fastlane binary after reviewing the lane.

No App Store Connect API credential is configured in source control, as
required.

## Remaining environment work

1. Free sufficient disk space and install one supported iOS Simulator runtime.
2. Run simulator unit and UI tests on a named device.
3. Configure an authorized Apple Developer team and matching App Group.
4. Connect and trust a supported iPhone for ReplayKit/Picture in Picture tests.
5. Complete GitHub command-line authentication and push with the repository-local
   public handle and GitHub no-reply address.
6. Configure App Store Connect and Developer ID credentials only through an
   approved secret route.
7. Rerun builds, analysis, privacy checks, and release gates from the final
   committed source.

Xcode installation is complete. Signing, live-device behavior, GitHub push,
TestFlight, and notarization remain separate uncompleted gates.
