# C10 — TACTICAL ZOOM (spec — AT THE GATE)

> Status: mockup gate. `design/tactical-zoom.html` is the gate artifact (forked from the approved
> C9 living-sea machinery, sea locked to the approved preset). This is a **formal Change Request**:
> the camera was deliberately fixed at 0.85 in C1 (`scenes/Main.tscn`, hardcoded) — this chunk
> supersedes that with a player-controlled tactical zoom. The owner directive (research-pass
> interview 2026-07-09, recorded in the DECISIONS Change Log): **~2× out** — wheel zoom to ~0.4,
> smoothed; existing art survives via stroke compensation + a minimum-apparent-size floor;
> **NO icon/blip LOD stage**. He judged the C9 sea at **zoom 0.51** — the wide view is home.

## 1. Why (owner, research pass)

Most combat already happens off-screen at the fixed 0.85 view: the main battery reaches 900u,
gunboats fire from 700u, subs torpedo from 800u — but the visible half-height is ~424u. The
radar carries the load alone. Zoom to ~0.4 puts the whole gun envelope on the main view
(~3200×1800u) and sets up C11's burst-at-cursor fire control (the cursor becomes able to
express real distance — the C3 bearing-only rationale dissolves).

## 2. Hard rules

- **Render/app-layer ONLY.** The sim never reads camera state (GameWorld's law: "No sim system
  may ever read screen size"). `world.input.aim_world` already comes through
  `get_global_mouse_position()`, which is camera-aware — aiming inherits zoom for free and the
  sim never knows. Two-world determinism probes must stay byte-identical.
- **Ship-centered camera stays.** The C1 camera is hard-locked to `ship_pos`; radar, culling,
  and the fire-control bearing all assume it. Zoom scales around the ship — the directive's
  "cursor-anchored" detail is superseded by this rationale at the gate (anchoring would fight
  the ship lock every frame and skew the radar's viewport-extent read).
- **No LOD stage.** Art survives as itself: stroke compensation (outline widths hold their
  0.85-baseline apparent size) + a minimum-apparent-size floor for the smallest hostiles.
  The C9 sea already fades its high-frequency layers with zoom and clamps splash minimums.
- **Camera tunables live in `config/camera.tres`** (new `CameraConfig.gd` — per-system config
  rule; `FieldConfig` explicitly refuses unrelated tunables). The `.tscn`-hardcoded 0.85 dies.

## 3. The mechanics (defaults = gate knobs, owner-tunable)

| knob | default | meaning |
|---|---|---|
| `zoom_min` | 0.40 | farthest out (the C10 floor the C9 art was proven at) |
| `zoom_max` | 0.85 | closest in (today's LOOK-LOCKED view) |
| `zoom_home` | 0.51 | sortie-start zoom and the H-key snap — the owner's judged view |
| `wheel_step` | 1.18 | multiplicative zoom per wheel notch |
| `lerp_half_life` | 0.12 s | exponential smoothing toward the target (no snap; motion-sick-safe) |
| `enemy_min_px` | 10 | smallest hostiles never render under this apparent size |
| `stroke_comp` | on | outline widths compensate to hold the 0.85-baseline look |

- Wheel input: `zoom_in`/`zoom_out` actions (mouse wheel up/down) → `target_zoom` multiplied by
  `wheel_step`, clamped. The camera's actual zoom lerps toward the target
  (`1 − 0.5^(dt/half_life)`); fades/LOD-ish reads use the TARGET so nothing shimmers mid-lerp.
- `H` (`zoom_home` action) snaps the target to home. Sorties START at home.
- Stroke compensation: world-art outline widths multiply by `clamp(0.85/zoom, 1.0, 2.2)` —
  identical to today at 0.85, holds apparent width at 0.4. Chart grid stays a 1-px hairline.
  Fills are untouched (they scale honestly).
- Min-size floor: swarmer-class draws scale by `max(1, min_px / (apparent_px))` so the smallest
  hostiles stay targetable at the floor. HP pips and the sub ripple tell get width compensation.
- HUD (CanvasLayer) is zoom-immune by construction; the radar's viewport-extent rectangle and
  `FieldRenderer.view_rect()` culling already read `cam.zoom` live (verified C9).

## 4. Acceptance

1. Full verify gate green; determinism probes byte-identical (camera is invisible to the sim).
2. Sortie boots at 0.51; wheel spans 0.40–0.85 smoothly; H snaps home.
3. At 0.40: hull/turret art, swarmers, torpedo wakes, splash columns, and the ripple tell all
   legible (screenshot harness `ScreenshotC10`: home / floor / max, comp on).
4. Zero sim diffs beyond none-at-all: this chunk touches Main, render, configs, project input
   map only.
5. Gate tunes recorded back into `camera.tres` + this spec + the mockup (the C9 pattern).
