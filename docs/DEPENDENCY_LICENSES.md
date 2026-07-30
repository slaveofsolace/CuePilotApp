# Dependency Licenses

## Application dependencies

`Package.swift` declares no remote Swift package dependencies. CuePilot runtime
targets depend only on source in this repository and Apple platform frameworks,
including SwiftUI, Foundation, Vision, Core Image, Accelerate, ReplayKit, AVKit,
ScreenCaptureKit, and AppKit.

Apple frameworks are governed by the applicable Apple software and developer
terms; their source is not redistributed with CuePilot.

## Development and release tooling

| Tool or action | Role | Version source | Upstream license |
| --- | --- | --- | --- |
| Fastlane | Build and TestFlight automation | `Gemfile.lock` | [MIT](https://github.com/fastlane/fastlane/blob/master/LICENSE) |
| Bundler | Locked Ruby dependency environment | `Gemfile.lock` | [MIT](https://github.com/rubygems/rubygems/blob/master/LICENSE.txt) |
| XcodeGen | Generate the Xcode project | Quality workflow | [MIT](https://github.com/yonaskolb/XcodeGen/blob/master/LICENSE) |
| `actions/checkout` | Hosted checkout | Workflow declaration | [MIT](https://github.com/actions/checkout) |
| `github/codeql-action` | Hosted source analysis | Workflow declaration | [MIT](https://github.com/github/codeql-action) |

`Gemfile.lock` records the resolved Fastlane dependency graph used by the
release lanes. Hosted actions and build-tool versions are reviewed through
normal dependency updates.

## Release review

Before distribution:

1. review changes to dependency lockfiles and workflow actions;
2. enumerate direct and transitive release-tool dependencies;
3. confirm license and notice requirements;
4. run dependency and vulnerability checks;
5. include any required acknowledgments with the release.

No third-party runtime code should be added without a license, privacy,
security, size, and maintenance review.
