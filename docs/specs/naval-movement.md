# Spec — C1: Naval Movement

**Status:** APPROVED-PENDING (owner sign-off on this document) · Interviewed 2026-07-08
**Resolves:** DECISIONS.md D1.6's deferral ("do not implement movement mechanics without a dedicated
spec pass first" — this is that pass).

## Goal

Replace the C0 placeholder (static ship dot) with real naval piloting: a battleship with momentum,
weight, a wide turning circle, and visible lateral slip. Piloting is the game's only hands-on verb —
hardpoints will auto-fire (D1.7), so how the hull moves through the water IS the player's skill
expression. The ship must feel commanded, not dragged: committing to a line matters, stopping is a
deliberate act, and a hard turn visibly slides the hull before the keel catches.

## Player-facing behavior

- **W** — throttle ahead. From a dead stop, holding W reaches full ahead speed in **~4–5 seconds**.
- **S** — brake, then astern. Braking is stronger than thrust; holding S through the stop smoothly
  builds reverse speed, capped at **~35% of ahead speed** (one continuous control, no re-press gate).
- **A/D** — turn. Turn rate **couples to current speed with a floor**: full rudder authority near full
  speed, degrading toward a minimum floor at a standstill — the ship always answers the helm, just
  sluggishly when slow. Turn direction meaning is screen-fixed (D = clockwise) regardless of ahead/astern.
- **No input** — the ship **coasts long**: water drag bleeds speed slowly (still visibly gliding many
  seconds after throttle-off). Stopping fast requires S.
- **Lateral slip** — in a hard turn at speed, velocity lags behind heading: the hull visibly slides
  sideways through the turn before settling onto the new course. This is the "weight" read.
- **Camera** — north-up, fixed orientation, following the ship (C0's follow-cam). The hull swings its
  heading on screen; the world never rotates.
- Player sees a **hull silhouette** (top-down battleship read: distinct bow/stern, superstructure hint),
  a **wake trail** whose length/spread reads speed and slip, and a **speed/throttle readout** (minimal
  HUD element — the first piece of the future gauge bank).

## Mechanics

- **New sim system: `scripts/engine/systems/Movement.gd`** — static `step(world, dt, cfg)`, the first
  entry in `Sim.step`'s fixed order. Pure arithmetic, **no RNG**.
  - Integration model: thrust along `heading` from the W/S axis; anisotropic exponential drag
    (low along-keel drag = long coast; high-but-finite lateral drag = slip that decays but exists);
    turn rate = `turn_rate_max * max(turn_speed_floor, |speed|/max_speed_ahead)` scaled by the A/D axis.
    Heading drives velocity — never fulfillment's `heading = vel.angle()` (that's the arcade
    anti-pattern this chunk exists to replace).
- **New: `scripts/engine/data/InputState.gd`** — sim-side input snapshot: `thrust: float` (−1..1 from
  S/W) and `rudder: float` (−1..1 from A/D). Main writes it from Godot input each frame; sim only reads it.
- **`GameWorld` changes:** `ship_pos`/`ship_heading` placeholders become the real ship state:
  `ship_pos: Vector2`, `ship_vel: Vector2`, `ship_heading: float`, plus `input: InputState`. No other
  state added — throttle is held-key (no persistent telegraph state).
- **`Sim.step` order:** `Movement.step` is system #1; the "no systems yet" comment block retires.
- **Render:** `FieldRenderer` replaces the C0 dot with the drawn hull silhouette (rotated to
  `ship_heading`) and a render-side wake trail (cosmetic: own state, fed one-way from ship pos/vel —
  never sim-affecting). Speed/throttle readout is a small `ui/` element reading the world one-way.

## Config — `config/MovementConfig.gd` + `config/movement.tres` (per-system config rule)

| Tunable | Start value | Meaning |
|---|---|---|
| `max_speed_ahead` | `220.0` | full ahead speed, u/s |
| `astern_frac` | `0.35` | reverse cap as a fraction of ahead |
| `thrust_accel` | `55.0` | u/s² under full throttle (~4.5s to full) |
| `brake_accel` | `90.0` | u/s² while S opposes forward motion |
| `drag_forward` | `0.08` | 1/s exponential along-keel drag (long coast) |
| `drag_lateral` | `1.8` | 1/s lateral drag (slip decays, visibly) |
| `turn_rate_max` | `0.55` | rad/s at full speed, full rudder |
| `turn_speed_floor` | `0.25` | min fraction of turn authority at standstill |

Wake/HUD cosmetics tune in `FieldConfig`/a small HUD config, not here. All values are first-playable
anchors — the owner tunes by feel against the mockup and the live build.

## Visual spec (mockup gate: mock → approve → port)

`design/naval-movement.html` — an **interactive, keyboard-driven** canvas mockup implementing this
exact model (same tunables, same integration), proving before any Godot code:
1. the top-down hull silhouette and its legible heading swing,
2. the wake trail reading speed + slip,
3. the speed/throttle readout,
4. the feel numbers: ~4–5s to full speed, long coast, floor-coupled turning, visible lateral slip in a
   full-speed turn.
Owner approves the mockup's feel; then it ports. (No scripted turning-circle demo — judging is hands-on.)

## Determinism notes

- **Zero new `world.rng` draws.** Movement is pure arithmetic; the determinism tripwire (`rng.calls`)
  must be byte-identical with movement running or idle.
- Wake trail is render-side cosmetic state (own RNG if it ever needs jitter — never the sim's).
- Input enters the sim only via `InputState`, written by Main before stepping — same one-way pattern as
  fulfillment.

## Acceptance checks (`tests/probe_movement.gd`; add a `verify.sh` step)

1. **Determinism:** two worlds, same seed, same scripted input sequence, 600 ticks → identical
   `ship_pos`, `ship_vel`, `ship_heading`, and `rng.calls` (which must equal the input-idle count).
2. **Accel:** from rest, full W → ≥95% of `max_speed_ahead` between 3.5s and 5.5s.
3. **Coast:** release at full speed → after 5s of no input, speed still > 50% of max (long coast).
4. **Brake + reverse:** hold S from full ahead → forward speed reaches 0 markedly faster than coasting,
   then goes astern, capping within 2% of `max_speed_ahead * astern_frac`.
5. **Turn floor:** at standstill, full rudder turns heading at ≥ `turn_speed_floor * turn_rate_max`.
6. **Slip:** in a sustained full-speed full-rudder turn, the lateral (cross-keel) velocity component
   exceeds a threshold mid-turn, then decays when the rudder centers.
7. Existing `probe_sim` lockstep checks still pass unchanged.

## Out of scope (explicit cuts from the interview)

- **Boost / emergency power** — no flank-speed override; if ever wanted, it's its own interview.
- **World bounds / arena edge** — open ocean; bounds arrive with wave/spawn design.
- **Collision** with enemies/objects — comes with combat chunks.
- **Sea state affecting handling** — water is flat for handling; any swell is a future pass (cosmetic
  ocean texture in the mockup is fine, zero sim effect).
- Turning-circle scripted demo in the mockup (cut — hands-on judging instead).

## DECISIONS.md impact

No conflicts. At implementation time: supersede **D1.6**'s deferral with the chosen model (car-style
hold, coupled turn w/ floor, lateral slip, long coast, slow astern) via a Change Log entry pointing at
this spec. D1.4 (determinism), the config-split rule, and the mockup gate are all satisfied as designed.
