# Contributing

CuePilot is a clean-room, MIT-licensed project. Contributions require
the repository owner's authorization. Submission does not grant permission to
redistribute the project or its assets.

## Clean-room requirements

Contributions must be original and based on public documentation, observable
behavior, or independently developed algorithms. Do not submit:

- code or assets from the legacy GameSeagull archive;
- third-party game artwork, screenshots, branding, or private declarations;
- jailbreak hooks, memory patches, input automation, or private APIs;
- hard-coded values or formulas copied from a proprietary implementation;
- credentials, provisioning profiles, certificates, device identifiers,
  personal fixtures, or account information.

Document the public source for platform-specific behavior. Apple API references
should link to official Apple documentation.

## Development expectations

- Use Swift 6 language rules and strict concurrency.
- Keep platform capture behind a replaceable frame-provider boundary.
- Keep shared geometry, physics, strategy, calibration, session, presentation,
  diagnostics, vision, and test support in focused modules.
- Favor deterministic geometry and bounded work over unbounded queues or large
  general-purpose models.
- Keep frame analysis on-device and avoid networking in the analysis path.
- Preserve manual correction and explicit user control.
- Never report a shot as ready from one noisy frame.
- Keep iPhone controls native and use standard macOS structure and materials
  before custom chrome.

## Tests

Every behavioral change should add or update the smallest relevant test:

- geometry and coordinate transforms;
- 8-ball legality and match state;
- randomized solver invariants;
- vision fixtures and confidence behavior;
- calibration persistence;
- UI and accessibility;
- latency, memory, thermal, and stability measurements for live paths.

Use synthetic fixtures where possible. Personal screenshots must remain outside
the repository.

Full iOS, extension, and signed-device validation requires Xcode and the
appropriate Apple SDKs. If those are unavailable, state exactly which checks
were not run.

## Change preparation

Before requesting review:

1. Keep the change narrowly scoped.
2. Update documentation and `CHANGELOG.md` for user-visible behavior.
3. Run available tests and record the exact command and result.
4. Check staged files for secrets and personal data.
5. Confirm no legacy source or proprietary asset entered the repository.
6. Describe limitations and unverified runtime behavior plainly.

Use direct commit subjects such as `feat: add table normalization` or
`test: cover illegal early 8-ball`.
