# C17 — WEATHER FRONTS (spec)

> The first system of the TEMPEST arc. Interview locked 2026-07-12; **mockup gate:
> `design/the-tempest.html` APPROVED AS-IS 2026-07-12** — the page is the visual reference and its
> default rail values ship as the config defaults. Research basis: `docs/research/naval-systems.md`.
> Implementation happens in a FRESH session per house law, after owner approval of this spec.

## Identity

A **light tactical layer**, not a physics sim: a seeded schedule of weather FRONTS rolls over the
strait, each front cutting **detection** for both sides while it lasts. The sea already knows how to
look like weather (C9); this chunk makes weather *mean* something — and the FLEET RADIO gets to be
a met office. Lightning stays spectacle (the contact-reveal variant was offered and declined).

## Owner interview decisions (2026-07-12 — locked)

1. **Tier = light tactical layer** (from the research interview): seeded fronts + detection
   attenuation + radio forecast. No wind physics, no gunnery dispersion, no lightning gameplay.
2. **Cadence = ESCALATING.** Early waves mostly clear; the first front lands around wave 4–6, then
   fronts arrive more often, heavier, and longer as the run deepens. Weather is a late-run pressure
   axis stacking with the director's own escalation.
3. **Shape = GLOBAL STATE (v1).** One weather state for the whole strait per wave. The drifting
   squall *band* (enter/exit, hide your wake in it) is the named follow-up — config reserves the
   fields; superseding global requires a CR, not a drift.
4. **Attenuation = ALL DETECTION, symmetric.** Radar blip acquisition, sonar radius (ship AND the
   bird's dip), and turret auto-acquire range — ours and theirs equally. Force-fire is untouched
   (the cursor doesn't need eyes). Gunnery dispersion explicitly NOT taken.
5. **Couplings: boss waves stay clear + ground the bird.** The schedule never lands a front on an
   every-Nth machine wave (weather and boss difficulty never stack). The AIR WING returns to the
   pad while a SQUALL/THUNDERHEAD is up — you lose the dip and the door guns exactly when your own
   sonar is short. Storm pay (+XP in weather) offered and declined.

**Accepted defaults (tunable, not forks):** four states from the mockup — CLEAR / RAIN / SQUALL /
THUNDERHEAD; per-state detect multiplier 1.0 / 0.75 / 0.6 / 0.5; RAIN does NOT ground the bird
(squall+ does); fronts change state only at wave boundaries (the radio announces during the quiet);
a front spanning a boss wave is suppressed to CLEAR for that wave and resumes after.

## The system

- **Schedule:** rolled once at `GameWorld` init on a **dedicated substream**
  (`Rng.new((seed ^ 0x57583137) & 0xFFFFFFFF)` — the C16 director precedent), drawing ZERO from
  `world.rng`. Entries `{start_wave, duration_waves, state}`; escalation = state tier and duration
  grow, gaps shrink, as wave count rises. Same seed ⇒ same weather, regardless of how you fought.
- **Sim surface (small by design):** `world.wx` (current state id + detect_mult) set at
  `Waves._begin_wave` from the schedule. Consumers: `Sonar.gd` radius ×mult (ship + dip),
  radar-acquisition range ×mult, `Turrets` auto-acquire range ×mult (⚠ exact seam names confirmed
  at build against the real bodies), `AirWing.gd` — state ≥ SQUALL forces rtb/pad, no dips, no door
  guns. No new entry in `Sim.step`'s fixed order — weather is per-wave state, not a per-tick system.
- **Render (the approved mockup, ported):** wind-angled screen-space rain streaks + world dimple
  rings + visibility veil + gust curtains; THUNDERHEAD lightning with the mockup's photosensitivity
  caps (flash veil ≤ 0.16 alpha, ≥ 4 s between strikes, bolts pre-jagged so nothing shimmers).
  Strike timing/position is RENDER-side cosmetic rng — never the sim's. `reduced_motion` law:
  streaks/dimples/flash die, static veil stays, strike glow (no flash) remains.
- **Radio:** the MET SECTION joins TF50 traffic — forecast at the lull ("SQUALL LINE, WAVE 6"),
  front arrival, front clearing, bird grounded/airborne calls. Wave plate carries a small state tag.
- **SFX:** rain bed + thunder via `tools/gen_sfx.py` (seeded, byte-identical reruns); thunder
  delayed by strike distance (cosmetic — it rides the render event).
- **Config:** `config/WeatherConfig.gd` + `weather.tres` — the states table (id, detect_mult,
  rain/veil/wind render values from the approved rail, ground_bird flag), schedule knobs
  (first_front_min/max, gap curve, duration curve, boss_clear), reserved band fields (unused v1).
  Registered in `Configs.defaults()`/`load_all()` + the `.duplicate()` line in `Tech.apply()`.
- **Determinism contract:** weather disabled in config ⇒ byte-identical to pre-C17 (zero
  `world.rng` deltas — the schedule substream guarantees it even enabled). Two-world probes stay
  green with weather on.

## Verify

`tests/probe_weather.gd`, wired into `verify.sh`: (1) two-world determinism with weather enabled;
(2) weather-disabled ⇒ byte-identical pre-C17 baseline; (3) same seed ⇒ same schedule, escalation
shape holds (first front in window, gaps shrink, tiers rise); (4) every boss wave reads CLEAR;
(5) detection attenuation observable (a sub undetected at clear-weather radius IS detected closer);
(6) bird grounded during SQUALL+ (state = pad, no dip contacts) and returns after; (7) force-fire
behavior byte-identical in and out of weather.

## Out of scope (named, not drifted into)

The drifting band (follow-up CR) · lightning gameplay of any kind · gunnery dispersion · storm pay ·
a standalone reduce-flashing settings screen (reduced_motion covers v1) · whirlpools (C18, own
interview) · night + thermal layer (queued, own interview).
