# Security Policy

## Supported versions

Security fixes are applied to the latest release and the default branch.
Older versions may be asked to update before a fix is provided.

## Reporting a vulnerability

Use the repository's **Security → Report a vulnerability** form. If private
reporting is unavailable, open a public issue containing only a request for a
secure contact route. Do not include exploit details or sensitive data in that
issue.

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

Source checks complement, but do not replace, signed-binary and live-platform
security review.
