# Earth Defense Force (working title) — Project Handoff

> Read this first. It tells a fresh agent what the game is, how the tree is organized, the hard rules
> that will bite you, and where things stand. Pairs with `DECISIONS.md` (the manifest — locked
> decisions) and `ARCHITECTURE.md` (the map). Keep this file updated as the project moves.

---

## 1. What this is

**Earth Defense Force (working title)** is a deterministic naval wave-survival roguelite. You command a
single battleship, alone against AI-piloted alien swarms attacking from air, sea surface, and
underwater. Tone is 1950s B-movie schlock — propaganda-poster earnestness, played straight-faced.

It is a **sibling project of `fulfillment`**, reusing its proven architecture (deterministic sim, hybrid
render, entity pooling) re-derived fresh rather than copied — `fulfillment` is a reference to *read*,
never to copy (see `DECISIONS.md` D1.1/D1.3). Full narrative/systems brief: `docs/DESIGN-BRIEF.md`.

The reason the process here mirrors fulfillment's is the same one: build **design-first, one
fully-fleshed chunk at a time — mechanics AND visuals — cross-checked against the manifest before the
next chunk begins.** No dead mechanics, no orphan pointers, no dead tags strapped in and left behind.

---

## 2. Current status

**C0 — Heartbeat, C1 — Naval movement, and C2 — Hardpoint hull & gunnery range** are all built
(2026-07-08), each through the full pipeline: owner interview → approved spec → owner-approved
interactive mockup → Godot port verified against it.

C1: `Movement.gd` (system #1), `InputState` one-way input door, `movement.tres`, mockup-matched
sea/hull/wake render + helm gauges. C2: `Drones`/`Turrets`/`Projectiles` behind it in the fixed step
order, the `Configs` bundle, `hardpoint.tres`/`weapons.tres`/`range.tres`, pooled shells, and the
LOOK-LOCKED render — battleship-scale hull with class-distinct traversing turret art, practice
drones, force-fire (hold LMB = all guns on cursor, RMB = main battery), reticle + kills HUD.
`design/*.html` mockups remain the visual references; `tests/probe_{sim,movement,hardpoints}.gd`
gate everything in `verify.sh`. The C2 spec's LOOK-LOCK (owner: "if it doesn't look this good it
doesn't get approved") binds any future render change that touches this chunk.

**C3 — Wave director & first enemies** is BUILT (2026-07-08): seeded budget director (discrete
waves + lulls, costs/unlocks, cluster bearings, beyond-the-edge arrival), swarmer/gunboat/bomber
roster, hull pips + grace, SHIP LOST card + fresh-seed restart, MMB secondary force-fire, radar
scope with fire-control bearing, over-the-horizon main battery with proximity fuse. The C2 practice
range retired with it (Drones/RangeConfig deleted; probes re-targeted). One port fix worth knowing:
turret auto-fire LEADS its target now — no-lead fire couldn't hit orbiting gunboats and waves never
cleared; the fix is in the mockup reference too. `probe_waves` + re-targeted `probe_hardpoints`
gate it all in `verify.sh`.

**Direction change (owner, 2026-07-08 — see the DECISIONS Change Log):** the hardpoint purchase
economy is DEAD. Ships have set hulls/turrets; progression is persistent levels unlocking a tech
tree (movement, turret-size-specific, bullet effects, traverse, and a helicopter branch — function
TBD). The fixed loadout already in the build matches this.

**C4 — Levels & tech tree** is BUILT (2026-07-08): persistent career XP/levels in the FIRST save
file (`user://profile.cfg`, app-layer only), `Tech.apply` deriving each sortie's Configs from
duplicated base resources + unlocked nodes (zero tech = byte-identical C3, probe-gated), the
24-node tree + CLASSIFIED AIR WING on a custom-drawn tree screen, the title hub, lost-card XP
report, four marquee sim features behind default-off flags, muzzle-origin shells (owner's approval
fix), and the DEV TEST KIT (debug builds only, ` to toggle). `probe_tech` (9 checks) gates it in
`verify.sh`; `design/tech-tree.html` stays the visual/loop reference.

**C5 — Sonar, subs & depth charges is BUILT (2026-07-09):** interview → approved spec → approved
mockup (`design/sonar-subs.html` stays the visual reference) → Godot port. The third D1.9 domain:
`sub` roster elite (cost 6, unlock wave 7) torpedoing from standoff with wake-drawing torpedoes;
`Sonar.gd` passive detection + contact latch (`Enemy.detected_until`, D1.10); `DepthCharges.gd`
contact-gated stern volleys — the owner superseded D1.11's blind-backstop clause at interview
(no contact, no ASW; charges stay free/auto/inaccurate), and NO gun can hurt a sub (domain
exclusion, probe-gated). `SonarConfig`/`sonar.tres`, SONAR tech branch (son1–son5, ASDIC LOCK
marquee), `xp_sub` 80, radar sonar ring + sonar-gated diamond blips, ripple tell, DC sink/blast
fx, six-column tree, dev-kit `+SUB`. `probe_sonar` (8 checks incl. zero-tech baseline) gates it
in `verify.sh`.

**C6 — AIR WING is BUILT (2026-07-09):** interview → approved spec → mockup through two owner
gate revisions (weaving escort + speed-coupled throttle; DOOR GUNNER ×2) → Godot port. The stern
pad flies an autonomous, invulnerable ASW wingman: air1 WHIRLYBIRD unlocks it and de-redacts the
seven-node column (`tech.tres` at 36 nodes); `AirWing.gd` (after DepthCharges, inert without
`tech.helo` — zero-tech probe-gated) runs the pad→air→rtb state machine, the escort weave +
throttle (aim point rides the ship and leads with its speed; astern beeline; acceptance contract
is RECOVERY — back ahead of the bow <5s from any transient dip), dipping sonar on the C5 latch
(MAD GEAR: bird latches never decay), contact-centered light drops (detector-first: softens, the
stern racks finish), door gunners (wild short-reach tracers vs air/surface; `gunsplash` water
slaps; the deep draws zero fire). Torpedo launches mark `helo_mark` for its investigate behavior.
Render: rotor/shadow/dip ring/pad rearm arc + radar bird blip. `probe_airwing` (10 checks) gates
it; `probe_tech`'s AIR-WING-locked check superseded (air1 buys, air2 gates). Also this chunk: the
deaf-deep law went PHYSICAL (latent C5 gap — shells/airbursts now skip submerged hulls everywhere).

**C7 — Boss ladder & naming pass is BUILT (2026-07-09):** interview → approved spec → approved
mockup (`design/boss-ladder.html` stays the visual reference) → Godot port. Every 5th wave a
mothership war machine + `escort_frac` budget escort: THE JUGGERNAUT (surface; turret/director
parts, panic-fires when the director dies), THE CANOPY (air — mb16 can't touch it; bays + drone
hive), THE MAW (deep; 20s/8s dive–breach cycle, torpedo fans while down, cowls exposed while up,
every cowl lost extends the breach). `Bosses.gd` after Enemies; parts + phases; soft-gated cores
(×0.25 until parts fall); machines integrate with sonar/racks/bird/turrets/projectiles (turret
`_pick_target` refactored to pseudo-targets; machine strikes respect domain tags physically).
Rewards: per-part XP + lap-scaled bounty + 2-pip hull patch (D1.8 refined, not superseded).
Naming pass: `EnemyDef.rep` GNAT/JACKAL/VULTURE/LAMPREY in the wave-plate newsreel tally,
PRIORITY TARGET plate (core bar + strike-through part pips), oversized radar blips, dev-kit
machine spawn buttons. **Owner tune at this gate (C5 behavior change): the stern racks throw a
K-GUN SPREAD** — stations around the beams + stern (`sonar.dc_ring`), scatter as jitter — the
blind auto racks needed a blanket, not a point. `probe_bosses` (8 checks) gates it;
`probe_waves`'s budget scenario isolates the ladder (`bosses.every_n = 0`).

**C8 — Bug batch is BUILT (2026-07-09):** nine fixes from the first adversarial full-code sweep
(29-agent research pass), all red-green probe-gated — dp5 flak now fuses off war machines, AoE
strikes resolve at the burst point (off-center parts were blast-proof), bay bombs got their spec'd
splash (`BossDef.bomb_splash`), sonar latches extend-never-shorten (MAD GEAR survives ship sonar),
turret cadence matches config exactly (aa20 was 10/s vs configured 12/s — a known ~20% AA tighten),
posthumous XP banks, dev-kit MAX LVL covers the 63-point tree, menus draw over open sea only. The
three boss fixes are parity-ported into `design/boss-ladder.html`. Probes: bosses 11 / sonar 9 /
hardpoints 8 / tech 10.

**C9 — THE LIVING SEA is BUILT (2026-07-09):** the owner approved direction B "HEAVY WEATHER"
at the mockup gate (`design/living-sea.html`, two live-preset directions; gate tunes: column 1.4,
disc 3.4 s, wake 9 s; judged at zoom 0.51 — noted for C10). Render-only: sea shader on Main's
`SeaLayer` (bands + glints, world-anchored), crest flecks/streaks, heave/roll/hull-shadow ride,
churned wake + bow wave, SPLASH COLUMNS with per-battery dye, DC subsurface glow, air-enemy
shadows. Misses now splash (cosmetic-only `Projectiles.gd` appends). `field.tres` gained the sea
tables incl. `reduced_motion` (the law). **`FieldRenderer` split** into `SeaRender`/`ShipRender`/
`HostileRender`/`FxRender` under a slim orchestrator (house 500-line rule). `verify.sh` now
fails on SHADER ERROR too; `ScreenshotC9` proves sea / zoom floor / reduced motion. Spec:
`docs/specs/living-sea.md`. Probes stay byte-identical — the render-only proof.

**C10 — TACTICAL ZOOM is BUILT (2026-07-09):** gate approved as-is (`design/tactical-zoom.html`).
Wheel zoom 0.40–0.85, sorties boot at home 0.51, `H` snaps home; `CameraConfig`/`camera.tres`
(the C1 hardcode is dead — formal CR complete); ship-centered camera retained (cursor-anchor
superseded with rationale, spec §2); stroke compensation through all render helpers (×1 at 0.85 —
LOOK-LOCK intact); 10 px min-size floor on hostiles; sim camera-blind, probes byte-identical.
Spec: `docs/specs/tactical-zoom.md`; `ScreenshotC10` harness.

**CREWED GUNS is BUILT (2026-07-09):** the S mounts are person-manned machine guns — bursts
with rest gaps (10 rounds @ 12/s, 1.5 s re-lay), wild spread, per-round 40–100% reach rolls
stitching the water, air+surface targets (the deep stays deaf). Planes are more dangerous now
by owner directive. `probe_hardpoints` re-targeted (checks 2/6/7); spec:
`docs/specs/crewed-guns.md`; `ScreenshotCG` proof.

**C11 — LONG-RANGE FIRE CONTROL is BUILT (2026-07-10):** gate approved as-is
(`design/fire-control.html`). Forced main-battery shells burst AT the cursor within range (the
C3 bearing rule survives beyond — its fixed-camera premise died with C10); flight-time readout +
MAX RANGE telltale at the reticle; fall-of-shot on the scope (own shells + burst flashes, Main
plumbs the effect batch to HelmGauges too); RANGEKEEPER shipped as ord7 (advisory intercept
ghost, 120u snap; tree now 37 nodes / 65 pts / level 66 = everything). Probes re-targeted
(`probe_tech` totals, `probe_hardpoints` check 5); deaf-deep untouched; no rng. Spec:
`docs/specs/fire-control.md`.

**C12 — READABILITY & FEEL is BUILT (2026-07-10) — THE POLISH ARC IS COMPLETE.** Gate approved
as-is (`design/readability-feel.html`). Sound: 13 baked WAVs (`tools/gen_sfx.py`, seeded) +
`SfxPlayer` on the effect channel (`AudioConfig`/`audio.tres`); klaxon (machine arrival),
waveclear, and the new cosmetic `torpwater` horn all sound. Scope: torpedo dash + wake sparks;
dashed DC arm ring + rack dial. Flow: `P` pause (the war waits, the sea doesn't), key-only lost
card, five once-per-profile drip hints (`Profile.seen_hints`). Render: wounded tells. Spec:
`docs/specs/readability-feel.md`.

**The founding brief is SYSTEMS-COMPLETE and the 2026-07-09 polish directive fully discharged**
(C8 bugs · C9 living sea · C10 tactical zoom · CREWED GUNS · C11 fire control · C12 feel).
Remaining open threads are narrative/naming only: #1 water-mystery payoff, #4 working-title
trademark check. New systems (a win mode? new hulls? D1.12 says one hull until revisited)
start with fresh `/spec-feature` interviews.

## 3. Tree layout

```
scripts/
  app/            root scene + loop plumbing + meta layer (Main.gd — state machine title/tree/game,
                  InputState pre-step, effects plumbing post-step, sortie restarts;
                  Profile.gd — the save file; Tech.gd — config derivation + spend rules)
  engine/         the deterministic sim
    Sim.gd        step root — fixed order: Movement, Waves, Enemies, Bosses, Sonar,
                  DepthCharges, AirWing, Turrets, Projectiles
    data/         GameWorld truth object, InputState, Configs bundle
    entities/     plain data classes (Enemy, Projectile, Mount, Boss)
    systems/      static funcs that mutate GameWorld (Movement C1; Turrets/Projectiles C2;
                  Waves/Enemies/Hull C3; Sonar/DepthCharges C5; AirWing C6; Bosses C7)
    util/         Rng, Pool — determinism primitives (Pool feeds projectiles)
  render/         one-way sim → view (FieldRenderer: sea/wake/hull/turrets/enemies/fx; patina.gdshader)
  ui/             screens + HUD (HelmGauges — gauges/pips/wave plate/radar/reticle/lost card;
                  TitleScreen, TechTreeScreen; DevKit — debug builds only)
config/           typed Resource tunables (.tres)
docs/             SPEC.md, HANDOFF.md (this file), CHANGELOG.md, DESIGN-BRIEF.md
design/           approved HTML mockups (visual spec, mock → approve → port)
tests/            probe_*.gd — verify.sh's runtime checks
```

## 4. Hard rules (read `DECISIONS.md` for full detail)

- Determinism is sacred — all gameplay randomness through `world.rng`.
- Sim never reads render/node state; render never mutates sim.
- Tunables live in `config/*.tres`, never hardcoded.
- No dead mechanics — a system isn't "in" until mechanical + visual + cross-checked.
- Turret/hardpoint art renders **on the hull**, not HUD-only — this inverts fulfillment's D1.5, it's
  intentional (D1.5 here).
- New feature? `/spec-feature` interview → spec → owner approval → implement in a fresh session.

## 5. Verify

`./verify.sh` (full: gdparse sweep → import → boot probe) or `./verify.sh quick` (gdparse only). Run
`quick` after every edit; run the full gate before any push.
