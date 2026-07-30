# TestFlight Installation

TestFlight is the recommended way to share signed iPhone beta builds.

## Release prerequisites

- Apple Developer Program membership
- App Store Connect access with an appropriate role
- Registered app and App Group identifiers
- Distribution signing and provisioning
- Completed privacy and export-compliance information
- An internal or external TestFlight group

Credentials and API keys must remain outside the repository.

## Upload

1. Run the repository verification gate and physical-device checks.
2. Confirm version, build number, bundle identifiers, entitlements, and signing.
3. Create and validate an App Store archive.
4. Upload through Xcode or the configured Fastlane lane.
5. Wait for App Store Connect processing.
6. Add clear beta notes covering screenshot analysis, user-started broadcasting,
   Picture in Picture behavior, and known limitations.
7. Assign the build to the intended testing group.

## Tester installation

1. Accept the TestFlight invitation with the intended Apple Account.
2. Install Apple's TestFlight app.
3. Open the CuePilot invitation and review the beta notes.
4. Tap **Install**.
5. Launch CuePilot and respond to the Photos, broadcast, Picture in Picture, and
   capture prompts as each workflow requires.

When reporting a problem, include the CuePilot version and build, the general
device and OS model, the workflow being tested, and sanitized reproduction
steps. Never send personal screenshots, account credentials, certificates, or
provisioning profiles through an issue report.

TestFlight builds expire on the date shown in the TestFlight app. TestFlight
does not grant additional capture, overlay, injection, or automation
permissions.
