# CuePilot design system

## Direction

CuePilot is a precision instrument, not a game skin. The interface uses native
Apple structure, open layouts, deliberate typography, and one dominant working
surface at a time.

## Color

| Role | Value |
| --- | --- |
| App canvas | `#0D1012` |
| Elevated graphite | `#1A1E20` |
| Table surface | `#0D4F51` |
| Primary text | `#F5F7F7` |
| Secondary text | `#A7AFB2` |
| Separator | `#343A3D` |
| Action teal | `#16B8AE` |
| Confirmed lock | `#78D65B` |
| Caution | `#F0B640` |
| Destructive | `#F34D4D` |

Green is reserved for a legal, stable, high-confidence lock. It is never used
as decoration.

## Typography

- System font throughout.
- Large status: 34–44 pt, semibold, compact line height.
- Screen title: native navigation title.
- Primary action: 17–20 pt, semibold.
- Body and list rows: 16–17 pt.
- Analysis labels: 13–15 pt, medium, with tabular numbers.
- Secondary values: 13–15 pt, regular.

## Components

- Native navigation stacks, lists, forms, toolbars, split views, inspectors,
  toggles, sliders, and segmented controls.
- One framed table/capture canvas per analytical screen.
- Thin separators instead of stacked cards.
- Capsule or rounded-rectangle primary controls only where the platform uses
  them naturally.
- Monochrome symbols; semantic color only for action, status, warning, and
  destructive meaning.
- A small cue-line-and-ball mark is the only brand ornament.

## Container model

- iPhone: open vertical rail with one dominant action or table surface.
- Mac: system sidebar, central capture canvas, native inspector.
- PiP: a live visual feed or rendered table state, never a generic floating
  dashboard and never described as a transparent anchored overlay.

## Motion

- Status changes use short opacity and scale transitions.
- Lock requires agreement across consecutive frames before the green state
  appears.
- Reduced Motion replaces spatial transitions with crossfades.

## Concepts

- `Concepts/iphone-home.png`
- `Concepts/iphone-live-setup.png`
- `Concepts/iphone-detection-review.png`
- `Concepts/iphone-live-assist.png`
- `Concepts/iphone-match-session.png`
- `Concepts/iphone-settings.png`
- `Concepts/macos-precision-overlay.png`
