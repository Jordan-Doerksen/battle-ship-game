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

**Next:** C3 is unscoped — candidates: wave/spawn director (first real enemies + hull damage),
sonar + subs, depth charges, hardpoint purchase economy. Each needs its own `/spec-feature`
interview first. All five DECISIONS.md open threads: #5 is resolved; #1–#4 remain.

## 3. Tree layout

```
scripts/
  app/            root scene + fixed-step loop plumbing (Main.gd — writes InputState pre-step,
                  plumbs the sim effects queue to the renderer post-step)
  engine/         the deterministic sim
    Sim.gd        step root — fixed order: Movement, Drones, Turrets, Projectiles
    data/         GameWorld truth object, InputState, Configs bundle
    entities/     plain data classes (Drone, Projectile, Mount)
    systems/      static funcs that mutate GameWorld (Movement C1; Drones/Turrets/Projectiles C2)
    util/         Rng, Pool — determinism primitives (Pool feeds projectiles)
  render/         one-way sim → view (FieldRenderer: sea/wake/hull/turrets/drones/fx; patina.gdshader)
  ui/             screens + HUD (HelmGauges.gd — gauges, kills plate, force-fire reticle)
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
