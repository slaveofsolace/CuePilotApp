# Dependency Licenses

Snapshot date: 2026-07-30

## Application dependencies

`Package.swift` declares no remote Swift package dependency. CuePilot products
depend only on targets in this repository and Apple SDK frameworks.

The application uses Apple frameworks including SwiftUI, Foundation, Vision,
Core Image, Accelerate, ReplayKit, AVKit, ScreenCaptureKit, and AppKit. They are
provided by the platform SDKs and governed by the applicable Apple software and
developer terms; their source is not redistributed here.

No `Package.resolved` is expected while the package has no remote dependency.

## Development and release tooling

| Tool or action | Role | Resolved or installed version | Upstream license |
| --- | --- | --- | --- |
| Fastlane | Build and TestFlight automation | 2.237.0 in `Gemfile.lock` and Homebrew | [MIT](https://github.com/fastlane/fastlane/blob/master/LICENSE) |
| Bundler | Locked Ruby dependency environment | 4.0.16 in `Gemfile.lock`; not installed for system Ruby | [MIT](https://github.com/rubygems/rubygems/blob/master/LICENSE.txt) |
| XcodeGen | Generate the Xcode project | 2.46.0 installed | [MIT](https://github.com/yonaskolb/XcodeGen/blob/master/LICENSE) |
| SwiftLint | Source linting | 0.65.0 installed | [MIT](https://github.com/realm/SwiftLint/blob/main/LICENSE) |
| xcbeautify | Xcode log formatting | 3.2.1 installed | [MIT](https://github.com/cpisciotta/xcbeautify/blob/main/LICENSE) |
| `actions/checkout` | Hosted checkout | `v4` declaration | [MIT](https://github.com/actions/checkout/blob/main/LICENSE) |
| `github/codeql-action` | Hosted source analysis | `v3` declaration | [MIT](https://github.com/github/codeql-action/blob/main/LICENSE) and applicable service terms |

`Gemfile.lock` freezes the Fastlane transitive versions used by the declared
Ruby bundle. It does not by itself complete the license, vulnerability, or
notice audit. The locked bundle currently cannot run through the system
`bundle` command until Bundler 4.0.16 is installed in an approved Ruby
environment.

## Project and reference-source licenses

CuePilot source and original assets are released under the MIT License. See
`LICENSE`.

The legacy GameSeagull archive has no license and is not a dependency. Its code,
icons, formulas, declarations, and assets are excluded from CuePilot.

## Release procedure

Before distribution:

1. verify `Gemfile.lock` is unchanged from the reviewed release candidate;
2. enumerate resolved direct and transitive Ruby dependencies;
3. confirm each license and required notice from the dependency's tagged
   release;
4. review hosted workflow actions at immutable commit identifiers where
   practical;
5. run dependency and vulnerability checks;
6. add every required acknowledgment to the release package;
7. update this report with the audit date and any notice paths.

No third-party runtime code should be added without a license, privacy,
security, size, and maintenance review.
