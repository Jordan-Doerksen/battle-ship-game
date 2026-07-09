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

**C6 — AIR WING (helicopter) is MID-GATE (2026-07-09):** interviewed + spec approved
(`docs/specs/air-wing.md`), interactive mockup BUILT (`design/air-wing.html` — autonomous ASW
wingman: air1 WHIRLYBIRD unlocks the bird + de-redacts the column, contact-led picket, dipping
sonar writing the C5 latch, light contact-centered drops on a 9s cadence [detector-first: it
softens, the stern racks finish], ~45s/10s fuel loop, MAD GEAR marquee; scratchpad harness 8/8
incl. zero-tech byte-parity vs the shipped C5 sim) and published for owner feel-approval. NOT yet
approved, NOT yet ported. Three tunables were adjusted at mockup build and noted in the spec table
(dc_cooldown 6→9, picket_dist 450→360, orbit_radius 180→150). On approval: record it, then port
(AirWingConfig + AirWing.gd after DepthCharges + helo render/radar + real air1–5 nodes in
tech.tres + probe_airwing + resolve open thread #3 in DECISIONS).

**After C6:** the boss ladder + naming pass (open thread #2). Needs its own `/spec-feature`
interview first.

## 3. Tree layout

```
scripts/
  app/            root scene + loop plumbing + meta layer (Main.gd — state machine title/tree/game,
                  InputState pre-step, effects plumbing post-step, sortie restarts;
                  Profile.gd — the save file; Tech.gd — config derivation + spend rules)
  engine/         the deterministic sim
    Sim.gd        step root — fixed order: Movement, Waves, Enemies, Sonar, DepthCharges,
                  Turrets, Projectiles
    data/         GameWorld truth object, InputState, Configs bundle
    entities/     plain data classes (Enemy, Projectile, Mount)
    systems/      static funcs that mutate GameWorld (Movement C1; Turrets/Projectiles C2;
                  Waves/Enemies/Hull C3; Sonar/DepthCharges C5)
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
