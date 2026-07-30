# Distribution

## Current status

| Item | Status |
| --- | --- |
| Version | Declared as `0.1.0` |
| Build number | Declared as `1` |
| Xcode | 26.6 build `17F113`, installed and selected |
| Local Git repository | Initialized |
| Public-safe source commit | Pending |
| Public GitHub repository | Configured and owner-approved |
| Main push and release tag | Not performed |
| iOS Simulator validation | Blocked by missing runtime |
| Signed iOS archive | Not built |
| TestFlight upload/install | Not attempted |
| Mac development bundle | Manual smoke route available; not a release artifact |
| Developer ID signing | Not performed |
| Hardened Runtime audit | Pending |
| Notarization | Not attempted |
| DMG or release ZIP | Not produced |
| Checksums | Not produced |

No installable release artifact is available.

## Release tooling

The repository includes:

- `Gemfile.lock`, resolving Fastlane 2.237.0 with Bundler 4.0.16;
- iOS lanes for tests, unsigned build, signed archive, and internal TestFlight
  upload;
- a Mac Swift Package release-build lane;
- metadata for version `0.1.0`, build `1`, and the `Personal` internal group;
- XcodeGen project generation;
- verification, private-API, secret, and dependency scripts;
- hosted workflow declarations for shared checks and source analysis;
- dependency update declarations for Bundler and hosted actions.

Homebrew Fastlane 2.237.0 is installed. `bundle exec fastlane` requires the
locked Bundler 4.0.16, which is not installed for the system Ruby. No signed
lane or hosted workflow has been qualified.

## iPhone release gate

1. Freeze the intended source and regenerate the Xcode project.
2. Pass the shared Swift package tests and generic Xcode iOS/extension builds.
3. Free sufficient disk space, install a simulator runtime, and run the iOS
   unit and UI suites.
4. Configure an authorized team, bundle identifiers, App Group, and signing.
5. Pass static analysis, private-API, secret, dependency, and privacy checks.
6. Install on a supported iPhone and complete ReplayKit/Picture in Picture
   feasibility, interruption, memory, thermal, and 15-minute stability tests.
7. Archive version `0.1.0`, build `1`, with the intended distribution identity.
8. Validate and upload to App Store Connect.
9. Record processing status and assign the `Personal` internal testing group.
10. Verify installation and first launch on the intended iPhone.

A successful generic SDK build or archive does not establish TestFlight
availability.

## Mac release gate

1. Pass the Xcode `CuePilotMac` build from the frozen source.
2. Run the foreground `.app` bundle and grant Screen Recording permission.
3. Explicitly select a live iPhone Mirroring window and verify nonblank capture,
   alignment, click-through input, stale-frame shutdown, move/resize behavior,
   and 15-minute stability.
4. Audit sandbox entitlements, Hardened Runtime, linked frameworks, and network
   behavior.
5. Sign with a valid Developer ID Application identity.
6. Notarize and staple the artifact.
7. Package a signed ZIP or DMG and publish SHA-256 checksums.
8. Test installation and first launch on a clean supported Mac account.

`script/build_and_run.sh` creates a convenient development smoke bundle. It is
not signing-equivalent and must never be presented as a normal release.

## GitHub release gate

Only after the frozen builds and checks pass:

1. complete GitHub command-line authentication in the intended account;
2. configure the owner-approved Git author name and email;
3. inspect staged files for secrets, personal fixtures, legacy files, build
   products, and signing material;
4. confirm the owner-approved public repository destination;
5. push the reviewed history to `main`;
6. tag `v0.1.0`;
7. attach factual release notes, test and performance reports, checksums, and
   only properly signed distributable artifacts.

The supplied legacy archive and extracted reference source must not be pushed.

## Credentials

Use Xcode-managed credentials or App Store Connect API credentials supplied
outside source control. Do not commit:

- `.p8`, `.p12`, `.cer`, `.pem`, `.key`, or provisioning files;
- Fastlane sessions, account passwords, or tokens;
- `.env` files;
- account addresses, device identifiers, or personal screenshots.

## Release record

For each release, record:

- repository visibility, branch, commit, and tag;
- Xcode, Swift, XcodeGen, Fastlane, and Bundler versions;
- supported platform versions;
- exact build, test, analysis, and scan results;
- device and OS classes without serial identifiers;
- capture, Picture in Picture, overlay, latency, accuracy, and stability results;
- TestFlight version/build, processing, group, and installation status;
- Mac signing, notarization, packaging, and checksum status;
- all known limitations and any remaining blocker.
