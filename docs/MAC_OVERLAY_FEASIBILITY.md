# Mac Precision Overlay Feasibility

Status: candidate public-API workflow; live iPhone Mirroring proof not completed

## Verdict

ScreenCaptureKit can capture a person-selected window and supplies metadata for
screen position, content crop, and point-to-pixel scale. AppKit can create a
transparent, borderless, nonactivating panel whose mouse events pass through.

Apple does not document a guarantee that iPhone Mirroring:

- appears in ScreenCaptureKit's shareable-window inventory;
- returns nonblank game pixels;
- exposes stable window identity;
- supports the required cross-process z-order behavior.

Xcode 26.6 and the macOS 26.5 SDK are installed.
`swift build --target CuePilotMac` passed after the Mac release fixes. No
signed Mac application, live iPhone Mirroring test, or signing identity is
available, so the overlay has not been verified live.

## Selection and capture

The current implementation asks `SCShareableContent` for visible windows and
presents the resulting choices in CuePilot. Metadata can rank a likely iPhone
Mirroring candidate, but the person confirms the intended window and chooses
**Start Analysis** before capture begins. CuePilot does not depend on a private
or undocumented Mirroring bundle identifier.

The selected window is captured with a desktop-independent `SCContentFilter`
and `SCStream`. The stream must be treated as valid only when complete frames
contain nonblank source pixels. A changed or missing window ID requires
selection again.

## Registration model

Per-frame ScreenCaptureKit metadata is the primary registration source:

- `screenRect` locates captured content in screen coordinates;
- `contentRect` identifies the useful pixel crop;
- `contentScale` and `scaleFactor` map content pixels to display points;
- `status` distinguishes complete, idle, blank, suspended, and stopped frames.

The overlay transform must be recalculated from each accepted metadata change.
It must not assume a toolbar inset, orientation size, fixed scale, or
bottom-left/top-left conversion without explicit normalization.

## Overlay window

The intended overlay is a borderless, transparent, nonactivating `NSPanel`:

- clear background;
- `isOpaque = false`;
- no shadow;
- `ignoresMouseEvents = true`;
- no key or main-window behavior;
- frame derived from current ScreenCaptureKit metadata;
- ordered immediately above the selected source window where public ordering
  behavior permits;
- hidden whenever the source is absent, minimized, invalid, on another Space,
  or no longer the intended context.

Calibration and diagnostics belong in a separate ordinary window. The assist
overlay must never temporarily capture clicks over iPhone Mirroring.

## Intended data flow

```text
SCShareableContent window list
        |
        +-- person confirms source and starts analysis
        |
        v
SCStream for selected window
        |
        +-- frame status and coordinate metadata
        +-- canonical table normalization
        +-- vision, geometry, physics, and strategy
        |
        v
Transparent click-through assist panel
```

Filtering only the selected source window should keep CuePilot's overlay out of
the captured image and prevent recursion.

## Lifecycle checks

| Scenario | Expected behavior | Result |
| --- | --- | --- |
| Application opens | No capture until Start Analysis | Implemented; runtime check pending |
| Screen Recording denied | Permission guidance; overlay hidden | Implemented; runtime check pending |
| Mirroring window moves | Overlay follows without visible drift | Not run |
| Mirroring window resizes | Transform and overlay update | Not run |
| Portrait/landscape changes | Table registration is recalculated | Not run |
| Window minimizes | Capture pauses and overlay hides | Not run |
| Window restores | Capture and registration recover | Not run |
| Mirroring reconnects | Stale window ID is rejected; selection resumes | Not run |
| Different scale-factor display | Point/pixel mapping remains aligned | Not run |
| Space or Stage Manager change | Overlay never covers unrelated content | Not run |
| Mission Control/full screen | Z-order and hiding remain safe | Not run |
| Mouse/trackpad input | Input reaches Mirroring through the overlay | Not run |
| Fifteen-minute session | Stable capture and registration | Not run |

## Measurements required

- nonblank-frame success rate;
- capture-to-overlay median and P95 latency;
- dropped and incomplete frame rate;
- registration error in points and source pixels;
- move/resize recovery time;
- CPU, GPU, memory, and energy impact;
- thermal behavior;
- 15-minute stability;
- behavior after sleep/wake and display hot-plug.

No values have been measured.

## Platform requirements

The practical floor is macOS 15 with an iOS 18-compatible iPhone because
iPhone Mirroring is the binding feature. Apple's published Mirroring
requirements include a supported Mac, the same Apple Account with two-factor
authentication, Wi-Fi and Bluetooth, proximity, and a locked iPhone. Regional
availability also applies.

If the Mirroring window is excluded or redacted, there is no public bypass.
CuePilot must explain the limitation and offer screenshot analysis.

## Official references

- [Capturing screen content in macOS](https://developer.apple.com/documentation/screencapturekit/capturing-screen-content-in-macos)
- [SCShareableContent](https://developer.apple.com/documentation/screencapturekit/scshareablecontent)
- [SCContentFilter](https://developer.apple.com/documentation/screencapturekit/sccontentfilter)
- [SCStreamFrameInfo](https://developer.apple.com/documentation/screencapturekit/scstreamframeinfo)
- [SCFrameStatus](https://developer.apple.com/documentation/screencapturekit/scframestatus)
- [SCWindow](https://developer.apple.com/documentation/screencapturekit/scwindow)
- [NSWindow](https://developer.apple.com/documentation/appkit/nswindow)
- [NSWindow.ignoresMouseEvents](https://developer.apple.com/documentation/appkit/nswindow/ignoresmouseevents)
- [Ordering a window relative to another](https://developer.apple.com/documentation/appkit/nswindow/order(_:relativeto:))
- [iPhone Mirroring requirements](https://support.apple.com/120421)
