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

**C0 — Heartbeat** and **C1 — Naval movement** are built. C1 went through the full pipeline
(spec interview → owner-approved spec → owner-approved interactive mockup → Godot port) in one day:
`Movement.gd` is system #1 in `Sim.step`, `InputState` is the one-way input door, tunables live in
`config/movement.tres`, and the render/HUD (sea chart grid, wake, hull silhouette, helm gauge bank,
patina shader) is a 1:1 port of `design/naval-movement.html` — that mockup remains the C1 visual
reference. `tests/probe_movement.gd` gates the spec's acceptance checks in `verify.sh`.

**Next:** C2 is unscoped — hardpoint hull, weapon catalog, sonar, depth charges, wave director each
need their own `/spec-feature` interview first. `DECISIONS.md` open thread #5 (owner, 2026-07-08)
already seeds the hardpoints interview: turrets auto-track/auto-fire (D1.7) **plus** a mouse-button
force-fire-at-cursor override, with turret traverse/tracking called out as a design risk.

## 3. Tree layout

```
scripts/
  app/            root scene + fixed-step loop plumbing (Main.gd — also writes InputState pre-step)
  engine/         the deterministic sim
    Sim.gd        step root — calls systems in fixed order (Movement first)
    data/         GameWorld truth object, InputState, tunable tables
    entities/     plain pooled data classes (empty until combat chunks)
    systems/      static funcs that mutate GameWorld (Movement.gd — C1)
    util/         Rng, Pool — determinism primitives
  render/         one-way sim → view (FieldRenderer: sea/wake/hull; patina.gdshader)
  ui/             screens + HUD (HelmGauges.gd — the C1 gauge bank)
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
