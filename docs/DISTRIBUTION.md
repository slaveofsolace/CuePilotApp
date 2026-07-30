# Distribution

CuePilot ships as two Apple-platform applications:

- an iPhone app with a Broadcast Upload Extension and App Intents framework;
- a native Mac app that uses ScreenCaptureKit.

## iPhone release

Prerequisites:

- Apple Developer Program membership;
- registered bundle identifiers and App Group;
- App Store Connect access;
- distribution signing managed by Xcode or an approved CI secret store.

Release sequence:

1. Update the marketing version and build number.
2. Regenerate the Xcode project.
3. Run `./script/verify.sh`.
4. Run the iPhone UI suite and the physical-device matrix in
   [Validation](VALIDATION.md).
5. Confirm privacy manifests, entitlements, App Group identifiers, and linked
   binaries.
6. Create and validate an App Store archive.
7. Upload the archive to App Store Connect.
8. Complete export-compliance, privacy, and testing-group details.
9. Install the processed build through TestFlight and verify first launch,
   broadcast selection, Picture in Picture, and screenshot analysis.

See [TestFlight installation](TESTFLIGHT_INSTALLATION.md) for tester steps.

## Mac release

1. Run the verification gate and the live iPhone Mirroring matrix.
2. Audit sandbox entitlements, capture permissions, linked frameworks, and
   network behavior.
3. Archive with Hardened Runtime enabled.
4. Sign with a Developer ID Application certificate.
5. Submit for notarization and staple the ticket.
6. Package the app as a signed ZIP or DMG.
7. Publish a SHA-256 checksum and verify installation from a clean user account.

The development runner in `script/build_and_run.sh` is intended for local source
builds. Public packages should be signed and notarized.

## GitHub release

1. Require pull requests and passing quality checks on the default branch.
2. Confirm that source, assets, history, and generated files contain no
   credentials, personal data, signing material, or build products.
3. Tag the reviewed commit with the release version.
4. Publish concise product release notes.
5. Attach only signed distributable artifacts and their checksums.

## Credentials

Keep certificates, provisioning profiles, API keys, account sessions, and
environment files outside source control. Use Xcode-managed credentials or a
protected CI secret store.
