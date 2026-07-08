# Decisions Manifest — Earth Defense Force (working title)
**Started:** 2026-07-08  ·  **Last Updated:** 2026-07-08  ·  **Status:** C2 Hardpoint Hull BUILT (C0 + C1 also 2026-07-08)

> The single source of truth, written *for the next agent* — not a doc anyone maintains by hand.
> Every future agent consults this before an architectural/behavioral change. Never silently rewrite
> a locked decision — supersede it via a Change Request and note the successor.

---

## Core Goal
**Earth Defense Force (working title)** is a deterministic naval wave-survival roguelite — a spinoff
of `fulfillment`, sharing its architecture but not its tone or content. You command a single Earth
Defense Force battleship, alone against AI-piloted alien swarms rising from air, sea surface, and
underwater. Tone is 1950s B-movie schlock — propaganda-poster earnestness, played straight-faced —
a deliberate departure from fulfillment's deadpan corporate-parody voice. Full brief: `docs/DESIGN-BRIEF.md`.

## Non-Negotiable Constraints
(Carried forward from fulfillment as process invariants — these are not game-specific, they are what
keeps a from-scratch build honest.)
- **No dead mechanics.** A system is not "in" until it is fleshed mechanically **and** visually **and**
  cross-checked against this manifest. No half-wired pointers, unused data tables, or orphan tags left
  in the tree.
- **Determinism is sacred.** All *gameplay* randomness goes through `world.rng` (the seeded stream), in
  a stable order. Same seed ⇒ same run. *Cosmetic-only* effects may use Godot's global RNG — never the
  sim's.
- **One-way sim → render.** The simulation never reads node/render state; nodes and the renderer never
  mutate sim state. Rendering can change nothing about the outcome of a run.
- **Tunables live in `config/*.tres`**, never hardcoded. Check the domain's config first; change logic
  only if config can't solve it.
- **Config is split per-system domain, never a monolithic balance file.** Each system gets its own
  small `<Domain>Config.gd` + `.tres` (`SimConfig`/`sim.tres`, `FieldConfig`/`field.tres`, and future
  `MovementConfig`, `HardpointConfig`, `SonarConfig`, …). Tuning one system should mean reading one
  short file, not scrolling a shared config that also carries every other system's numbers — the
  opposite of fulfillment's single ~300-line `BalanceConfig.gd`, adopted here specifically to keep
  tuning-pass context small. Never add a new system's tunables to an existing unrelated config file.
- **Design-first / mockup gate.** Every visual chunk is proven as an HTML mockup in `design/` and
  approved **before** it is ported to Godot. (mock → approve → port)
- **Secrets only in a gitignored `.env`.**
- **Proprietary & commercial.** Source is reference-only; see `LICENSE`.

---

## Chapter 1: Core Architecture

### Decision 1.1: What is this relative to `fulfillment`?
**Chosen Answer:** A **sibling game reusing fulfillment's proven architecture patterns**, re-derived
fresh rather than copy-pasted — same discipline fulfillment itself used relative to its own predecessor
(A.S.S.; see fulfillment D1.3). `fulfillment` is a reference to *read*, never a folder to import
wholesale. Setting, tone, movement model, hull model, and weapon domain system are new; the sim/render
split, determinism model, and pooling patterns are the parts worth keeping.
**Rationale:** Owner design brief (`docs/DESIGN-BRIEF.md` §7) audited fulfillment system-by-system and
split it into a "keep/adapt closely" column and a "rebuild from scratch" column. Re-deriving instead of
copying keeps only what's actually load-bearing and avoids dragging fulfillment-specific cruft (its
elemental system, its arcade flight model, its corporate-parody UI copy) into a tonally different game.
**Date Locked:** 2026-07-08 · **Affects:** the whole tree.
**Change Rule:** If this flips to "hard fork with shared code," re-open this decision and the reuse map
in `docs/DESIGN-BRIEF.md` §7.

### Decision 1.2: Engine / stack.
**Chosen Answer:** **Godot 4.7 / GDScript** — same as fulfillment.
**Rationale:** Fits the design-first process: scenes/nodes are domain-split by construction, `Resource`s
give typed config files, and the deterministic-sim / dumb-renderer split is native.
**Date Locked:** 2026-07-08 · **Affects:** entire architecture, `project.godot`, every script.

### Decision 1.3: Where does the project start from?
**Chosen Answer:** **Greenfield** — a brand-new `project.godot`. Fulfillment is read for structural
patterns (fixed-tick accumulator, seeded `Rng`, `Pool`, `GameWorld` shape), never imported directly.
**Rationale:** Same reasoning as fulfillment's own D1.3 — proven patterns re-derived fresh stay honest
to "no dead mechanics"; a wholesale copy would drag fulfillment's specific systems (elements, arcade
flight, corporate HUD copy) along for the ride.
**Date Locked:** 2026-07-08 · **Affects:** all of `scripts/`.

### Decision 1.4: Determinism model.
**Chosen Answer:** **Seeded & deterministic**, fixed-timestep (60 Hz) sim. `world.rng` is the only
gameplay randomness, backed by Godot's native seeded `RandomNumberGenerator` (PCG32) wrapped in an
`Rng` class with a `calls` draw-counter as a determinism tripwire — identical shape to fulfillment's.
**Rationale:** Buys daily-seed challenges, replays, one-line bug repro, and enforces the sim/render
split.
**Date Locked:** 2026-07-08 · **Affects:** `scripts/engine/` (all sim), `Rng`, `Sim`, `GameWorld`.
**Change Rule:** Any new gameplay randomness MUST draw from `world.rng`. Dropping determinism is a
large rewrite — file a Change Request first.

### Decision 1.5: Render architecture.
**Chosen Answer:** **Hybrid — sim owns truth.** Deterministic sim holds all gameplay state; render with
real Godot nodes/scenes for the discrete "stars" (player ship, HUD) and batched drawing for high-count
swarms once combat lands. Turret geometry renders **ON the hull** — the opposite of fulfillment's D1.5,
which locks weapon art to the HUD rack only. This game's whole point is a visible, purchasable hardpoint
layout, so the hull itself must carry that art.
**Rationale:** Direct requirement from the design brief §5 (hardpoints are a hull identity, not an
abstract bay count) and §7 (explicitly listed as a "rebuild from scratch" item, inverted from fulfillment).
**Date Locked:** 2026-07-08 · **Affects:** `scripts/render/`, future hull/hardpoint rendering.

### Decision 1.6: Naval movement.
**Chosen Answer:** **New physics-based movement** — real momentum/inertia, wide turning radius, weight.
Fulfillment's `Flight.gd` (arcade boost-dash, free 2D flight) is explicitly **not** a base; it may only
be mined for structural patterns (fixed-tick integration, camera-follow).
**Rationale:** Design brief §3 — piloting should feel like a battleship, not a fighter. Not yet designed
in detail; the concrete movement model (acceleration curves, turn rate, drift) is a future
`/spec-feature` interview, not decided here.
**Date Locked:** 2026-07-08 (deferral, not the movement spec itself) · **Affects:** future
`scripts/engine/systems/Movement.gd` (name TBD).
**Change Rule:** Do not implement movement mechanics without a dedicated spec pass first.
**Resolved 2026-07-08:** the deferral is discharged. The concrete model is locked by
`docs/specs/naval-movement.md` (owner-approved spec + mockup gate) and built as
`scripts/engine/systems/Movement.gd` + `config/movement.tres`: held-key throttle with
brake-through-to-astern, speed-coupled turn authority with a standstill floor, anisotropic drag
(long along-keel coast, decaying lateral slip), heading-drives-velocity. See Change Log.

### Decision 1.7: Hardpoints fire independent of hull facing.
**Chosen Answer:** **360° auto-turrets.** Hull facing is purely cosmetic + economic identity (where a
mount visually sits, what it costs) — never a tactical firing-arc constraint. A hardpoint engages
anything in range regardless of which way the hull points.
**Rationale:** Keeps piloting a maneuvering/positioning decision for *domain coverage and sonar range*,
not for "bringing guns to bear" — deliberate design intent from the brief §3, not an oversight.
**Date Locked:** 2026-07-08 · **Affects:** future targeting/turret system (adapts fulfillment's
`Turrets.gd` CLOSE/FAR/STRONG model — see brief §7).
**Refined 2026-07-08 (C2, not a reversal):** turrets still engage 360° regardless of hull facing, but
slew at per-weapon **traverse rates** (owner decision, hardpoint spec #2) — positioning now decides
*which guns bear soonest*, never *whether* they can bear. A hold-only force-fire override (LMB all
guns / RMB main battery) rides on top; see `docs/specs/hardpoint-hull.md`.

### Decision 1.8: Hull health model.
**Chosen Answer:** **Single hull health pool**, pip-style (discrete hits, like fulfillment's hull pips).
No per-hardpoint destruction/knockout layer — hardpoints are an offense/loadout axis only, never a
targetable damage layer.
**Rationale:** Brief §3. Keeps hardpoint design (§5) about loadout variety, not survivability math.
**Date Locked:** 2026-07-08 · **Affects:** future `Hull.gd` (adapted from fulfillment's hull-pip system).

### Decision 1.9: Domain-tag axis replaces elements.
**Chosen Answer:** Every weapon is tagged with the domain(s) it can engage — **air / surface / sub**.
Some weapons are dual-domain, some single-domain. This is a **targeting-capability tag**, not a
damage-type/resistance system — it replaces fulfillment's Blaze/Frost/Shock/Void elemental axis
entirely for this game. Whether a *separate* elemental/status layer sits on top of domain-tagging is
undecided and out of scope for MVP.
**Date Locked:** 2026-07-08 · **Affects:** future weapon catalog + targeting AI.

### Decision 1.10: Sonar is passive-only for MVP.
**Chosen Answer:** Subs are invisible on radar by default. A Sonar system, upgraded through the same
economy as hardpoints, is a **passive detection radius only** — no active "ping" ability for MVP.
Direct extension of fulfillment's `RadarView.gd` minimap, gated by detection radius.
**Date Locked:** 2026-07-08 · **Affects:** future Sonar system + `RadarView` extension.

### Decision 1.11: Depth charges are a free, always-on failsafe.
**Chosen Answer:** Depth charges are a **non-purchased, always-on** ship system (parallel to
fulfillment's fixed "prow" gun that's never drafted/upgraded) that auto-fires at subs within a tight
close range, with deliberately bad accuracy. Creates the intended tension: invest in sonar to fight subs
at range with real guns, or rely on the inaccurate backstop.
**Date Locked:** 2026-07-08 · **Affects:** future depth-charge system.

### Decision 1.12: Scope lock — one hull only.
**Chosen Answer:** **One hull shape**, no hull-class variety, until the rest of the game is built out.
All balance work targets that single hull. Deliberately sidesteps fulfillment's 3-hull-class system.
**Date Locked:** 2026-07-08 · **Affects:** all hull/balance work until explicitly revisited.
**Change Rule:** Hull variety is a scope expansion — requires an explicit Change Request, not a drift.

---

## Not Yet Decided (Open Threads — do not silently resolve)
Carried forward verbatim from `docs/DESIGN-BRIEF.md`. Each requires its own decision pass before it's
treated as locked:

1. **Water-mystery payoff** — why the aliens want Earth's water. Narrative/mission framing question;
   doesn't block systems work.
2. **Boss ladder & enemy roster naming** — needs a B-movie-appropriate replacement for fulfillment's
   corporate title-ladder (mothership hierarchy, drone type names). Not yet designed.
3. **Helipad function** — part of the hull's visual identity (replaces a hangar/fighter bay), but
   whether it does anything mechanically (support ability? cosmetic only? `Fighters.gd` analog?) is
   undefined.
4. **Working title / trademark check** — "Earth Defense Force" collides with an existing real game
   franchise (Sandlot/D3 Publisher). Revisit before the name goes into a public repo/store listing.
5. ~~**Hardpoint force-fire override & turret tracking**~~ — **RESOLVED 2026-07-08** by the C2
   interview + spec (`docs/specs/hardpoint-hull.md`): finite per-weapon traverse, per-weapon
   CLOSE/STRONG policies, hold-only force-fire (LMB all mounts domain-overridden / RMB large only).
   Built in C2; D1.7 carries the refinement note.

---

## Build Timeline
- **C0 — Heartbeat (built 2026-07-08).** Greenfield skeleton: fixed-timestep deterministic loop, seeded
  RNG, `GameWorld` truth object, minimal render harness proving the loop is alive on screen. No gameplay
  systems. Mirrors fulfillment's own C0.
- **C1 — Naval movement (built 2026-07-08).** Spec'd, mockup-gated (`design/naval-movement.html`,
  owner-approved), and ported: `Movement.gd` system #1 in `Sim.step`, `InputState` one-way input door,
  `movement.tres` tunables, mockup-matched sea/hull/wake render + helm gauge bank, `probe_movement`
  acceptance gate. Spec: `docs/specs/naval-movement.md`.
- **C2 — Hardpoint hull & gunnery range (built 2026-07-08).** Interviewed, spec'd, mockup-gated
  through three owner revisions (battleship-scale hull ×2.4, 4S/4M/2L, class-distinct turret art,
  blooming AA), LOOK-LOCKED, and ported: `Drones`/`Turrets`/`Projectiles` systems, `Configs` bundle,
  three new per-system configs, pooled shells, mockup-matched render/HUD, `probe_hardpoints` gate.
  Spec: `docs/specs/hardpoint-hull.md`.
- **C3+ — not yet scoped.** Wave/spawn director (first real enemies), sonar + subs, depth charges,
  hardpoint purchase economy, hull damage — each needs its own `/spec-feature` interview before
  implementation, per this repo's `CLAUDE.md`.

---

## Change Log
- **2026-07-08 — C2 Hardpoint Hull built; open thread #5 resolved; D1.7 refined.** The approved C2
  spec (three owner gate revisions, LOOK-LOCK condition) ported to Godot: `Drones.gd`/`Turrets.gd`/
  `Projectiles.gd` in `Sim.step`'s fixed order behind `Movement`, a `Configs` bundle so the step
  signature stays flat, per-system configs `hardpoint.tres`/`weapons.tres` (WeaponDef sub-resources)/
  `range.tres`, `Pool`'s first consumer (shells), sim→render effects queue plumbed through Main,
  battleship-scale hull + class-distinct turret art with recoil in `FieldRenderer`, force-fire
  reticle/batteries line/kills plate in `HelmGauges`, mouse input map. `probe_hardpoints` (8 checks
  mirroring the mockup harness) added to the gate; `probe_movement` now isolates with a drone-free
  range so its zero-RNG tripwire stays exact. Look-lock verified by side-by-side Xvfb screenshots
  against mockup rev 3. D1.7 refined (traverse rates), open thread #5 closed, D1.9 domain tags live.
- **2026-07-08 — C1 Naval Movement built; D1.6 deferral resolved; D1.2 re-affirmed.** Owner accepted
  the engine review ("keep Godot; HTML stays the design surface") — D1.2 stands. The approved C1 spec
  ported to Godot: `Movement.gd` (system #1, pure arithmetic, zero RNG draws), `InputState.gd`,
  `MovementConfig`/`movement.tres`, mockup-matched `FieldRenderer` (chart grid, foam flecks, wake,
  hull silhouette — replaces the C0 placeholder starfield, so `FieldConfig` fields changed with it),
  patina shader, `HelmGauges` HUD, input map, `probe_movement` verify step. D1.6's "do not implement
  without a spec pass" deferral is resolved by that spec (noted inline at D1.6). Godot probe numbers
  match the JS mockup validation exactly (4.55s to 95%, 67% coast, 2.25s stop, cap 0.00% off,
  floor 0.1375 rad/s, slip 66.1 u/s).
- **2026-07-08 — C1 mockup approved at the gate.** `design/naval-movement.html` owner-approved for
  feel at the spec-default tunables; the Godot port is unblocked, with a 1:1 look-match requirement
  recorded in the spec. Owner requested a review of D1.2 (keep Godot vs ship the HTML/JS mockup
  stack) — review delivered in-session recommending Godot stands; D1.2 remains locked unless the
  owner supersedes it. New open thread #5 (hardpoint force-fire override + turret tracking) captured
  from the same feedback.
- **2026-07-08 — Brief adopted as founding manifest.** Owner-approved design brief
  (`docs/DESIGN-BRIEF.md`, captured 2026-07-08) translated into this manifest's Chapter 1. C0 Heartbeat
  skeleton built in the same session. No prior decisions to supersede — this is the repo's founding
  commit.
