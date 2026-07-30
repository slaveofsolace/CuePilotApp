# Security Policy

## Supported versions

CuePilot is in pre-release development. No build is currently supported for
production use. Security fixes apply to the current `main` branch until a
versioned release policy is published.

## Reporting a vulnerability

Report a vulnerability through the private repository's security-advisory
channel once the remote repository exists. If that channel is unavailable,
contact the repository owner privately and request a secure reporting route
before sharing exploit details, captured screens, credentials, or personal
data.

Include:

- the affected target and version or commit;
- device and operating-system version, without serial numbers or UDIDs;
- reproduction steps;
- expected and observed behavior;
- impact;
- the smallest sanitized log or fixture needed to reproduce the issue.

Do not open a public issue containing secrets, personal screenshots, screen
recordings, security-sensitive logs, or a working exploit.

## Security boundaries

CuePilot must use public Apple APIs and remain inside the normal iOS and macOS
sandboxes. It must not:

- inject into or patch another process;
- read another application's private container;
- synthesize input into another application;
- use private frameworks or selectors;
- silently activate screen recording;
- upload or retain live frames by default;
- download executable code;
- store signing credentials in the repository.

The user must start capture through Apple's system interface. Capture and
analysis stop cleanly when the user ends the session. The Mac overlay must
remain click-through and must hide when the selected source is unavailable.

## Sensitive data

Screen frames, screenshots, calibration profiles, diagnostics, and match
history may contain private information. The release implementation must:

- keep analysis on-device;
- use bounded in-memory frame processing;
- avoid recording full-frame history;
- delete temporary data after analysis;
- make diagnostic export explicit;
- exclude personal fixtures from version control and release artifacts;
- protect App Group state with the narrowest required entitlement;
- avoid analytics, advertising, and network SDKs unless separately reviewed and
  approved.

## Release controls

Before distribution:

- run unit, UI, integration, and privacy tests;
- audit entitlements and background modes;
- scan for private APIs, secrets, unsafe logging, and bundled fixtures;
- review dependencies and licenses;
- validate the privacy manifest against the final binary;
- build and sign with a trusted Apple toolchain;
- verify ReplayKit and Picture in Picture on a physical iPhone;
- verify ScreenCaptureKit selection and overlay behavior on the target Mac;
- record unresolved issues in `docs/KNOWN_LIMITATIONS.md`.

No security claim should be inferred from a successful source-level build
alone.
