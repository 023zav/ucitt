# UCI TT Position Checker (MVP)

Point a phone at a side-on time-trial bike, mark a few landmarks, and get each
UCI cockpit measurement with its margin to the limit. **No printing** — scale
comes from either a bank card you already own or ARKit depth.

> **Pre-check, not certification.** Target accuracy ±5–10 mm. Anything within
> ~10 mm of a limit is flagged "borderline" and must be re-checked with proper
> tools before a race.

## Two measurement modes

- **LiDAR scan (Pro devices, primary):** markerless. Aim the on-screen reticle
  at each landmark and tap to capture a gravity-aligned 3D point (LiDAR depth at
  the reticle); no reference object.
- **Wheel photo (any iPhone, fallback / cross-check):** one square-on side-on
  photo. Scale comes from the bike's own wheel — tap the two hub centers (their
  line is horizontal) and a tyre-to-ground contact (hub→ground = wheel radius),
  then the six landmarks. Nothing to attach.

## What it measures

| Measurement | Definition | Limit |
|---|---|---|
| Reach | extension tip → BB, horizontal | category max |
| Extension height | armrest mid → tip, vertical | category max |
| Armrest → tip | armrest leading edge → tip, horizontal | min 180 mm |
| Armrest angle | tilt of armrest surface vs horizontal | max 30° |
| Saddle setback | saddle nose → BB, horizontal | selects category |

Category is chosen from rider height + saddle setback (§7 of the spec); all
numeric limits live in `UCIRules` with a `rulesVersion` string so they can be
bumped when the UCI revises them.

## How it works

**Bank-card mode** is solved in the bike's **sagittal (side) plane** in 2D:

1. The card (known mm size) is detected → four corner pixels.
2. A **homography** maps image pixels → millimetres in that plane.
3. Tapped landmarks are pushed through the homography to mm.
4. Distances/angles are computed in mm, then evaluated against `UCIRules`.

**ARKit mode** captures each landmark as a gravity-aligned 3D point (mm).
Horizontal measurements use ground-plane distance, vertical uses the gravity
axis, and the armrest angle is the inclination of the armrest line — these match
the 2D formulas for a side-on rig. Both modes share the same `ReportBuilder` /
rules engine.

The **BB trick**: the bottom-bracket axle is hidden, but it is the concentric
center of the chainring — the user marks that.

## Project layout

```
Package.swift                 # SwiftPM: the pure, testable core (no device needed)
Sources/UCITTCore/            # Geometry, Homography, rules engine, pipeline
Tests/UCITTCoreTests/         # unit tests over synthetic point sets
App/UCITTChecker/             # the iOS app (SwiftUI + AVFoundation + Vision)
project.yml                   # XcodeGen spec -> UCITTChecker.xcodeproj
```

### Core (`UCITTCore`)

Depends on Foundation only, so it builds and tests on any Swift toolchain:

```bash
swift test
```

Key types: `Homography` (DLT from 4 correspondences), `Geometry`, `Measurement`,
`UCIRules` / `CategoryEngine` / `Evaluator`, `MarkerGeometry` (capture-quality
gate), and `PositionChecker` (the end-to-end pure pipeline).

### App

```bash
brew install xcodegen      # once
xcodegen generate          # creates UCITTChecker.xcodeproj
open UCITTChecker.xcodeproj
```

Build and run **on a physical iPhone** — the simulator has no camera/ARKit.
Flow: Onboarding (pick mode) → Rider input → Capture/Scan → Results.

## Notes / known limits

- **Card detection** (bank-card mode) uses Vision rectangle detection, tuned for
  a card's aspect ratio. `MarkerDetecting` is a protocol, so a more robust
  detector can drop in without touching the rest of the app.
- **Lateral-offset caveat (card mode):** the tip and armrests sit laterally
  offset from the card plane. If the card isn't coplanar with the cockpit
  centerline, foreshortening adds error — the main accuracy limiter. ARKit mode
  avoids this by measuring true 3D positions.
- **ARKit accuracy** depends on tracking quality and LiDAR; treat it as the same
  ±5–10 mm pre-check, not a certification.
- Landmarks are placed manually (taps / reticle); no auto-detection in the MVP.

See `SPEC.md` for the full brief.
