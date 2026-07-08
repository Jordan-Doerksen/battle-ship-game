# Architecture Overview: Earth Defense Force (working title)

> The one-page map — short enough to read before touching anything. Any agent should be able to change
> one thing after reading only this + the one domain it points to. Pairs with `DECISIONS.md`.

## System at a Glance
A deterministic, fixed-timestep (60 Hz) **naval wave-survival roguelite** in Godot 4.7. The **simulation
owns all truth** as pooled data seeded by one RNG stream; the **renderer only reads it** (one-way, never
writes back). Unlike fulfillment, turret/hardpoint art renders **on the hull itself** (DECISIONS D1.5) —
the hull's visible hardpoint layout is the point of the game. Built so far: C0 heartbeat, C1 naval
movement (`docs/specs/naval-movement.md`), C2 hardpoint hull (traversing auto-turrets + force-fire,
LOOK-LOCKED — `docs/specs/hardpoint-hull.md`), C3 wave director (budget-director waves, three enemy
types, hull pips, radar fire-control, run loop — `docs/specs/wave-director.md`). It plays.

## Core Flow
```text
Input (keys / mouse→world-space)  →  InputState   (Main writes it pre-step; sim only reads it)
        ↓
Sim.step(world, dt, cfgs: Configs)          ← fixed 60 Hz, ONLY randomness = world.rng
   ├─ Movement.step (C1)                       (systems are static funcs that mutate `world`;
   ├─ Waves.step (C3)                           the whole block freezes when the run is over)
   ├─ Enemies.step (C3)                        pursuit/orbit + gunboat fire; Hull.gd takes damage
   ├─ Turrets.step (C2)                        policy targeting + lead, traverse, bloom, force-fire
   └─ Projectiles.step (C2/C3)                 pooled shells both ways, splash + proximity fuse
   …future: Sonar + DepthCharges (C4?), hardpoint economy, boss ladder
        ↓
GameWorld  ← the single mutable source of truth (+ effects queue: sim appends, Main plumbs to render)
        ↓  (one-way read, changes nothing)
Render:  FieldRenderer → sea + wake + hull + turret art (D1.5) + enemies/shells/fx
     +   HelmGauges HUD → pips, gauges, wave plate, radar scope, reticle, SHIP LOST card
        ↓
Screen (patina shader overlay — pure cosmetics)
```

## Core Domains
Each domain pairs logic with typed **`Resource` config** (`.tres`) — tunables live in config, never
hardcoded (DECISIONS Non-Negotiable Constraints).

| Domain | Purpose | Entry Point | Config | Notes |
|--------|---------|-------------|--------|-------|
| app | root scene + loop plumbing (fixed-step accumulator, wiring) | `scripts/app/Main.gd` + `scenes/Main.tscn` | — | thin; owns nothing gameplay |
| engine (sim) | the deterministic step root | `scripts/engine/Sim.gd` | `config/sim.tres` (clock only) | fixed-step; calls systems in a locked order (Movement first) |
| engine/data | the world truth object + input snapshot + config bundle | `scripts/engine/data/` | `config/*.tres` (one small file per system — see DECISIONS Non-Negotiable Constraints) | `GameWorld`, `InputState`, `Configs` |
| engine/systems | sim systems — static funcs that mutate `GameWorld` | `scripts/engine/systems/` | each reads its own config | `Movement` (C1); `Turrets`/`Projectiles` (C2: `hardpoint`/`weapons.tres`); `Waves`/`Enemies`/`Hull` (C3: `waves`/`enemies.tres`) |
| engine/entities | plain pooled data classes | `scripts/engine/entities/` | — | `Enemy`, `Projectile` (pooled), `Mount` — data only, no engine coupling |
| engine/util | determinism primitives | `scripts/engine/util/` | — | `Rng`, `Pool` (feeds projectiles) |
| render | draw the world (hybrid), read-only | `scripts/render/FieldRenderer.gd` | `config/field.tres` (sea/wake cosmetics) | one-way sim → view; turret art ON the hull per D1.5, LOOK-LOCKED to mockup rev 3; `patina.gdshader` |
| ui | screens + HUD | `scripts/ui/HelmGauges.gd` | — | gauges, hull pips, wave plate, radar scope (fire-control), reticle, SHIP LOST card |
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
