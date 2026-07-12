# C18 — THE WHIRLPOOL (spec)

> The second system of the TEMPEST arc. Interview locked 2026-07-12; **mockup gate:
> `design/the-tempest.html` APPROVED AS-IS 2026-07-12** — the vortex on that page (foam-dash spiral
> arms, subtle darkening, circling debris, restrained pull) is the visual reference and its rail
> values ship as config defaults. Research: `docs/research/naval-systems.md` §3 — real strait
> whirlpools are bathymetric, tide-clocked, and dangerous to small craft, never to big hulls.
> Implementation in a FRESH session per house law, after owner approval of this spec.

## Identity

**Every strait has THE whirlpool.** One charted, seeded vortex at an island constriction — a
landmark you learn, time, and use: a lane that opens and closes on the tide, a grinder you herd
small craft into, a shield that bends torpedoes off their line. Never a black hole: the pull is
capped, the battleship is never doomed, and the art IS the hitbox.

## Owner interview decisions (2026-07-12 — locked)

1. **Tier = FULL TACTICAL TERRAIN** (from the research interview): seeded placement, tide clock,
   mass-tiered pull — battleship ×0.25 / small waterborne craft ×1.0 / torpedoes ×1.6 — capped
   radial, zero player hull damage.
2. **Count = ALWAYS EXACTLY ONE.** The seed places a single vortex at the best-scoring
   constriction (min-distance from the ship's start clearing; open-water fallback if a map somehow
   has no pinch). A landmark, always somewhere new — simplest to tune and to teach.
3. **Tide = WAVE-KEYED CYCLE.** A seeded cycle keyed to wave count — builds over ~3 waves, peaks,
   ebbs to a floor. Independent of the C17 weather clock (the cycle×weather option was offered and
   not taken). Dormant = a crossable lane with a lazy foam ring; peak = lane denied. The radio
   calls the tide.
4. **The grinder KILLS, full XP.** GNAT/JACKAL-class small craft capsize inside the core
   (~15 % of radius) at tide ≥ ~0.8 — it counts as the player's kill at normal XP (herding is
   play and pays like play). Subs and war machines are never grinder-killed.
5. **The eye = HELM FIGHT.** Inside the core at high tide: heavy yaw torque + rudder authority
   briefly halved — you fight the wheel and lose firing solutions while the waves keep coming.
   Still never hull damage.

**Accepted defaults (tunable, not forks):** the approved rail values — influence radius 170 u,
swirl 30 u/s², inward 11 u/s² (tangential:radial ≈ 3:1 — crossing WITH the rotation is a
slingshot), foam spin 0.5; tide floor 0.15, capsize threshold 0.8; subs unaffected by the field
(they run beneath it), air ignores it entirely; the capsize death is a grounded spin-under (no
explosion), with debris joining the rim.

## The system

- **Placement:** rolled once at world init on a **dedicated substream**
  (`Rng.new((seed ^ 0x57503138) & 0xFFFFFFFF)`) — ZERO `world.rng` draws, so the combat stream is
  untouched whether the feature is on or off. Scoring: narrowest navigable gap between C15
  features, min-distance from the ship start (the terrain start-clearing precedent), fixed for the
  whole run. Charted bathymetry, not an event.
- **The field (pure arithmetic, no rng):** `v(p) = T(r)·perp(dir) − R(r)·dir`, r normalized 0–1;
  T peaks near r≈0.35 and holds; R smoothsteps to a **cap** (the cap is what makes it a whirlpool,
  not a black hole); both × `tide(wave)` ∈ [0.15, 1]. Applied as acceleration with per-class
  multipliers: player hull in `Movement.step` (⚠ exact insertion vs. drag/terrain confirmed at
  build), waterborne small craft in `Enemies.step`, torpedoes in `Projectiles.gd`. Air untouched;
  subs untouched; the MAW in both states untouched (too big).
- **The grinder:** a small craft inside r < 0.15 at tide ≥ 0.8 dies — normal XP path, a new
  `"capsize"` effect for the render (spin-under, no fireball), debris feeds the rim.
- **The helm fight:** player inside r < 0.15 at high tide → yaw torque + rudder authority ×0.5.
  Surfaced on `world` so HUD/radio can speak it. No hull damage from the vortex, ever.
- **Scope:** the vortex is charted — drawn on the RadarScope like the C15 coastlines (a small
  spiral glyph + faint influence ring), always visible, never a contact blip.
- **Render (approved mockup, ported):** three log-spiral arms as foam dashes (rotation speed
  encodes tide), darkening well whose radius = influence radius (the art is the hitbox), circling
  debris motes, small eye. `reduced_motion`: spiral holds still, debris static, pull unchanged
  (it's sim). **Audio:** a low diegetic water-roar ramping with tide × proximity (Corryvreckan is
  heard for miles) via `tools/gen_sfx.py`.
- **Radio:** MET SECTION tide calls — "VORTEX AT FULL CHURN, LANE CLOSED" at peak, "SLACK WATER"
  at ebb; a first-encounter drip line the first time the pull touches the hull.
- **Config:** `config/WhirlpoolConfig.gd` + `whirlpool.tres` — radii, T/R curve values, per-class
  multipliers, tide period/floor/capsize threshold, placement scoring knobs, the count field
  (fixed 1; raising it is a CR). Registered in `Configs.defaults()`/`load_all()` + the
  `.duplicate()` line in `Tech.apply()`.
- **Determinism contract:** disabled ⇒ byte-identical to pre-C18; enabled, the field is an
  analytic function of position + wave count and placement lives on its own substream — two-world
  probes stay green either way.

## Verify

`tests/probe_whirlpool.gd`, wired into `verify.sh`: (1) two-world determinism enabled; (2) disabled
⇒ byte-identical pre-C18 baseline; (3) same seed ⇒ same site, start clearing respected; (4) tide
cycle deterministic and bounded [floor, 1]; (5) mass tiers observable — player accel ≤ cap ×0.25,
a torpedo's track visibly deflects, a sub's does not; (6) grinder law — small craft in core at
peak dies + XP banks, below threshold nothing dies, sub/machine immune; (7) helm fight only in
core at high tide, rudder authority restored on exit; (8) the vortex never damages the hull.

## Out of scope (named, not drifted into)

More than one vortex (CR raises the count) · weather-coupled intensity (declined at interview) ·
vortices as depth-charge/DC interactions · dynamic spawn/despawn · any effect on the AIR WING.
