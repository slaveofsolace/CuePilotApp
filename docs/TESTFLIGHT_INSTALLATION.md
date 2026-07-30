# Internal TestFlight Installation

## Current status

No CuePilot build has been archived, uploaded, processed, assigned to an
internal group, or installed through TestFlight. There is no available
TestFlight version or build number.

The declared release is version `0.1.0`, build `1`, with a planned internal
group named `Personal`. Xcode 26.6 and the iOS SDK are installed. A valid
development/distribution team, signing assets, provisioning, App Store Connect
access, and an upload authentication route remain unavailable.

## Release-owner prerequisites

- active Apple Developer Program membership;
- App Store Connect access with the required role;
- registered bundle identifier and App Group;
- valid distribution signing and provisioning;
- an App Store Connect application record;
- export-compliance and privacy answers;
- a full Xcode release build and archive;
- an approved upload route through Xcode or the configured release lane;
- an internal tester assigned to the `Personal` group.

Credentials and API keys must remain outside the repository.

## Upload sequence

1. Generate and inspect the Xcode workspace.
2. Set the authorized development team on the app and extension targets.
3. Confirm bundle identifiers and App Group entitlements.
4. Run shared tests, Xcode tests, static analysis, private-API scan, secret scan,
   and dependency audit.
5. Create a clean App Store archive for version `0.1.0`, build `1`.
6. Validate the archive and privacy manifest.
7. Upload through the approved App Store Connect route.
8. Wait for processing and resolve any rejection.
9. Add the processed build to the internal `Personal` group.
10. Add test notes that explain the user-started broadcast, PiP limitations,
    manual control, local processing, and current known limitations.
11. Verify that the intended internal tester can see and install the build.
12. Record the processed build identifier, status, and installation evidence in
    the test and distribution reports.

`Gemfile.lock` resolves Fastlane 2.237.0 and Homebrew Fastlane 2.237.0 is
installed. The locked bundle requires Bundler 4.0.16, which is not installed
for the system Ruby. The presence of the lane and tools does not prove that an
archive or upload lane has run.

## Tester installation

After App Store Connect reports an available internal build:

1. Accept the internal testing invitation for the correct Apple Account.
2. Install Apple's TestFlight application if it is not already installed.
3. Open CuePilot in TestFlight and confirm the displayed version and build.
4. Read the test notes and known limitations.
5. Tap **Install**.
6. Launch CuePilot and complete the stated capture and privacy prompts.
7. Report the exact version, device/OS class, and sanitized reproduction steps
   for any problem.

Do not install an archive, IPA, profile, or certificate received through an
unverified channel.

## Expiration and renewal

TestFlight displays each build's expiration. An expired build must be replaced
with a newly uploaded and processed build. TestFlight does not grant special
overlay, capture, injection, or automation permissions.

## Required installation evidence

| Evidence | Status |
| --- | --- |
| App Store Connect app record | Not verified |
| Uploaded version/build | None |
| Processing success | Not attempted |
| `Personal` group assignment | Not attempted |
| Tester invitation | Not verified |
| Installation on physical iPhone | Not attempted |
| First launch | Not attempted |
| Broadcast extension selection | Not attempted |
| PiP workflow | Not attempted |
