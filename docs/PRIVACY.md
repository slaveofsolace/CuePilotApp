# Privacy

This document describes the data handling implemented by CuePilot's iPhone,
Broadcast Upload Extension, and Mac targets.

## Summary

CuePilot is designed to analyze screen frames and a user-selected screenshot
on the device. The application does not require an account, cloud analysis,
advertising, or behavioral analytics. It does not create or retain a continuous
screen recording.

The privacy manifests declare:

- no tracking;
- no tracking domains;
- no collected data types;
- UserDefaults as the only required-reason API category;
- reason `1C8F.1` for the iPhone app and Broadcast Upload Extension's
  App Group defaults;
- reason `CA92.1` for the Mac application's standard local preferences.

Release review compares these declarations with the linked application
binaries.

## Live screen capture

On iPhone, capture requires the person to use Apple's ReplayKit broadcast
picker. On Mac, the person must grant Screen Recording permission, choose the
iPhone Mirroring source in CuePilot, and choose **Start Analysis**.

The implementation uses bounded frame processing and discards transient pixel
buffers after analysis. It does not:

- silently start capture;
- capture before an approved analysis session starts;
- upload frames;
- save a continuous recording;
- use screen content for advertising, profiling, or model training;
- expose frames to an analytics SDK;
- automate input in the observed application.

The Mac overlay hides when capture is stopped, stale, invalid, or unavailable.

## Screenshots and Photos

Screenshot analysis uses Apple's photo picker and receives only the selected
image data. CuePilot does not enumerate the photo library or delete the user's
original image.

The app decodes the selected image into the active application state
and does not create an application-managed screenshot file. That in-memory
working image can remain until it is replaced, the state is discarded, or the
process ends.

Personal screenshots:

- are excluded from version control;
- are not bundled as test fixtures;
- are not included in a release;
- must not be added to a dataset without explicit authorization.

## Local settings and state

iPhone runtime state includes:

- selected screenshot analysis and manual corrections;
- group, turn, and called-pocket choices;
- current calibration flag and angular correction;
- presentation preferences.

The iPhone screens do not persist a match history or durable calibration
profile. Shared `CueCalibration` and `CueSession` store types are separate from
the screen's session-local state.

The Mac application stores local preferences in user defaults, including
overlay presentation, hotkey choice, manual game state, aim bias, and display
scale. It does not store captured frames as a recording.

## App Group transport

The iPhone application and Broadcast Upload Extension use a private App Group.
The file transport publishes a compact, versioned analytical state with
sequence and integrity checks. It does not publish screenshots or a frame
archive. Corrupt or stale state is rejected.

## Diagnostics

The shared diagnostics model accepts bounded numeric timing summaries and
event counters. It excludes frames, screenshots, captured text, file paths,
third-party bundle identifiers, accounts, contacts, and precise device
identifiers.

The iPhone Settings screen does not create a diagnostics export file.

## Networking

Analysis requires no network connection. No analytics, advertising, upload, or
runtime network client is implemented. The declared Mac sandbox disables
outbound client networking.

Build and distribution tools can contact package, source-hosting, and Apple
services outside the application runtime. Their credentials must remain
outside source control.

Adding a runtime network dependency requires a privacy review, manifest update,
user disclosure, and security review.

## Retention and deletion

| Data | Behavior |
| --- | --- |
| Live frame pixels | Bounded transient processing; no recording file |
| Selected screenshot | Working image held in memory; original remains in the user's library |
| iPhone match state/history | Current runtime controls only; no durable history wired |
| iPhone calibration | Current runtime correction only |
| Mac preferences/calibration controls | Local user defaults until reset or app data removal |
| Diagnostics file | No UI export is currently produced |

On iPhone, **Reset Calibration** clears the current in-memory calibration flag
and angular correction. It is not a general local-data deletion control. On
Mac, **Reset Calibration** resets the local aim-bias and display-scale
preferences.

## Third-party identity

CuePilot is not affiliated with Apple or any third-party game developer. Its
name, icon, and product artwork use original generic billiards branding.
Unlicensed third-party screenshots or artwork must not be bundled.

## Release privacy checklist

- compare privacy manifests with every linked binary and SDK;
- inspect final source and binary network behavior;
- review Photos, App Group, audio, screen-capture, and background-mode use;
- confirm that no frames or personal fixtures appear in archives;
- inspect logs for captured text, paths, and unnecessary coordinates;
- test capture start, stop, stale-state clearing, and permission revocation;
- test every visible reset or export control against its actual behavior;
- update store privacy answers from observed behavior;
- record the release audit with the signed artifacts.
