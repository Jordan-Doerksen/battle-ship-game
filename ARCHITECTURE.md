# Architecture Overview: Earth Defense Force (working title)

> The one-page map — short enough to read before touching anything. Any agent should be able to change
> one thing after reading only this + the one domain it points to. Pairs with `DECISIONS.md`.

## System at a Glance
A deterministic, fixed-timestep (60 Hz) **naval wave-survival roguelite** in Godot 4.7. The **simulation
owns all truth** as pooled data seeded by one RNG stream; the **renderer only reads it** (one-way, never
writes back). Unlike fulfillment, turret/hardpoint art renders **on the hull itself** (DECISIONS D1.5) —
the hull's visible hardpoint layout is the point of the game. Currently only the C0 heartbeat exists: no
gameplay systems are wired yet.

## Core Flow
```text
Input (keys / mouse)  →  InputState
        ↓
Sim.step(world, dt)                         ← fixed 60 Hz, ONLY randomness = world.rng
   ├─ (C0: no systems yet)
   ├─ …future: naval movement                  (systems are static funcs that mutate `world`)
   ├─ …future: hardpoints / targeting / domain-tagged combat
   ├─ …future: sonar detection + depth charges
   ├─ …future: spawn / wave director
   └─ …future: progression, hardpoint economy
        ↓
GameWorld  ← the single mutable source of truth (pools arrive as systems land)
        ↓  (one-way read, changes nothing)
Render:  FieldRenderer → placeholder hull + starfield (C0)   +   node scenes → future HUD
        ↓
Screen
```

## Core Domains
Each domain pairs logic with typed **`Resource` config** (`.tres`) — tunables live in config, never
hardcoded (DECISIONS Non-Negotiable Constraints).

| Domain | Purpose | Entry Point | Config | Notes |
|--------|---------|-------------|--------|-------|
| app | root scene + loop plumbing (fixed-step accumulator, wiring) | `scripts/app/Main.gd` + `scenes/Main.tscn` | — | thin; owns nothing gameplay |
| engine (sim) | the deterministic step root | `scripts/engine/Sim.gd` | `config/sim.tres` (clock only) | fixed-step; C0 has no gameplay systems to call yet |
| engine/data | tunable tables + the world truth object | `scripts/engine/data/` | `config/*.tres` (one small file per system — see DECISIONS Non-Negotiable Constraints) | `GameWorld` lands here |
| engine/systems | sim systems — static funcs that mutate `GameWorld` | `scripts/engine/systems/` | reads config | empty until C1 (naval movement is first) |
| engine/entities | plain pooled data classes | `scripts/engine/entities/` | — | data only, no engine coupling |
| engine/util | determinism primitives | `scripts/engine/util/` | — | `Rng`, `Pool` |
| render | draw the world (hybrid), read-only | `scripts/render/FieldRenderer.gd` | — | one-way sim → view; hull/hardpoint art lives here (not HUD-only, per D1.5) |
| ui | screens + HUD | `scripts/ui/` | — | not built yet |
| config | typed tunables | `config/*.tres` | — | `Resource` subclasses |
| design | approved HTML mockups = the visual spec | `design/` | — | mock → approve → port |

## Reuse vs. Rebuild (from `docs/DESIGN-BRIEF.md` §7)
| Keep / adapt closely from fulfillment | Rebuild from scratch for this game |
|---|---|
| Sim/render one-way split, `GameWorld`-as-truth, entity pooling, static-system-per-tick | Naval movement/physics — fulfillment's `Flight.gd` is arcade-only, wrong fit |
| `Turrets.gd` targeting/firing model (CLOSE/FAR/STRONG, ammo/reload) | Hull hardpoint **position** data model — no analog in fulfillment (one flat polygon) |
| `RadarView.gd` minimap (extend for sonar-gated sub visibility) | Turret geometry rendered ON the hull, not HUD-only (inverts fulfillment D1.5) |
| Depot rider-buy/refund shop pattern, as a template for hardpoint-purchase UI | Hardpoint-purchase-by-position shop UI itself |
| Archetype/boss escalation structure — reskinnable | Fresh weapon catalog (6-8 types, domain-tagged) |
| Discrete hull-pip health display | Domain-tagging system (air/surface/sub) — new axis |
| | Sonar detection-radius + depth-charge auto-defense — no analog in fulfillment |

## How to Modify a Domain
1. Read `DECISIONS.md` — is this locked? Does a Non-Negotiable Constraint apply?
2. Read this map; open ONLY the owning domain folder.
3. Check that domain's `.tres` config first — change a tweakable there, not in logic.
4. Change logic only if config can't solve it (one responsibility per file).
5. `gdparse` every changed `.gd`; if it's visual, run the mockup gate.
6. If it touches design / behavior / config / determinism → file a Change Request + update
   `DECISIONS.md`'s Change Log.
