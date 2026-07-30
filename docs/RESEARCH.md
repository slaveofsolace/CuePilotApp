# Platform Research

Research snapshot: 2026-07-29
Source policy: Apple Developer and Apple Support documentation only

## Stable baseline and migration path

Apple's system-requirements page listed Xcode 26.6 with the iOS 26.5 and macOS
26.5 SDKs, while Xcode 27 beta 4 was listed separately. The initial release
must not depend on beta-only APIs.

ReplayKit remains the public stable iPhone broadcast path for the iOS 26 SDK,
although its broadcast picker and sample handler are deprecated beginning with
iOS 27. Apple's iPhone ScreenCaptureKit sample requires iOS 27 or later and was
beta in this research snapshot. Capture should therefore sit behind a
replaceable frame-provider protocol.

The complete suite uses iOS 18.0 and macOS 15.0 as practical floors because
iPhone Mirroring is the binding feature. ReplayKit and sample-buffer Picture in
Picture have lower API floors, but those lower floors do not provide the whole
product workflow.

## Findings

| Topic | Research conclusion | Proof still required |
| --- | --- | --- |
| User-started iPhone capture | `RPSystemBroadcastPickerView` and `RPBroadcastSampleHandler` are the stable public path | Signed iPhone must produce usable game pixels |
| iPhone ScreenCaptureKit | Future migration path on iOS 27 beta at the snapshot date | Re-evaluate with a stable SDK |
| App Group state | Shared containers support compact app-extension IPC | Signed entitlements and high-frequency transport test |
| Picture in Picture | Sample-buffer PiP can display live video from iOS 15 | Background continuity, recursion, latency, and App Review fit |
| True iPhone overlay | No public transparent, coordinate-anchored overlay exists | No spike can change this API boundary |
| Mac window capture | `SCShareableContent`, `SCContentFilter`, and `SCStream` can capture a confirmed window | Mirroring window must appear and return nonblank pixels |
| Mac coordinates | Frame metadata provides screen, content, and scale registration data | Multi-display and lifecycle alignment measurements |
| Mac overlay | A transparent click-through AppKit panel is public | Cross-process z-order and Space/full-screen behavior |

## Official Apple references

### Toolchain and capture

- [SDKs and system requirements](https://developer.apple.com/xcode/system-requirements)
- [ScreenCaptureKit](https://developer.apple.com/documentation/screencapturekit)
- [Capturing screen content on iOS](https://developer.apple.com/documentation/screencapturekit/capturing-screen-content-on-ios)
- [RPSystemBroadcastPickerView](https://developer.apple.com/documentation/replaykit/rpsystembroadcastpickerview)
- [RPBroadcastSampleHandler](https://developer.apple.com/documentation/replaykit/rpbroadcastsamplehandler)
- [Processing broadcast sample buffers](https://developer.apple.com/documentation/replaykit/rpbroadcastsamplehandler/processsamplebuffer(_:with:))
- [Creating an App Extension — Optimize Efficiency and Performance](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/ExtensionCreation.html)
- [Detecting captured content](https://developer.apple.com/documentation/uikit/uiscreen/iscaptured)
- [Protecting sensitive content during screen sharing](https://developer.apple.com/documentation/swiftui/protecting-sensitive-content-when-screen-sharing)

### App Groups and Picture in Picture

- [Configuring app groups](https://developer.apple.com/documentation/xcode/configuring-app-groups)
- [App Groups entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.application-groups)
- [AVPictureInPictureController.ContentSource](https://developer.apple.com/documentation/avkit/avpictureinpicturecontroller/contentsource-swift.class)
- [Sample-buffer content source initializer](https://developer.apple.com/documentation/avkit/avpictureinpicturecontroller/contentsource-swift.class/init(samplebufferdisplaylayer:playbackdelegate:))
- [AVPictureInPictureController](https://developer.apple.com/documentation/avkit/avpictureinpicturecontroller)
- [Adopting Picture in Picture in a Custom Player](https://developer.apple.com/documentation/avkit/adopting-picture-in-picture-in-a-custom-player)
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)

### macOS capture and overlay

- [Capturing screen content in macOS](https://developer.apple.com/documentation/screencapturekit/capturing-screen-content-in-macos)
- [SCShareableContent](https://developer.apple.com/documentation/screencapturekit/scshareablecontent)
- [SCContentFilter](https://developer.apple.com/documentation/screencapturekit/sccontentfilter)
- [SCContentSharingPicker](https://developer.apple.com/documentation/screencapturekit/sccontentsharingpicker)
- [WWDC23: What's new in privacy](https://developer.apple.com/videos/play/wwdc2023/10053/)
- [SCWindow](https://developer.apple.com/documentation/screencapturekit/scwindow)
- [SCRunningApplication](https://developer.apple.com/documentation/screencapturekit/scrunningapplication)
- [iPhone Mirroring requirements](https://support.apple.com/120421)
- [SCStreamFrameInfo](https://developer.apple.com/documentation/screencapturekit/scstreamframeinfo)
- [screenRect](https://developer.apple.com/documentation/screencapturekit/scstreamframeinfo/screenrect)
- [SCFrameStatus](https://developer.apple.com/documentation/screencapturekit/scframestatus)
- [WWDC22: Take ScreenCaptureKit to the next level](https://developer.apple.com/videos/play/wwdc2022/10155/)
- [NSWindow](https://developer.apple.com/documentation/appkit/nswindow)
- [NSWindow.ignoresMouseEvents](https://developer.apple.com/documentation/appkit/nswindow/ignoresmouseevents)
- [Ordering a window relative to another](https://developer.apple.com/documentation/appkit/nswindow/order(_:relativeto:))
- [SCWindow.windowID](https://developer.apple.com/documentation/screencapturekit/scwindow/windowid)
- [CGWindowListCopyWindowInfo](https://developer.apple.com/documentation/coregraphics/cgwindowlistcopywindowinfo(_:_:))

### Interface availability

- [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass)
- [View.glassEffect](https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:))

## Review and policy implications

Picture in Picture must act as genuine, user-started video PiP. The system owns
its size, placement, controls, and lifecycle. A utility-only floating dashboard
is outside the clearest media use and carries App Review risk. The feasibility
build should present continuously changing visual content, explain the
user-started flow, and retain a useful standalone screenshot-analysis mode.

The product identity and bundled assets must avoid unlicensed third-party names,
artwork, and screenshots. CuePilot must work without private APIs, background
capture tricks, or interaction automation.

## Research boundary

Public documentation establishes API availability, not success with a
particular third-party screen or window. Xcode 26.6 and the required SDKs are
now installed, but no signed-device or live iPhone Mirroring result exists.
Live behavior and performance remain unverified until the feasibility matrices
in the companion documents are completed.
