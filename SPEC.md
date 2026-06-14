# UCI TT Position Checker — MVP Spec

A spec for an iOS app that estimates whether a time-trial bike's cockpit (aero
extensions + armrests) meets UCI position limits, using the camera + a printed
scale marker.

---

## 1. Goal & positioning

**One-liner:** Point the phone at a side-on TT bike with a printed marker in
frame, tap a few landmarks, get each UCI cockpit measurement with margin-to-limit.

**This is a pre-check / setup tool, not a legal certification.** Target accuracy
±5–10 mm. The UI must communicate that anything within ~10 mm of a limit should be
re-checked with proper tools before a race.

**In scope (MVP):**
- Reach (BB → extension tip, horizontal)
- Extension height (armrest mid-point → extension tip, vertical)
- Armrest leading-edge → extension tip (horizontal, minimum)
- Armrest angle
- Saddle setback (saddle nose → BB vertical plane, horizontal) — needed to pick category
- Rules engine: category determination + pass/fail + margin per measurement

---

## 2. Target & stack

- **Device:** iPhone Pro (12 Pro or later). LiDAR optional for MVP; the marker
  carries scale. Require a Pro only if/when depth fusion lands in v2.
- **Min iOS:** 17.
- **UI:** SwiftUI.
- **Camera:** AVFoundation (still capture is enough for MVP; no need for live AR).
- **Marker detection:** OpenCV ArUco via Swift Package Manager wrapper, OR
  Vision rectangle/marker detection. Prefer ArUco — robust pose from a known tag.
- **Geometry math:** plain Swift (simd). No ARKit required for the MVP path.
- **Motion:** CoreMotion only if deriving gravity; preferred approach uses a
  level-placed marker instead (see §6).

> Note: the simulator has no camera. The build→run→tune loop must run on a
> physical device.

---

## 3. Measurement principle

Every MVP measurement lives in the bike's **sagittal (side) plane**, so the app
works in 2D, not 3D:

1. A printed marker of known physical size is placed **coplanar with the bike's
   cockpit centerline** and **level** (one marker axis plumb).
2. From the marker's four corners (known mm size) the app computes a
   **homography** mapping image pixels → real-world millimetres in that plane.
3. The user taps landmarks; each tap is transformed through the homography to
   mm coordinates.
4. Distances and angles are computed in mm. Because the marker is placed level,
   the rectified frame's axes are world horizontal/vertical.

**BB center trick:** the bottom-bracket axis is hidden inside the frame, but it
is the rotation center of the crank, i.e. the concentric center of the chainring.
The user taps the visible chainring center; that is the BB reference point.

---

## 4. User flow (screens)

**S1 — Onboarding / marker setup** — explain print-at-size, tape to a board,
stand it next to the bike in line with the extensions, make it level.

**S2 — Rider inputs** — height (cm); saddle position measured but with a manual
override toggle.

**S3 — Capture** — live camera guide; on capture, detect the marker and reject
bad captures with a reason; show detected outline + confidence.

**S4 — Guided tapping** — sequential prompts, one landmark at a time, each with a
zoom loupe; placed points draggable; all points overlaid.

**S5 — Results** — per measurement: value (mm), limit, margin (±), pass/fail/
borderline; category applied + why; persistent disclaimer; save/share.

Landmark order: chainring center (BB), extension tip, armrest mid-point, armrest
leading edge, armrest rear reference, saddle nose.

---

## 5. Landmark & measurement definitions

| Point | Definition |
|---|---|
| `bb` | Chainring concentric center (bottom-bracket axle center) |
| `tip` | Forward-most end of the extensions (incl. any bar-end accessory) |
| `armMid` | Mid-point of the armrest top surface |
| `armLead` | Leading (forward) edge of the armrest |
| `armRear` | Rear edge of the armrest top surface (defines the surface line for angle) |
| `saddleNose` | Forward-most point of the saddle nose |

| Measurement | Formula | Axis |
|---|---|---|
| Reach | `tip.x − bb.x` | horizontal |
| Extension height | `armMid.y − tip.y` (abs) | vertical |
| Armrest→tip | `tip.x − armLead.x` | horizontal, must be ≥ min |
| Armrest angle | `atan2(armRear.y − armLead.y, armRear.x − armLead.x)` vs horizontal | degrees |
| Saddle setback | `bb.x − saddleNose.x` | horizontal (positive = behind BB) |

All `.x/.y` are in mm in the rectified, world-aligned plane.

---

## 6. Geometry math details

**Homography:** solve for the 3×3 H from the four marker-corner image points →
four known marker-corner mm points. Apply H to every tapped pixel to get mm.

**World alignment:** require the marker placed level; the marker's mm frame *is*
world horizontal/vertical. Add a tilt check at capture: reject if the detected
marker's horizontal axis deviates > ~1° from level.

**Lateral-offset caveat:** the tip and armrests sit laterally offset from the
wheel/marker plane. If the marker isn't coplanar with the cockpit centerline,
foreshortening adds error. MVP mitigation: place the marker in line with the
extensions. Residual error is the main accuracy limiter. (v2: LiDAR depth.)

**Units:** keep everything in mm internally. Marker physical size is a config
constant the user confirms.

---

## 7. UCI rules engine

Inputs: `heightCm`, `saddleSetbackMm` (measured or overridden).

```
if saddleSetbackMm < 50:   category = "Forward"; reachMax = 750; heightMax = 100
else if heightCm < 180:    category = "Cat 1";   reachMax = 800; heightMax = 100
else if heightCm < 190:    category = "Cat 2";   reachMax = 830; heightMax = 120
else:                      category = "Cat 3";   reachMax = 850; heightMax = 140
```

**Fixed limits (all categories):**
- Armrest leading-edge → extension tip: **minimum 180 mm** (horizontal)
- Armrest angle: **maximum 30°**

**Flags (surface, don't hard-fail):**
- Height ≥ 180 cm → Cat 2/3 require a UCI online application form + a frame
  sticker before the event; without it the rider is held to Forward limits.
- Saddle setback has its own minimum-distance rule (with morphological
  exemption) — "verify against current UCI rulebook," don't encode a hard number.

**Per-measurement output:** `{ value, limit, direction (max|min), margin, state }`
where state ∈ {pass, borderline (|margin| ≤ 10 mm), fail}.

> All numeric limits live in a single `UCIRules` config with a `rulesVersion`
> string. Treat the values above as current-as-of-2024/25 and easy to bump.

---

## 9. MVP acceptance criteria

- Detects a level, coplanar marker and rejects bad captures with a clear reason.
- Produces all five measurements from six taps, points fine-adjustable.
- Applies the correct category and shows margin-to-limit per measurement.
- Repeatability: same bike/placement, 5 runs → spread ≤ ~5 mm on reach.
- Clear, persistent "estimate, not certification" disclaimer.

---

## 10. Build notes

- Start with `Geometry` + `Homography` + the rules engine — pure, testable, no
  device. Cover them with unit tests using synthetic point sets.
- Then `MarkerDetector` + capture, which require on-device iteration.
- Keep the rules table data-driven from day one.
- No auto-detection of landmarks in the MVP — guided taps only.
