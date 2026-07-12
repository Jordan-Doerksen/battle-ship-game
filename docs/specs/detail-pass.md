# C19 — THE DETAIL PASS (spec)

> The third piece of the TEMPEST arc. Owner interview 2026-07-12 approved THREE packs from the
> ranked 20-item research catalog (`docs/research/naval-systems.md` §4); **mockup gate:
> `design/the-tempest.html` APPROVED AS-IS 2026-07-12** — eight of the items are demoed there as
> individual toggles and those looks are the reference. HUD grit (phosphor persistence, needle
> jitter) was offered and DECLINED. Entirely render/audio-layer: **zero sim behavior changes** —
> the two-world probes must stay byte-identical, which IS this chunk's acceptance gate.
> Implementation in a FRESH session per house law.

## Identity

The "one more 1%" layer: the battle leaves marks on the world, the ship reads crewed, the strait
reads inhabited. The research's governing insight — **persistence** (kill-marks outlive the kill)
and **reactivity** (ambient life responds to you) buy more aliveness than any particle count.

## The three approved packs

**1 · SHIP LIVELINESS** (your own hull, every second)
- **Funnel smoke** — throttle-responsive wisps off the stack, streaming downwind (reads the C17
  wind table when a front is up; render-only reads of sim throttle/speed).
- **Ejected casings** — brass glints tumble off M mounts per shot, fade ~1 s (off the existing
  `muzzle` effect).
- **Signal lamp** — the bridge Aldis blinks morse-ish triplets on a lazy cosmetic clock.
- **Bow spray** — spray flecks over the stem at speed in weather (speed + C17 state gated).
- **Heel spray** — extra leeward spray sheet during hard rudder at speed (reads turn rate).

**2 · BATTLE AFTERMATH** (persistence — the fight marks the sea)
- **Oil slick + debris field** — where a surface enemy sank: dark lobed slick with a faint sheen
  rim, 3–5 bobbing planks/crates drifting apart, fading ~60–90 s (off the existing `death` effect;
  slick suppresses glints inside its bound — one cheap mask in the glint pass).
- **Cordite haze** — sustained fire wreathes the mounts in slow-drifting grey that speed/wind
  clears (off `muzzle` effects; density capped for readability).
- **Sub-death bubble column** — a sunk sub site boils briefly, then a small upwelling ring
  (off the sub-layer `death` effect).

**3 · AMBIENT WORLD** (the strait is a place)
- **Gulls that scatter** — a pair circles the stern; gunfire within ~200 u scatters them squawking
  (reacts to `muzzle`/`gunflash` effects); they leave entirely in C17 rain+.
- **Drifting flotsam** — sparse crates/planks on a slow current (doubles as a free speed/heading
  parallax cue; tiled like the C1 fleck field).
- **Channel buoys** — 1–2 bobbing markers seeded off the C15 shoals, slow lamp blink (extends the
  existing islet nav-light language; seeded placement, cosmetic).
- **Cloud shadows** — large soft patches sliding across the sea; one extra band layer in
  `sea.gdshader` (the cheapest whole-screen liveliness in the catalog).
- *(Optional, owner may cut at the gate check: the distant neutral tanker silhouette crossing
  between waves — it IS the Strait of Hormuz, but it must never blip the scope.)*

## Build notes

- **Plumbing:** everything rides the existing one-way effect batch (`muzzle`/`gunflash`/`death`)
  or pure render clocks. NO new sim events needed; the deck-scorch item (needs a hit-location
  event) was NOT approved and stays out.
- **Ownership:** new render-domain helper `AmbienceRender.gd` (the C9 split family) for packs 2–3;
  pack 1 extends `ShipRender` (it draws on/around the hull). Tunables in a new small
  `AmbienceConfig`/`ambience.tres` (counts, lifetimes, drift speeds, scatter radius) — the
  one-config-per-system rule; `reduced_motion` freezes bobbing/circling and keeps static marks.
- **Readability law (from the research):** the detail layer must never out-contrast gameplay marks
  — torpedo wakes, telegraphs, and blips always win. Alpha ceilings live in the config.
- **Determinism gate:** this chunk's probe story is the C9 one — no new probe; every existing
  suite must pass byte-identical (render-only proof). A `ScreenshotC19` harness proves the looks.
- **Audio (small):** gull cry + a soft slick-bubble plop via `gen_sfx.py` if they earn their keep
  at the gate check; skippable without a CR.

## Out of scope (named)

HUD grit (declined at interview) · deck scorch (needs a sim event) · lifeboats (tonally heavy —
future owner call) · crew silhouettes / fish / jellyfish (rejected in research on tone/legibility).
