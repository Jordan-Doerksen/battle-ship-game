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

**C0 — Heartbeat** is built: a fixed-timestep deterministic loop, seeded RNG, the `GameWorld` truth
object, and a minimal render harness proving the loop is alive. No gameplay systems are wired yet.

**C1 — Naval movement** is mid-gate: the spec (`docs/specs/naval-movement.md`) is owner-APPROVED, and
the interactive mockup `design/naval-movement.html` is built (keyboard-driven, implements the spec's
exact model + tunables; spec acceptance checks 1–6 validated numerically against it). Per the mockup
gate, the owner must approve the mockup's *feel* hands-on before the Godot port. No Godot code for C1
exists yet. See `DECISIONS.md`'s Build Timeline for what's next.

## 3. Tree layout

```
scripts/
  app/            root scene + fixed-step loop plumbing (Main.gd)
  engine/         the deterministic sim
    Sim.gd        step root — calls systems in order (empty for now)
    data/         GameWorld truth object + tunable tables
    entities/     plain pooled data classes
    systems/      static funcs that mutate GameWorld (empty until C1)
    util/         Rng, Pool — determinism primitives
  render/         one-way sim → view (FieldRenderer)
  ui/             screens + HUD (not built yet)
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
