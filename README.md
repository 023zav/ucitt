# UCI TT Position Checker (MVP)

Point a phone at a side-on time-trial bike with a printed scale marker in frame,
tap a few landmarks, and get each UCI cockpit measurement with its margin to the
limit.

> **Pre-check, not certification.** Target accuracy ±5–10 mm. Anything within
> ~10 mm of a limit is flagged "borderline" and must be re-checked with proper
> tools before a race.

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

Everything is solved in the bike's **sagittal (side) plane**, so the math is 2D:

1. A level, coplanar marker of known mm size is detected → four corner pixels.
2. A **homography** maps image pixels → millimetres in that plane.
3. Tapped landmarks are pushed through the homography to mm.
4. Distances/angles are computed in mm, then evaluated against `UCIRules`.

The **BB trick**: the bottom-bracket axle is hidden, but it is the concentric
center of the chainring — the user taps that.

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

Build and run **on a physical iPhone** — the simulator has no camera. Screens
follow the spec flow: Onboarding → Rider input → Capture → Guided tapping (loupe
+ draggable points) → Results.

## Notes / known limits

- **Marker detection** uses Vision rectangle detection for a dependency-free
  MVP. `MarkerDetecting` is a protocol — drop in an OpenCV **ArUco** detector
  (preferred, per the spec) without touching the rest of the app.
- **Lateral-offset caveat:** the tip and armrests sit laterally offset from the
  marker plane. If the marker isn't coplanar with the cockpit centerline,
  foreshortening adds error — the main accuracy limiter. v2: LiDAR depth at the
  marker vs. each landmark to scale-correct.
- Landmarks are placed by guided taps only; no auto-detection in the MVP.

See `SPEC.md` for the full brief.
