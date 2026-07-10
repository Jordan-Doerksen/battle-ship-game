# Architecture Overview: Earth Defense Force (working title)

> The one-page map — short enough to read before touching anything. Any agent should be able to change
> one thing after reading only this + the one domain it points to. Pairs with `DECISIONS.md`.

## System at a Glance
A deterministic, fixed-timestep (60 Hz) **naval wave-survival roguelite** in Godot 4.7. The **simulation
owns all truth** as pooled data seeded by one RNG stream; the **renderer only reads it** (one-way, never
writes back). Unlike fulfillment, turret/hardpoint art renders **on the hull itself** (DECISIONS D1.5) —
the hull's visible turret layout is the ship's identity. Built so far: C0 heartbeat, C1 naval
movement, C2 hardpoint hull (LOOK-LOCKED), C3 wave director (waves, enemies, hull pips, radar,
run loop), C4 levels & tech tree (persistent career, config-derivation upgrades, marquee effects,
title/tree screens — `docs/specs/tech-tree.md`), C5 sonar/subs/depth charges (the third D1.9
domain: torpedoes, passive detection, contact-gated ASW — `docs/specs/sonar-subs.md`), C6 AIR WING
(the autonomous ASW helicopter wingman — `docs/specs/air-wing.md`), C7 boss ladder & naming pass
(mothership war machines + reporting names — `docs/specs/boss-ladder.md`). The founding brief is
systems-complete: three domains, a career, a wingman, and a ladder of named machines.

## Core Flow
```text
Title / Tech Tree (Main's state machine)    ← Profile (user://profile.cfg: XP, levels, unlocks)
        ↓  BEGIN SORTIE: cfgs = Tech.apply(base .tres values, unlocked)   ← the meta layer only
        ↓                                                                    ever DERIVES config
Input (keys / mouse→world-space)  →  InputState   (Main writes it pre-step; sim only reads it)
        ↓
Sim.step(world, dt, cfgs: Configs)          ← fixed 60 Hz, ONLY randomness = world.rng
   ├─ Movement.step (C1)                       (systems are static funcs that mutate `world`;
   ├─ Waves.step (C3→C16)                       formation/echelon director on a (seed,wave) substream
   ├─ Enemies.step (C3/C5)                     pursuit/orbit + gunboat shells / sub torpedoes
   ├─ Bosses.step (C7)                         the war machine: parts, phases, breach cycle
   ├─ Sonar.step (C5)                          passive detection radius + contact latch (D1.10)
   ├─ DepthCharges.step (C5)                   contact-gated K-gun spreads (D1.11 as refined)
   ├─ AirWing.step (C6)                        the ASW wingman — inert without tech.helo
   ├─ Turrets.step (C2)                        policy targeting + lead, traverse, bloom, force-fire
   └─ Projectiles.step (C2/C3/C5/C6/C7)        pooled shells/torpedoes/charges/tracers, fuses
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
| app | root scene, loop plumbing, state machine, meta layer | `scripts/app/Main.gd` + `scenes/Main.tscn` | `config/camera.tres` (C10 tactical zoom — wheel 0.40–0.85, home 0.51; sim is camera-blind) | `Profile` (save file), `Tech` (config derivation + spend rules); owns no gameplay; feeds the sea shader + camera one-way |
| engine (sim) | the deterministic step root | `scripts/engine/Sim.gd` | `config/sim.tres` (clock only) | fixed-step; calls systems in a locked order (Movement first) |
| engine/data | the world truth object + input snapshot + config bundle | `scripts/engine/data/` | `config/*.tres` (one small file per system — see DECISIONS Non-Negotiable Constraints) | `GameWorld`, `InputState`, `Configs` |
| engine/systems | sim systems — static funcs that mutate `GameWorld` | `scripts/engine/systems/` | each reads its own config | `Movement` (C1); `Turrets`/`Projectiles` (C2: `hardpoint`/`weapons.tres`); `Waves`/`Enemies`/`Hull` (C3: `waves`/`enemies.tres`); `Sonar`/`DepthCharges` (C5: `sonar.tres`); `AirWing` (C6: `airwing.tres`); `Bosses` (C7: `bosses.tres`) |
| engine/entities | plain pooled data classes | `scripts/engine/entities/` | — | `Enemy`, `Projectile` (pooled), `Mount` — data only, no engine coupling |
| engine/util | determinism primitives | `scripts/engine/util/` | — | `Rng`, `Pool` (feeds projectiles) |
| render | draw the world (hybrid), read-only | `scripts/render/FieldRenderer.gd` (orchestrator) → `SeaRender`/`ShipRender`/`HostileRender`/`FxRender` | `config/field.tres` (sea/ride/splash/wake cosmetics incl. `reduced_motion`) | one-way sim → view; turret art ON the hull per D1.5 (C2 art LOOK-LOCKED); C9 living sea: `sea.gdshader` on Main's `SeaLayer` (world-anchored, uniforms fed by Main), splash columns, render-only ride; `patina.gdshader` |
| ui | screens + HUD | `scripts/ui/` | — | `HelmGauges` (gauges/pips/wave plate/radar/reticle/lost card), `TitleScreen`, `TechTreeScreen`, `DevKit` (debug builds only) |
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
