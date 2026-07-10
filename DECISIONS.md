# Decisions Manifest — Earth Defense Force (working title)
**Started:** 2026-07-08  ·  **Last Updated:** 2026-07-09  ·  **Status:** C7 BOSS LADDER & NAMING BUILT — the founding brief is systems-complete (C0–C6 also built)

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
**Built 2026-07-09 (C5, as specced):** `Sonar.gd` (passive radius + contact-hold latch on
`Enemy.detected_until`), radar-gated diamond blips + soft sonar ring on the scope, and the SONAR
tech branch — "the same economy" now means the tech tree per the C4 Change Request. An undetected
sub near the ship shows a render-only ripple tell (cosmetic, not a detection channel). See
`docs/specs/sonar-subs.md`.

### Decision 1.11: Depth charges are a free, always-on failsafe.
**Chosen Answer:** Depth charges are a **non-purchased, always-on** ship system (parallel to
fulfillment's fixed "prow" gun that's never drafted/upgraded) that auto-fires at subs within a tight
close range, with deliberately bad accuracy. Creates the intended tension: invest in sonar to fight subs
at range with real guns, or rely on the inaccurate backstop.
**Date Locked:** 2026-07-08 · **Affects:** future depth-charge system.
**Superseded in part 2026-07-08 (owner, C5 interview; built 2026-07-09):** charges arm **only on a
live sonar CONTACT** — the "backstop for whatever sonar misses" clause and the "fight subs at range
with real guns" framing are dead (no gun can hurt a sub; depth charges are the ONLY sub killer, and
without a contact they never roll). Free / always-on / automatic / deliberately inaccurate all
stand. No contact, no ASW — the SONAR tree branch is load-bearing by design. See
`docs/specs/sonar-subs.md` and the Change Log.

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
2. ~~**Boss ladder & enemy roster naming**~~ — **RESOLVED 2026-07-09** by the C7 interview + spec
   (`docs/specs/boss-ladder.md`): mothership WAR MACHINES every 5th wave (THE JUGGERNAUT / THE
   CANOPY / THE MAW — a domain tour), parts + phases with soft-gated cores, endless lap scaling,
   per-part XP + lap bounty + hull patch; the roster carries EDF reporting names
   (GNAT/JACKAL/VULTURE/LAMPREY, display-only — mechanical ids untouched). Built in C7.
3. ~~**Helipad function**~~ — **RESOLVED 2026-07-09** by the C6 interview + spec
   (`docs/specs/air-wing.md`): the pad flies THE AIR WING — an autonomous, invulnerable ASW
   wingman (detector-first: its dipping sonar feeds the C5 contact latch, its light rack softens,
   the stern racks finish), unlocked by air1 WHIRLYBIRD, upgraded through the declassified
   seven-node column (door gunners at gate rev 2, MAD GEAR marquee). Built in C6.
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
- **C3 — Wave director & first enemies (built 2026-07-08).** Interviewed, spec'd, mockup-gated
  (two owner gate revisions: MMB secondaries + radar scope; over-the-horizon main battery with
  proximity fuse), and ported: seeded budget director, swarmer/gunboat/bomber roster, hull pips +
  grace, SHIP LOST card + fresh-seed restart, radar fire-control. The C2 practice range retired.
  Spec: `docs/specs/wave-director.md`.
- **C4 — Levels & tech tree (built 2026-07-08).** The Change Request made real: persistent XP/levels
  (first save file, `user://profile.cfg`), the 24-node tree + CLASSIFIED AIR WING, four marquee
  effects, title hub + tree screen, dev test kit (debug builds only). Spec: `docs/specs/tech-tree.md`.
- **C5 — Sonar, subs & depth charges (built 2026-07-09).** Interviewed, spec'd, mockup-gated
  (`design/sonar-subs.html`, owner-approved), and ported: the third D1.9 domain — sub elites with
  wake-drawing torpedoes, passive sonar detection + contact latch (D1.10), contact-gated stern
  depth-charge volleys (D1.11 as refined), the SONAR tech branch + ASDIC LOCK marquee, radar sonar
  ring + diamond blips, ripple tell. Spec: `docs/specs/sonar-subs.md`.
- **C6 — AIR WING (built 2026-07-09).** Interviewed, spec'd, mockup-gated through two owner
  revisions (weaving escort + speed-coupled throttle; door gunners ×2), and ported: the autonomous
  ASW helicopter off the stern pad — escort weave, dipping sonar on the C5 latch, detector-first
  light drops, fuel loop, MAD GEAR marquee, the AIR WING column declassified (7 real nodes).
  Resolves open thread #3. Spec: `docs/specs/air-wing.md`.
- **C7 — Boss ladder & naming pass (built 2026-07-09).** Interviewed, spec'd, mockup-gated
  (`design/boss-ladder.html`, owner-approved), and ported: mothership war machines every 5th wave
  touring the three domains, parts + phases, soft-gated cores, endless lap scaling, per-part XP +
  lap bounty + hull patch, the reporting-name pass + PRIORITY TARGET plate. Resolves open thread
  #2. The founding brief is systems-complete. Spec: `docs/specs/boss-ladder.md`.
- **C8 — Bug batch.** BUILT 2026-07-09 (see Change Log): nine fixes from the adversarial sweep,
  probe-gated, no design changes.
- **C9 — THE LIVING SEA.** BUILT 2026-07-09 (see Change Log): HEAVY WEATHER approved at the
  mockup gate; sea shader + ride + splash columns, render-only, probes byte-identical.
- **C10 — TACTICAL ZOOM.** BUILT 2026-07-09 (see Change Log): approved as-is; wheel 0.40–0.85,
  home 0.51, camera in config, sim camera-blind.
- **CREWED GUNS.** BUILT 2026-07-09 (see Change Log): burst-fire person-manned MGs on the S
  mounts, reach-roll stitching, air+surface; the AA nerf the owner asked for.
- **C11 — LONG-RANGE FIRE CONTROL.** BUILT 2026-07-10 (see Change Log): burst-at-cursor within
  range, fall-of-shot on the scope, flight-time readout, RANGEKEEPER as ord7.
- **C12 — READABILITY & FEEL.** BUILT 2026-07-10 (see Change Log): the scope speaks, the game
  sounds, the drip teaches, the wounded list. **The polish arc (C8–C12 + CREWED GUNS) is
  COMPLETE.** Remaining founding threads are narrative/naming only (#1 water-mystery,
  #4 working title); anything new starts with a fresh `/spec-feature` interview.

---

## Change Log
- **2026-07-10 — Housekeeping CR: HelmGauges split (no behavior change).** `HelmGauges.gd`
  (623 lines, past the 500 split guide since the C11/C12/C16 HUD growth) reduced to a slim
  orchestrator over render-domain helpers, exactly the C9 FieldRenderer precedent (static funcs
  taking the host `g: HelmGauges`, reaching its state/primitives; underscore access is the
  established house pattern). Domains: `GaugePanel` (the gauge plate + way/rudder bars + order
  text), `StatusPlates` (wave plate + PRIORITY TARGET boss plate), `RadarScope` (the scope:
  rings/labels/terrain/blips/fall-of-shot/rack dial + micro-label/dashed-arc), `HudOverlays`
  (reticle + flight time + RANGEKEEPER, pause plate, hint plate, lost card). The orchestrator
  keeps the color/dim consts, shared state, `bind`/`consume_effects`, `_draw` dispatch, and the
  shared plate/label/centering primitives. Every draw call preserved in order — verified by the
  full gate (boot-clean) + a HUD screenshot matching the pre-split render.
- **2026-07-10 — C16 THE WAR, REPACKED built; THE WORLD ARC (C14 hull · C15 waters · C16 war)
  IS COMPLETE.** Gate approved as-is. The C3 greedy director superseded (formal CR) by the
  formation/echelon composer: six templates as `WaveConfig.templates()` config data, echelons
  (vanguard 0 / main +15 / sting +28, normalized), the `quiet_secs` real quiet (12, renamed
  from the inert `lull_secs`), terrain-aware lane scoring + behind-the-rock ambushes (C15
  Terrain), singles filling the budget exactly. **Determinism strengthened:** composition on a
  per-wave substream keyed `(world_seed, wave)` — ZERO director `world.rng` draws — so the war
  is play-independent per seed (matches C15's terrain guarantee); two-world byte-identity holds,
  the probe re-baselines. C7 boss ladder preserved. New GameWorld read-state for the HUD
  (`wave_started`/`wave_ech_rel`/`wave_lines`/`wave_queue`); wave-plate names the drill phase.
  `lull_secs → quiet_secs` seam fixed across probe_bosses/probe_sonar/Main attract; `probe_waves`
  re-targeted + 4 C16 checks (cohesion, echelon separation, same-seed reproduction, ambush
  validity), 11 green; all pre-C16 probes pass untouched. **Remaining open threads are
  narrative/naming only** (#1 water-mystery, #4 working title); anything new starts fresh.
- **2026-07-10 — C16 spec interview: pressure = ECHELONS + REAL QUIET.** Each wave lands in
  2–3 echelons (vanguard → main body ~15 s behind → a sting), building to a crescendo; between
  waves a genuinely longer quiet (the sonar-sweep breather). With the earlier C16 interview
  (formations with shape; terrain-aware packing; domain mix KEPT), the director design is:
  budget buys FORMATION TEMPLATES (screens, lines, wedges, flights, wolfpacks — data in the
  waves config) assigned to echelons, bearings biased toward open water lanes, and an AMBUSH
  placement that stages surface/sub groups behind terrain features between the ring and the
  ship. Singles fill the remainder so the budget still spends exactly.
- **2026-07-10 — C15 THE WATERS built.** Seeded archipelagos (`Terrain.generate` = the world's
  first rng draws; `TerrainConfig`/`terrain.tres` with the owner's recipe: islets 3, rocks 9,
  size ×1.35, shoal 1.54×), the full land-rule blocking matrix (segment-swept), sliding hull
  collision with speed-scaled grind pips, tangent avoidance for every waterborne hull incl.
  machines, spawn re-rolls, dud charges on land, terrain art + scope land masses from shared
  verts, attract waters included. `probe_terrain` (14 checks) joins the gate; all pre-C15
  probes pass untouched (open water byte-identical). Integration seam fixed at the gate run:
  `Tech.apply` copies the terrain config like every system. Housekeeping flagged: HelmGauges
  past the split guide — candidate CR post-arc. THE WORLD ARC now awaits only C16.
- **2026-07-10 — C15 gate PASSED (approved as-is) + the land rules locked.** Grind cost:
  **speed-scaled** — a brush is friction, plowing in at speed costs a pip through the normal
  grace window. The owner's land rule, verbatim: **"terrain blocks all water vessels, no air
  vessels, air weapons and aa weapons are unaffected, everything else is."** Reading: every
  waterborne hull routes around land (ship, gunboats, SUBS, and the submerged MAW — the deep
  does NOT pass under); air units and their ordnance (WASP rockets, bay bombs, door-gun fire)
  plus the AA guns ignore terrain; ALL other projectiles die on rock — including mb16, which
  **supersedes the earlier "main battery arcs over" detail from the directive interview**:
  islands are hard cover against naval gunfire, both ways. dp5 rounds are blocked regardless
  of what they're aimed at (the gun fires flat — one simple rule, no per-target physics).
  Torpedoes always die on rock once running, whoever dropped them. **Gate tunes (owner,
  mid-port): shoal halo 1.54× · feature size ×1.35 · islet count fixed at 3 · rock features
  fixed at 9** — applied to the port configs (size as a `size_scale` dial; counts as
  min = max so variance can return later) and back-ported into the approved mockup's defaults.
- **2026-07-10 — AIR THREAT built (owner play-test directive, verbatim: "I can literally just
  go afk and make it to a boss, I want planes to drop torpedo pods or something once and a
  while to make them more than suicide bombers, or shoot unguided missles that miss often or
  can fly overtop of you"; interview: BOTH).** VULTURE reworked into a standoff TORPEDO BOMBER
  (drops running torpedoes on a 12 s period — full C5 torpedo kit inherited: wake, klaxon,
  counterplay, helo mark; contact-dmg field zeroed with the identity); NEW roster plane **WASP**
  (rep in the newsreel tally; cost 4 / unlock 4 / hp 2 / xp 40) ripples 4 unguided rockets per
  pass — wide spread, misses straddle via the C9 splash kit, overshoots overfly on the 1.4×
  life. New `EnemyDef.salvo` (default 1 — every other shooter byte-identical) + salvo loop in
  `Enemies.step` (per-rocket world.rng draws, stable order). GNATs stay the suicide swarm.
  `probe_waves` +1 (peak-sampled drop + full ripple), `probe_bosses` name pin re-targeted,
  manual TORPEDOES copy credits the sky. Roster mockup parity rides with C16. Gate green.
- **2026-07-10 — Owner directive (post-C13 play-test): THE WORLD ARC — C14/C15/C16 approved
  and interviewed.** Verbatim: "the player ship needs to be a bit larger to give things more
  space on the ship itself"; "I want to do a rework of the wave packing"; "add like rocks and
  small islands that we have to go around, static, loaded each run." Interview locked:
  **C14 THE HULL** — ~15% resize (HULL_SCALE 2.4 → 2.75), art + hit capsule TOGETHER (owner
  accepts becoming a larger target); the capsule consts scale in place — Hull.gd's header
  already rules them ship geometry, not balance tunables, and that stance stands. Deck
  furniture and mounts DON'T scale: the grown hull around them IS the requested deck space.
  Bow-anchored details (jack line, bow wave, wake stern point, the K-gun ring) ride the new
  hull. Mockup parity for the scale rides with C15's terrain mockup (which shows the new hull). **C15 THE WATERS** — scattered rocks + 2–4 islets per run,
  seeded from world.rng (same seed = same archipelago); ballistic splash shells ARC OVER,
  flat fire and torpedoes DIE on rock (islands are cover both ways); hull collision, enemy
  steering avoidance, spawn exclusion, terrain on the scope; full mockup gate (new look).
  **C16 THE WAR, REPACKED** — formations with shape (not blobs), pressure-rhythm rework, and
  terrain-aware packing (lanes/ambushes); domain mix explicitly KEPT; builds after C15 so the
  director tunes against real waters. Order: C14 → C15 → C16.
- **2026-07-10 — C13 FIELD MANUAL + show-off title built (owner directives at the play-test,
  verbatim: "needs a tutorial page that explains a function in text then underneath has a live
  example of all the mechanics"; "make the ship on the title screen invulnerable but have tons
  of shit on screen and max ALL of its upgrades — JUST for the title screen to show off").**
  New `manual` state + `TutorialScreen`/`TutorialVignettes` (nine text-over-training-film
  pages, deterministic loops, reduced-motion stills, M key + third title button); the attract
  world runs full-tree + `godmode` (presentation use of the DEV flag) + a cranked director
  (attract-only mutations on the DERIVED config copy — `start_sortie` re-derives honestly).
  This partially supersedes the C12 onboarding interview's "drip only" scope: the drip stays
  the in-sortie teacher; the manual is the reference the owner asked for after playing.
  UI/app/render only; gate green; probes untouched.
- **2026-07-10 — Play-test tune (owner feedback at the first C12 play-test; the K-GUN
  owner-tune precedent):** rack state moved OFF the scope onto the gauge plate's instrument
  line (`RACKS ARMED` / `RACKS · · ·`, fixed width — the on-scope dial read as a contact;
  supersedes the feel board's panel-2 placement), scope ring diet (1000u marks only) +
  micro-labels (`16-IN`/`SONAR`/`DC`/`VIEW` — "unclear what everything is," now named), and a
  TITLE ATTRACT MODE ("the title screen needs some action"): a real auto-piloted sortie behind
  a scrimmed title, player's unlocks, sound on, off-center camera, 3 s relaunch on demo death.
  Nothing banks, no hints fire from attract. `view_rect()` culls around the camera now (the C9
  audit's flagged trap, made real by the off-center attract cam). Render/app only; gate green.
- **2026-07-10 — C12 READABILITY & FEEL built; THE POLISH ARC IS COMPLETE.** Gate approved
  as-is (`design/readability-feel.html`, the FEEL BOARD). Sound: 13 procedural WAVs baked
  offline (`tools/gen_sfx.py`, seeded/stdlib — the mockup's recipes verbatim) + `SfxPlayer` on
  the one-way effect channel with per-sound rate limits + `AudioConfig`/`audio.tres`; the
  dropped `klaxon` (= machine arrival) and `waveclear` events finally sound; torpedo launches
  emit a cosmetic `torpwater` (the horn) — the arc's only sim touches are that append and
  nothing else, probes byte-identical. Scope: torpedo dash + wake sparks (the C5 promise),
  dashed DC arm ring + rack dial. Flow: `P` pause (sim holds, sea drifts), key-only lost card
  (1.5 s guard, R/T), contextual-drip hints ×5 once-per-profile (`Profile.seen_hints`).
  Render: wounded tells (list/char/smoke/flame, deterministic heel side). CLAUDE.md gotcha:
  gdparse tolerates nested same-name loop vars that Godot hard-rejects. With C8–C12 all built,
  the 2026-07-09 research-pass directive is fully discharged.
- **2026-07-10 — C12 spec interview: onboarding = CONTEXTUAL DRIP.** One-line deadpan hint
  plates, each shown ONCE PER PROFILE the first time it matters (first sortie: helm +
  force-fire; first sub contact: the deaf-deep rule; first torpedo; first machine) — no menus,
  no manual. Seen-flags persist in the profile (app layer, like XP).
- **2026-07-10 — C11 LONG-RANGE FIRE CONTROL built; the C3 gate-rev-2 rule formally superseded
  WITHIN GUN RANGE (CR complete).** Gate approved as-is (`design/fire-control.html`). Forced
  splash shells burst AT the cursor when it's within reach (`Turrets._fire`: the `not forced`
  guard died — one condition); beyond range the C3 bearing shot survives via the same `minf`.
  Proximity fuse untouched; deaf-deep law untouched; no rng — probes byte-identical. HUD:
  flight-time readout + MAX RANGE · BEARING telltale at the reticle; fall-of-shot on the scope
  (own mb16 shells as foam dots + burst flashes; Main plumbs the same one-way effect batch to
  HelmGauges); **RANGEKEEPER shipped as ord7** (cost 2, behind FULL SALVO; advisory steel ghost
  at the computed intercept, 120u snap via `tech.rangekeeper_snap`; shells still obey the
  cursor). Tree 37 nodes / 65 points (level 66 = everything; dev-kit tracks). `probe_tech`
  totals + `probe_hardpoints` check 5 re-targeted; full gate green.
- **2026-07-10 — C11 spec interview: LEAD-ASSIST is IN, as a tech node.** Owner chose the
  advisory version over deferral: a late-tree fire-control node (working name **RANGEKEEPER**,
  the USN's actual gun computer) — while force-firing, a ghost marker shows the computed
  intercept for the radar contact nearest the cursor; the player still lays the gun and pulls
  the trigger. HUD-side read of sim state only (render one-way, no sim change, no rng); the
  tree grows one node (probe_tech's full-catalog totals re-target with it).
- **2026-07-09 — CREWED GUNS built (the mid-C10 directive, CR complete): the S mounts are
  person-manned machine guns.** Bursts with rest gaps (10 rounds at 12/s, 1.5 s re-lay), wild
  0.14 spread, per-round 40–100% reach rolls through `world.rng` (short rounds stitch the water
  via the C9 splash kit), domains air+surface (`weapons.tres` + `spec_defaults()` +
  `Bosses.WPN_DOMAINS`); the deep stays deaf. New config-generic `WeaponDef`
  `burst_rounds`/`burst_rest`/`reach_min` (0/0/1.0 defaults — dp5/mb16 byte-identical) +
  `Mount.burst_left`. AA sustained output 12/s → ≈4.3/s: planes more dangerous, accepted in the
  directive verbatim. All six FLAK nodes live (flk4's bloom re-targeted in probe: accumulation,
  not the hose ceiling). `probe_hardpoints` re-targeted (checks 2/6/7); full gate green;
  parity ported into the mockup sims that model aa20 (K-GUN precedent). Spec:
  `docs/specs/crewed-guns.md`; `ScreenshotCG` proof harness.
- **2026-07-09 — C10 TACTICAL ZOOM built; the C1 fixed camera formally superseded (CR complete).**
  Gate: `design/tactical-zoom.html` approved as-is, defaults shipped. New `CameraConfig.gd`/
  `camera.tres` (zoom 0.40–0.85, home 0.51, wheel step 1.18, lerp half-life 0.12 s, enemy floor
  10 px, stroke comp on); the `.tscn` hardcode removed; `zoom_in`/`zoom_out`/`zoom_home` input
  actions. Sorties boot at home; fades key off the wheel target. **Ship-centered camera retained
  — the directive's "cursor-anchored" detail superseded with rationale** (would fight the C1
  ship lock and skew the radar's viewport-extent read; spec §2). Stroke compensation routed
  through all render helpers (×1 exactly at 0.85 — the LOOK-LOCK view byte-identical);
  min-apparent-size floor on hostiles. App/render only, sim camera-blind, probes byte-identical.
  Glint shader thresholds tightened at the port fidelity check (the 0.85 view read snowier than
  the approved mockup). `ScreenshotC10` harness; C9's harness re-pointed at the target-zoom path.
- **2026-07-09 — Owner directive (mid-C10, recorded verbatim per the C4 CR template): CREWED
  GUNS.** "Whatever that little strafe fire is we need to add that into the game, it looks so
  good — let's find an excuse to use it. The AA guns feel a little powerful 'cause there's so
  many; I was thinking of having them be more like person-manned machine guns so we get the
  strafing effect when it hits the water, and they can also shoot at planes, though planes
  would become more dangerous. I do like that anyways." Reading: the door-gunner firing model
  (C6 — wild spread, per-round 40–100% reach rolls, gunsplash stitching) comes aboard the four
  S mounts, replacing aa20's clinical 12/s hose; the air threat rising is an accepted,
  desired consequence. Specifics deferred to the spec interview; slots into the arc as its own
  small chunk immediately after C10 (visual language already shipped/approved — door-gun tracers
  + gunsplash + C9 columns — so this is a sim-behavior CR with mockup parity updates, the K-GUN
  precedent). Touches: `weapons.tres`/`Turrets`/`Projectiles`, FLAK tech branch reads,
  `probe_hardpoints` (the C8 cadence checks will need re-targeting to the new model).
  **Spec interview held same day, two decisions locked:** (1) firing model = **BURSTS WITH REST
  GAPS** — ~8–12 rounds at ~12/s then a 1–2 s re-lay pause, wild spread, per-round 40–100% reach
  rolls (each burst walks a stitch-line toward the target; the biggest honest AA nerf);
  (2) domains = **air + surface, never sub** (the door-gunner envelope — the guns always have
  something to strafe; gunboats get chip damage). Air threat increase accepted by the owner in
  the directive itself.
- **2026-07-09 — C9 THE LIVING SEA built; the C2 LOOK-LOCK superseded FOR THE WATER AND RIDE
  ONLY, through the lawful gate.** Two directions built as live presets on one interactive
  mockup; the owner approved **direction B "HEAVY WEATHER"** with gate tunes (splash column
  scale 1.4, foam disc life 3.4 s, wake foam life 9.0 s; judged at zoom 0.51 — recorded for
  C10). `design/living-sea.html` is the new water/ride reference; hull/turret art, palette, and
  line weights stay C2-verbatim and LOOK-LOCKED. Spec: `docs/specs/living-sea.md`. Built: sea
  shader on a `SeaLayer` (CanvasLayer −1) fed one-way by Main; crest-biased flecks + crest-foam
  streaks; heave/roll/hull-shadow ride (render-only); churned prop+V wake; splash COLUMNS with
  per-battery dye; DC subsurface glow; air-enemy shadows + gunboat bob (the shipped C6/C7 shadow
  language). **Cosmetic-only sim change (no CR needed, noted per the effects-channel rule):**
  `Projectiles.gd` now APPENDS splash/gunsplash effects for shells that miss into the sea
  (hostile misses, spent dp5/aa20, unburst flak) — append-only, no rng, no behavior change;
  two-world determinism probes stay byte-identical. **Config:** `field.tres` gained the C9 sea
  tables incl. `reduced_motion` (the law: sea/ride/column animation freezes, foam discs stay).
  **Refactor (house 500-line rule):** `FieldRenderer` split into `SeaRender`/`ShipRender`/
  `HostileRender`/`FxRender` helpers under a ~150-line orchestrator — one CanvasItem, draw order
  unchanged. **Gate hardening:** `verify.sh` fails on `SHADER ERROR` (one escaped the
  SCRIPT-ERROR-only grep during this build). `ScreenshotC9` harness added (sea / 0.4× zoom
  floor / reduced motion).
- **2026-07-09 — Owner direction (research-pass interview): the polish arc C8–C12 is approved.**
  Recorded verbatim from the interview, specifics deferred to per-chunk spec/mockup gates per the
  C4 CR template: **C8** bug batch (built — see below). **C9** THE LIVING SEA — render-only sea
  pass (swell, heave/roll, hull shadows, shell splash columns, upgraded wakes; cosmetic-only RNG;
  reduced-motion setting); supersedes the C2 LOOK-LOCK **only through a new approved mockup
  revision** — the mockup gate stays in force (owner chose full gate over Godot-direct iteration).
  **C10** TACTICAL ZOOM — owner chose **~2× out** (wheel zoom to ~0.4, cursor-anchored, smoothed)
  over strategic/overview depth: existing art survives via screen-px stroke compensation + a
  minimum-apparent-size floor for the smallest hostiles; NO icon/blip LOD stage; camera gets its
  own `CameraConfig.gd`/`camera.tres` (the .tscn-hardcoded 0.85 becomes config). This is a formal
  CR when built: the camera was deliberately fixed at C1. **C11** LONG-RANGE FIRE CONTROL — owner
  chose **burst-at-cursor-point**: forced mb16 bursts AT the cursor's world position when within
  gun range (bearing-mode full-range flight beyond it; proximity fuse and the radar fire-control
  line stay) + fall-of-shot feedback (own shells/bursts on the scope), flight-time readout,
  ranging/straddle feedback. Supersedes the C3 gate-rev-2 *rationale* ("the cursor can only
  express a screen's worth of distance" — C10 removes that premise), NOT its bearing mechanism,
  which survives beyond-range. Formal CR when built. **The deaf-deep law is explicitly NOT
  touched: long-range fire never hurts subs.** **C12** READABILITY & FEEL — torpedo-blip
  distinction, DC arm-ring + rack cooldown on the scope, pause, lost-card misclick guard,
  onboarding hints, wounded-enemy tells, and a **minimal SFX pass** (owner: procedural SFX wired
  to the existing 22 sim effect events incl. the currently-dropped `klaxon`/`waveclear`; no music).
- **2026-07-09 — C8 Bug Batch built: nine fixes from the first adversarial full-code sweep; no
  design changes, shipped systems now match their specs.** dp5 flak fuses off war machines (the
  fuse loop never scanned `world.boss`; submerged machines stay deaf); splash/airburst strikes
  resolve at the burst point clamped to the hull disc, not the machine's center (off-center parts
  were blast-proof); THE CANOPY's bay bombs got their spec'd splash (`BossDef.bomb_splash` = 30 in
  `bosses.tres` — new field, hostile splash-at-expiry mechanic in `Projectiles.gd`); sonar latch
  writes are `maxf` — extend, never shorten (ship passes were clobbering MAD GEAR's permanent bird
  marks, violating the C6 spec); turret cooldown carries the sub-tick remainder (aa20 fired 10/s
  vs configured 12/s from whole-tick quantization; sustained rates now match config exactly —
  a known ~20% AA DPS tighten, intent not drift; idle guns bank at most one shot); posthumous
  kill XP delta-banks while `run_over` (was silently dropped; lost card matches the profile);
  dev-kit MAX LVL computes from the catalog (63 pts → L64, was stale at 40); menus draw over open
  sea only (combat layers gate on `show_ship`); dead `WPN_DOMAINS["dc"]` entry removed. Probes:
  bosses 11, sonar 9, hardpoints 8, tech 10 — all red-green against the pre-fix code. **Mockup
  divergence found and healed:** the approved `design/boss-ladder.html` carried the same three
  boss bugs (a mockup-spec gap — spec wins); the fixes are ported into the mockup per the C3
  parity precedent. Spec correction: `docs/specs/tech-tree.md`'s "40 total" predates
  SONAR/AIR WING — the shipped catalog is 63 (dated note added in place).
- **2026-07-09 — C7 Boss Ladder & Naming Pass built; open thread #2 resolved; the founding brief
  is systems-complete.** The approved C7 spec + mockup ported: `BossConfig`/`bosses.tres`
  (generated from `spec_defaults()`) + `Boss` entity + `Bosses.gd` (after Enemies in the fixed
  order) — one machine at a time, gunboat-pattern brain, hull-relative destructible parts, phase
  changes on part loss (speed/minions/rate; the MAW's breach extends), soft-gated core (×0.25
  while any part lives), machine-specific attacks (JUGGERNAUT led shells + panic director, CANOPY
  bombs + hive, MAW torpedo fans on a 20s/8s dive–breach cycle). `Waves.gd` fields a machine +
  `escort_frac` budget every `every_n`-th wave and holds wave-clear until machine AND escort die.
  Machines integrate with EVERYTHING: sonar/bird hear a submerged MAW (D1.10 gating), the racks
  arm on it, turret targeting competes machine parts/core with drones under the same policies
  (pseudo-target refactor in `_pick_target`), and strikes respect domain tags physically for
  machines (the CANOPY flies above flat naval fire — a C7 machine rule; drones keep D1.9 physical
  hits). Rewards: `xp_part` on the spot, `xp_core`×lap, +`hull_patch` pips capped (D1.8 REFINED —
  a reward event, not a second health pool). Naming pass: `EnemyDef.rep`
  (GNAT/JACKAL/VULTURE/LAMPREY) live in the wave-plate newsreel tally; PRIORITY TARGET plate with
  core bar + strike-through part pips; oversized radar blips. **Owner tune at this gate (C5
  behavior change, all sims + spec updated): the stern racks now throw a K-GUN SPREAD** — stations
  evenly around the beams and stern (`sonar.dc_ring` 85), scatter jittering each station — because
  the auto-firing racks were too hard to connect when piled on one stern point. `probe_bosses`
  (8 checks incl. the spread geometry) added to the gate; `probe_waves` isolates the C3 director
  from the ladder (`bosses.every_n = 0` in its budget scenario).
- **2026-07-09 — C6 AIR WING built; open thread #3 resolved; the CLASSIFIED column declassifies.**
  The approved C6 spec + mockup (two owner gate revisions) ported to Godot: `AirWing.gd` after
  DepthCharges in the fixed order (inert without `tech.helo` — zero-tech probe-gated),
  `AirWingConfig`/`airwing.tres` (per-system rule), the single-bird state machine on GameWorld
  (pad → air → rtb), the ESCORT WEAVE + THROTTLE flight model (gate rev 1: aim point rides the
  ship and leads with its speed; the bird eases near station and opens up to ship+margin when
  behind — plus an astern beeline rule; the acceptance contract is RECOVERY: back ahead of the bow
  within 5 s from any transient dip), dipping sonar writing the same `detected_until` latch as
  ship sonar (MAD GEAR marquee: bird-made latches never decay), contact-centered light drops
  (detector-first — softens, never finishes fast; the stern racks stay the killer), DOOR GUNNERS
  (gate rev 2: two nodes, weak wild tracers vs air/surface with rolled short reach — `gunsplash`
  water slaps; the deep draws zero fire), fuel loop ~45 s/10 s, helo render (rotor/shadow/dip
  ring/pad rearm arc), radar bird blip + dip ring, the seven-node AIR WING column replacing the
  ████ placeholders (`tech.tres` regenerated, 36 nodes; tree screen redacts air2+ until
  WHIRLYBIRD is owned). `probe_airwing` (10 checks) added to the gate; `probe_tech`'s "AIR WING
  locked" check superseded (air1 buys, air2 gates behind it). Torpedo launches now mark
  `world.helo_mark` for the bird's investigate behavior (gated on `tech.helo`).
- **2026-07-09 — Deaf-deep law made PHYSICAL (latent C5 gap, found at the C6 mockup gate).** C5
  locked "the deep is deaf to gunfire" but only enforced it in TARGETING — the generic projectile
  hit test and the PROXIMITY BURST trigger/damage loops still let a stray friendly shell that
  physically crossed a submerged contact strike it (surfaced by the C6 door gunners peppering
  water near a sub). Fixed in `Projectiles.gd` and BOTH shipped mockup sims
  (`design/sonar-subs.html`, `design/air-wing.html`): friendly shells and airbursts now skip
  `layer == "sub"` entirely — shells fly OVER the deep; depth charges remain the only sub killer.
  D1.9's "domain tags gate targeting only; a shell that physically arrives hits regardless" note
  (C3 entry) now carries this one exception: submerged hulls are physically out of reach of
  gunfire, which is the C5 owner law, not a targeting choice. `probe_sonar`'s deaf-guns check
  extended to force-fire straight through a sub and assert zero damage.
- **2026-07-09 — C5 Sonar, Subs & Depth Charges built; D1.11 refined by owner supersession; D1.9's
  third domain live.** The approved C5 spec + mockup ported to Godot: `sub` in the roster
  (elite — cost 6, unlock 7, standoff torpedo shooter; `EnemyDef.torp_run` marks torpedo fire),
  `Sonar.gd` + `DepthCharges.gd` in `Sim.step`'s fixed order (after Enemies, before Turrets),
  `SonarConfig`/`sonar.tres` (per-system config rule), torpedo + `"dc"` projectile branches
  (charges sink on a fuse, then blast SUBS ONLY — ship and surface/air untouched), the SONAR tech
  branch (son1–son5, ASDIC LOCK marquee) in `tech.tres`, `xp_sub` 80, the three-way domain map in
  `Turrets._pick_target` (no gun carries "sub" — the deep is deaf to gunfire by construction),
  render/HUD per the approved mockup (detected silhouette + foam ring, ripple tell, torpedo wakes,
  DC sink/blast fx, radar sonar ring + sonar-gated diamond blips, contact ping, six-column tree,
  dev-kit +SUB). **D1.11 superseded in part at the owner interview:** charges arm ONLY on a sonar
  contact (noted inline at D1.11); D1.10 implemented as specced (noted inline). Two mockup bugs
  caught by the validation harness before approval: the domain map returned "surface" for subs
  (guns shot them), and the standoff brain gated on `type == "gunboat"` (subs sat inert) — both
  fixed in the mockup, ported correctly. `probe_sonar` (8 checks incl. zero-tech baseline: waves
  1–6 stay sub-free, and the director provably fields subs once unlocked) added to the gate.
- **2026-07-08 — C4 Levels & Tech Tree built; the Change Request is real.** Persistent career:
  `Profile` (the FIRST save file, `user://profile.cfg` — strictly app-layer, the sim never reads
  it), `Tech.apply` deriving each sortie's `Configs` from duplicated `.tres` values + unlocked
  nodes (baseline invariance probe-gated: zero tech = byte-identical C3), `ProgressConfig` XP/level
  curve, `TechConfig`/`tech.tres` (generated from `spec_defaults()` for parity), the four marquee
  sim features behind default-off flags (CRASH TURN in Movement, INCENDIARY burn in Enemies,
  PROXIMITY BURST in Projectiles, FULL SALVO in Turrets), title hub + tech-tree screen + lost-card
  XP report, and the DEV TEST KIT (owner request) gated behind `OS.is_debug_build()`. Owner's
  approval fix: shells spawn at the barrel MUZZLE (L 35 / M 22 / S 13 u; gunboats +14) — applied to
  sim + mockups. Also fixed at port: the C3 fx dispatcher had silently dropped
  gunflash/shiphit/shipdeath draws (render-only gap; now complete incl. the C4 effects).
  `probe_tech` (9 checks) added to the gate.
- **2026-07-08 — CHANGE REQUEST (owner): tech-tree progression replaces the hardpoint purchase
  economy.** Owner directive, verbatim intent: ships have SET hulls and turrets; the upgrade path is
  persistent LEVELS gained across runs, unlocking a TECH TREE of upgrades and effects — many
  movement upgrades, turret-size-specific upgrades, bullet effects, traverse speed, and a HELICOPTER
  tech tree (function undecided). Supersedes: the founding brief/SPEC's "visible, purchasable
  hardpoint positions" economy (mounts stay visible and hull-mounted per D1.5 — the PURCHASE axis
  dies, not the art); the planned hardpoint-purchase-shop reuse of fulfillment's Depot pattern.
  Conveniently, the C2/C3 build already runs a FIXED loadout — no built system is orphaned. Open
  thread #3 (helipad function) evolves into the helicopter tech-tree question. Detailed design goes
  through its own `/spec-feature` interview before anything is built (this entry records the
  direction, not the specifics).
- **2026-07-08 — C3 Wave Director built; the game has stakes.** The approved C3 spec (two owner gate
  revisions) ported to Godot: `Waves.gd` (seeded budget director), `Enemies.gd` (swarmer/gunboat/
  bomber, beyond-the-edge arrival, led + dodgeable gunboat shells), `Hull.gd` (pip pool per D1.8
  with a grace-window refinement, capsule contact, run end), `WaveConfig`/`waves.tres` +
  `EnemyConfig`/`enemies.tres` (EnemyDef sub-resources), hostile projectiles, MMB medium force-fire,
  radar scope with fire-control bearing (RadarView analog — D1.10 will sonar-gate SUB blips later),
  over-the-horizon main battery with proximity fuse, SHIP LOST card + fresh-seed restart in Main.
  **The C2 practice range retired by owner decision** (Drones/RangeConfig/range.tres deleted; the
  turret probe suite re-targeted at hand-placed enemies). **Port fix, applied to the mockup too:**
  turret auto-fire now leads its target — no-lead fire proved unable to hit orbiting gunboats, so
  waves could never clear. `probe_waves` added to the gate. D1.9 note: with contact damage live,
  domain tags remain targeting-capability only (a shell that physically arrives hits regardless).
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
