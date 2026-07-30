# Fidelity ledger

This ledger distinguishes source implementation from rendered runtime evidence.
No simulator runtime is installed, and no final live Mac screenshot has been
approved, so visual fidelity remains provisional.

| Area | Intended hierarchy | Source implementation | Runtime evidence | Status |
| --- | --- | --- | --- | --- |
| Home | One dominant Live Assist action with screenshot, match, calibration, tools, and settings below | Implemented in `HomeView` | UI test declared; not run | Source complete, render pending |
| Live setup | Three explicit public-API steps with live status and privacy rows | Implemented in `LiveAssistSetupView` | Signed iPhone required | Source complete, device pending |
| Detection review | Table-dominant canvas with manual corners, balls, pockets, classification, and rules | Implemented in `DetectionReviewView` and `EditableTableView` | Simulator/device not run | Source complete, render pending |
| Shot result | Alignment state, annotated table, power range, confidence, and match link | Implemented in `ShotResultView` | Simulator/device not run | Source complete, render pending |
| Match session | Turn, group, called pocket, remaining balls, and end action | Implemented; prior-shot history is not populated or persisted | UI test declared; not run | Partial behavior |
| iPhone calibration | Local profile surface, outcome picker, and reset | Screen changes only in-memory status and left/right angular correction | UI test declared; not run | Partial behavior |
| Settings | Native sections, privacy details, diagnostics, and overlay preview | Implemented; diagnostics export action is a placeholder | UI test declared; not run | Partial behavior |
| Mac shell | Native sidebar, toolbar, capture canvas, inspector, calibration, and settings | Implemented in SwiftUI/AppKit | Swift Package target build passed; no live approved render | Source complete, live render pending |
| Mac overlay | Transparent click-through guidance aligned to selected content | Implemented with registration and stale-frame shutdown | No live Mirroring capture | Source complete, live proof pending |
| Palette | Graphite, teal, semantic green/amber/red | Theme values and semantic states implemented | No final screenshot comparison | Source complete, render pending |
| Typography | System type with deliberate hierarchy and monospaced measurements | Implemented throughout views | No accessibility/runtime comparison | Source complete, render pending |
| Responsive layout | iPhone portrait and resizable Mac window | Adaptive SwiftUI layout declared | No simulator/device matrix | Runtime pending |

Before release, attach named simulator/device screenshots or a reviewed Mac
capture for each primary surface and record any variance from the intended
hierarchy. Do not mark a row complete from source inspection alone.
