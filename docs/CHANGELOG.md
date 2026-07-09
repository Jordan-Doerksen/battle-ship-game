# Changelog — Earth Defense Force (working title)

Chunk log, newest first. Each chunk ships only after it passes the cross-check against `DECISIONS.md`.

---

## C8 — BUG BATCH · 2026-07-09 · Built

Nine bugs from the first full-code adversarial sweep (research pass, owner-approved plan). No new
mechanics — the ones already shipped now do what their specs say. CR-free per the fix precedents;
every fix that could be probed is.

- **dp5 flak fuses off war machines.** With PROXIMITY BURST the fuse loop scanned only
  `world.enemies` and the airburst branch swallowed every dp5 shell — an upgraded gun that could
  never hurt a boss. The machine is a fuse candidate now (air trigger envelope vs THE CANOPY,
  contact vs surface machines; a submerged MAW neither triggers nor feels it — the deep stays deaf).
- **AoE strikes resolve at the burst point, not the machine's center.** Splash/airburst passed
  `world.boss.pos` to `Bosses.strike`, so off-center parts (turrets, bays) were unhittable by
  blast and hit effects drew at the wrong spot. The strike point is the burst clamped to the hull
  disc — edge bursts that pass the AoE gate still chip the core instead of dealing nothing.
- **THE CANOPY's bay bombs are splash attacks**, as the spec table always said (`bomb_splash` 30 —
  a new `BossDef` field in `bosses.tres`): they burst at flight end and hit the hull within the
  blast. They were point-contact shells; the hostile path had no splash mechanic at all.
- **Sonar extends a latch, never shortens it.** A ship-sonar pass over a bird-marked contact
  rewrote MAD GEAR's permanent latch down to a decaying ~4 s hold, at both write sites (sub +
  submerged MAW). `maxf` at both.
- **Turret cadence carries the sub-tick remainder.** Cooldown-by-assignment quantized every period
  UP to whole 60 Hz ticks — aa20 really fired 10/s against its configured 12/s. Decrement now gates
  at zero (idle guns bank at most one shot, never a backlog burst) and reload accumulates. Balance
  note, not drift: sustained AA DPS rises ~20% to what the config always claimed; dp5/mb16 tighten
  the same way.
- **Posthumous XP banks.** Shells still flying when the ship sank kept scoring kills the profile
  never saw. XP delta-banks every frame while the run is over; the SHIP LOST card shows exactly
  what reached the profile.
- **Dev kit MAX LVL computes from the catalog** (63 points → level 64) instead of the stale
  level-41 grant that left the tree unaffordable. Self-updates if the catalog grows.
- **Menus sit over open sea only.** Enemies, the machine, shells, and combat FX from the dead run
  no longer draw behind the title and tech-tree screens.
- Removed the dead `WPN_DOMAINS["dc"]` entry (depth charges detonate in their own branch and never
  reach `strike()`); `probe_bosses` reads the blast radius from config, not a const.
- **Mockup parity:** the three boss-behavior fixes are ported into `design/boss-ladder.html` too
  (the approved mockup carried the same bugs — C3 precedent: the fix lives in the reference).
- **Verify:** `probe_bosses` 8 → 11 checks (burst-point part attribution, dp5 flak vs machines +
  the deaf deep, bay-bomb splash in/out + live bay build), `probe_sonar` 8 → 9 (MAD latch survives
  ship sonar), `probe_hardpoints` 6 → 8 (sustained cadence == rate·T ±1; no catch-up burst after a
  10 s gap), `probe_tech` 9 → 10 (full-catalog affordability at L64). All red-green verified
  against Godot 4.7 headless; full gate green.

## C7 — BOSS LADDER & NAMING PASS · 2026-07-09 · Built

The war gets a face; the roster gets its names. The last founding system lands — open thread #2
resolves, and the design brief is SYSTEMS-COMPLETE. Full pipeline: interview (10 decisions) →
approved spec → mockup (two real balance findings) → approval → Godot port with one owner tune.

- **The ladder:** every 5th wave a mothership WAR MACHINE arrives with a half-budget escort; the
  wave holds until machine AND escort die. Three rungs tour the domains, then it laps forever at
  ×1.5 hp: THE JUGGERNAUT (wave 5, surface — turret parts + a fire director it panic-fires
  without), THE CANOPY (wave 10, air — the main battery passes under it; bomb bays + a GNAT hive),
  THE MAW (wave 15, the deep — 20 s stalking with torpedo fans, 8 s breached with vent cowls
  exposed; every cowl killed extends the breach. It can't seal).
- **The grammar:** hull-relative destructible parts (60 XP each, banked live), phase changes on
  every loss, soft-gated cores (×0.25 until the parts fall). Core kill: 250 XP × lap + a 2-pip
  hull patch — the survival loop's first breather (D1.8 refined: a reward event, not a second
  pool). Machines plug into every system: sonar and the bird hear a stalking MAW, the racks arm on
  it, turrets compete its parts with drones under the same policies, and strikes respect domain
  tags physically (a C7 machine rule).
- **The names:** GNAT / JACKAL / VULTURE / LAMPREY (`EnemyDef.rep`, display-only — mechanical ids,
  configs, and probes untouched). The wave plate reads like a newsreel tally; machines get a
  PRIORITY TARGET plate (THE-name + lap, core bar, part pips that strike through) and oversized
  radar blips (sonar-gated while the MAW is under). Dev kit: three machine spawn buttons.
- **Owner tune at the gate (C5 behavior change):** the stern racks now throw a K-GUN SPREAD —
  throw stations evenly around the beams and stern (`sonar.dc_ring` 85), scatter jittering each
  station — because blind auto racks piling charges on one stern point were too hard to connect.
  Applied to Godot + all three mockup sims + the C5 spec.
- **Verify:** `probe_bosses.gd` — 8 checks (determinism through boss waves, cadence + ladder +
  lap scaling + boss-free early waves, soft gate, parts + phases + rewards, the domain tour,
  bounty/patch/cap, the K-gun spread geometry, names) — added to `verify.sh`; `probe_waves`
  isolates the C3 director from the ladder. `ScreenshotC7` harness.

## C6 — AIR WING · 2026-07-09 · Built

The pad was never set dressing. Open thread #3 resolves: an autonomous ASW helicopter flies off
the stern, and the CLASSIFIED column declassifies. Full pipeline: interview (10 decisions) →
approved spec → mockup → TWO owner gate revisions → approval ("apoproved") → Godot port.

- **The bird (air1 WHIRLYBIRD unlocks it):** one airframe, one state machine (pad → air → rtb) on
  GameWorld, invulnerable by construction (nothing targets it; no damage path exists). Flies every
  wave regardless — spectacle first.
- **Gate rev 1 — escort weave + throttle:** a smooth S-weave across the bow that rides the ship;
  the aim point leads further ahead as the ship speeds up, and the bird has a real throttle (ease
  to station-keeping near the point — which scales with ship speed — open to ship+80 when behind;
  astern beeline failsafe). Contract, probe-gated: from any transient dip it is back ahead of the
  bow within 5 s. Constant-speed pursuit (draft) plunged ~800 u astern at flank — retired.
- **ASW (detector-first):** dipping sonar (240 u) writes the SAME contact latch as ship sonar —
  its finds are your diamonds and they arm your stern racks. Over a detected sub it drops a tight
  contact-centered 2-charge pattern (1 dmg, 9 s cadence): softens and marks, never finishes fast —
  the stern game stays king. Torpedo launches mark an investigate point it runs down.
- **Gate rev 2 — DOOR GUNNERS (air5/air6):** weak, wild MG fire at the nearest air/surface target
  near the bird; every round rolls spread AND a 40–100% reach fuse, so bursts stitch the water
  short of max range. The deep draws zero fire.
- **MAD GEAR (air7 marquee):** bird-made contacts never decay this wave; ship contacts still do.
- **Deaf-deep law made PHYSICAL (latent C5 gap the gunners exposed):** friendly shells and
  airbursts now skip submerged hulls in `Projectiles.gd` and both mockup sims — depth charges
  remain the only sub killer, by physics and not just targeting.
- **Tree:** the five ████ placeholders superseded by seven real nodes (1/1/2/2/2/2/3); air2+ stay
  redacted on the board until WHIRLYBIRD is owned. `tech.tres` regenerated (36 nodes).
- **Verify:** `probe_airwing.gd` — 10 checks (determinism, zero-tech inertness, extended ears,
  detector-first prosecution, fuel loop, speed-coupling recovery contract, MAD GEAR, tree
  derivation incl. 1-then-2 gunners, invulnerability, door gunners + deaf deep) — added to
  `verify.sh`; `probe_tech`'s AIR-WING-locked check superseded. `ScreenshotC6` harness.

## C5 — SONAR, SUBMARINES & DEPTH CHARGES · 2026-07-09 · Built

Something is under the water. The third D1.9 domain lands, completing the founding air/surface/sub
fantasy. Full pipeline: interview (8 decisions, incl. the owner's D1.11 supersession — depth
charges arm ONLY on a sonar contact) → approved spec → interactive mockup (7/7 validation harness;
two real bugs caught pre-approval: subs tagged "surface" so guns shot them, and the standoff brain
ignoring subs) → owner approval ("totally cool") → Godot port verified side-by-side.

- **Sub (roster elite):** cost 6, unlocks wave 7; hp 6, speed 35, gunboat-pattern standoff brain
  at 600 u. Its "shell" is a TORPEDO: slow (130 u/s), straight-running ~900 u, 2 pips on a hull
  hit, dodgeable off its wake line and outrunnable at full ahead. No gunflash — the deep is silent.
- **Sonar (`Sonar.gd` + `SonarConfig`/`sonar.tres`):** passive radius 350, contact latch 2.5 s on
  `Enemy.detected_until` (pure arithmetic, zero draws), `contact` ping on first acquisition.
  Detected subs: dark silhouette + foam ring in the world, diamond blips on the scope inside a
  soft sonar ring (D1.10). Undetected subs near the ship: a render-only ripple tell. Nothing else.
- **Depth charges (`DepthCharges.gd`):** free, automatic, deliberately inaccurate — and armed only
  by a DETECTED sub inside 220 u. Volleys of 4 scatter around the stern (seeded draws, volley
  order), sink 1.5 s, then blast SUBS ONLY (55 u, 3 dmg) — the ship and surface/air enemies never
  feel them. Guns can't touch subs at all: the domain map is probe-gated deaf.
- **Tech:** the SONAR branch (sixth column) — Hydrophones/Trained Ears/Deep Pattern/Quick Racks +
  ASDIC LOCK (marquee: −50% scatter, +30% blast). `tech.tres` regenerated (34 nodes). Sub kill:
  80 XP.
- **UI/render:** torpedo foam-wake runner, DC sink + underwater-blast fx, contact diamond ping,
  radar sonar ring + gated diamonds, six-column tree board, dev-kit `+SUB`.
- **Verify:** `probe_sonar.gd` — 8 checks (determinism with subs/torpedoes/DC, deaf guns,
  detection+latch, the DC trigger law, DC kill + isolation, torpedo behavior, SONAR derivation,
  zero-tech baseline: waves 1–6 sub-free AND the director provably fields subs once unlocked) —
  added to `verify.sh`. `ScreenshotC5` harness captures volley/blast/torpedo/tree frames.

## C4 — LEVELS & TECH TREE · 2026-07-08 · Built

The war gets a career, implementing the owner's Change Request (fixed hulls/turrets; persistent
levels replace the purchasable-hardpoint economy). Full pipeline: interview (8 decisions) →
approved spec → interactive mockup (career loop + owner-requested DEV TEST KIT) → approval with one
fix condition (muzzle-origin shells) → Godot port verified side-by-side.

- **Meta:** `Profile` — the FIRST save file (`user://profile.cfg`: XP + unlocked nodes; app-layer
  only, the sim never reads it). XP: kills by type (10/30/50) + wave-clear bonuses (25×wave), kept
  on death; linear-ramp level curve; 1 tech point per level.
- **Tech:** `TechConfig`/`tech.tres` (generated from `spec_defaults()` so code and resource cannot
  drift) — 24 buyable nodes across SEAMANSHIP/FLAK/GUNNERY/ORDNANCE with strict in-branch order and
  1/2/3-pt costs, plus the CLASSIFIED AIR WING (5 redacted, unbuyable nodes; open thread #3).
  `Tech.apply` derives each sortie's `Configs` from DUPLICATED base resources + node mods —
  baseline invariance is probe-gated (zero tech = byte-identical C3 behavior).
- **Marquees (sim features behind default-off flags):** CRASH TURN (Movement: emergency-back at
  speed arms a ×1.8 turn window on cooldown), INCENDIARY LOAD (aa20 hits ignite air enemies; burn
  ticks in Enemies), PROXIMITY BURST (dp5 shells airburst near air targets with a small AoE),
  FULL SALVO (mb16 fires both barrels per trigger, one spread draw).
- **UI:** title hub (BEGIN SORTIE / TECH TREE, level + XP bar), tech-tree plotting board
  (buy/respec/points, AIR WING stamp), wave-plate XP tally, lost-card XP report + LEVEL UP line +
  `[T]` shortcut. Main owns the title/tree/game state machine; menus show open sea (no ghost hull).
- **DEV TEST KIT (owner request; debug builds only, ` to toggle):** invulnerable, freeze waves,
  god guns, spawn swarmer/gunboat/bomber/swarm×8, kill all, next wave, heal, max level. Sim
  intercepts (`godmode`, `freeze_waves`) default off; spawns use non-sim RNG.
- **Fixes:** shells spawn at the barrel MUZZLE (owner's approval condition — no more rounds rising
  through the turret house; gunboats too), and the C3 fx dispatcher's silently-dropped
  gunflash/shiphit/shipdeath draws now render (found at port).
- **Verify:** `probe_tech.gd` — 9 checks (baseline invariance, derivation + modded-run determinism,
  XP/level curve + wave bonus, all four marquees behaviorally, spend rules, profile roundtrip on a
  probe-only path) — added to `verify.sh`. `ScreenshotC4` harness walks title → tree → sortie.

## C3 — WAVE DIRECTOR & FIRST ENEMIES · 2026-07-08 · Built

It's a game: enemies attack, the hull takes damage, runs end and restart. Full pipeline again —
interview (8 decisions) → approved spec → interactive mockup through two owner gate revisions
(MMB secondary-battery force-fire + radar scope; over-the-horizon main battery with proximity fuse
and radar fire-control bearing) → approval → Godot port verified side-by-side.

- **Sim:** `Waves.gd` — seeded budget director (base 6 + 4/wave threat points, costs swarmer 1 /
  gunboat 3 / bomber 5, unlock milestones 1/3/5, 1–3 cluster bearings, spawns beyond the view ring;
  discrete waves + lulls). `Enemies.gd` — divers pursue under per-type turn caps and pay themselves
  for hull contact; gunboats hold standoff, orbit, and fire led dodgeable shells. `Hull.gd` — pip
  pool (10) + 0.8s grace window, keel-capsule contact, run end freezing the war. `Turrets.gd` gains
  MMB medium-only force-fire, over-the-horizon forced splash shells (cursor = bearing, full-range
  flight), and — port fix, applied to the mockup reference too — intercept LEAD on auto-fire (no-lead
  fire could never hit an orbiting gunboat; waves stalled forever). `Projectiles.gd` gains hostile
  shells (hull capsule + grace) and the mb16 proximity fuse. Restart = fresh `GameWorld` seed (Main).
- **Retired:** the C2 practice range (owner decision) — `Drones.gd`, `Drone.gd`, `RangeConfig`,
  `range.tres` deleted; the turret probe suite re-targeted at hand-placed enemies.
- **Config:** `waves.tres` (director, hull pips/grace, radar range), `enemies.tres` (EnemyDef
  sub-resources). Roster ids await the naming pass (open thread #2).
- **Render/UI:** red enemy identity (darting swarmer delta / low gunboat hull with deck gun / heavy
  bomber wing), hostile orange shells, ship-hit rings, grace flicker on hull + pips, B-movie death
  blast with the wreck slipping under, wave plate (`WAVE N · CONTACTS: X` / lull countdown), radar
  scope with typed blips, incoming-fire sparks, viewport extent, main-battery ring, and the live
  fire-control bearing while force-firing; SHIP LOST card + `[R] NEW SORTIE`. Input map adds MMB +
  R. C2 LOOK-LOCK carried.
- **Verify:** `probe_waves.gd` (determinism through combat, exact budget spends [6,10,14,18,22,26],
  unlock milestones, lull timing, damage + grace, gunboat standoff/fire, run end + fresh-seed) and
  the re-targeted `probe_hardpoints.gd` (traverse, domain, policy, three force orders + release,
  fuse + trajectory, bloom) both gate in verify.sh. `probe_movement` isolates via a silenced
  director. `ScreenshotC3` harness replaces C2's.

## C2 — HARDPOINT HULL & GUNNERY RANGE · 2026-07-08 · Built

The hull grows teeth: visible hardpoints with real weapons, proven on a practice range. Full
pipeline again — owner interview (8 decisions) → approved spec → interactive mockup through THREE
owner gate revisions (hull ×1.7 then ×2.4; 6→4 small mounts with a blooming hose AA; class-distinct
turret art) → owner LOOK-LOCK ("if it doesn't look this good it doesn't get approved") → Godot port
verified side-by-side.

- **Sim:** three new systems in `Sim.step`'s fixed order behind Movement — `Drones.gd` (drifting
  air/surface practice targets, spawn/cull/respawn drawing 4 `world.rng` values per spawn in slot
  order), `Turrets.gd` (per-mount policy targeting CLOSE/STRONG, finite per-weapon traverse, bloom,
  hold-only force-fire: LMB all mounts with domain tags overridden, RMB large only; per-shot spread
  is the only draw), `Projectiles.gd` (pooled shells — `Pool`'s first real consumer — direct hits +
  splash bursts, kills/respawn). `GameWorld` gains mounts/drones/projectiles/kills and a one-way
  `effects` queue that Main plumbs to the renderer. `InputState` gains force flags + the WORLD-space
  cursor (Main converts; the sim never sees the screen). New `Configs` bundle keeps `Sim.step`'s
  signature flat as systems accumulate.
- **Config (per-system):** `hardpoint.tres` (10-mount plan 4S/4M/2L + fixed test loadout),
  `weapons.tres` (3-starter catalog as `WeaponDef` sub-resources: aa20 hose w/ bloom, dp5
  dual-purpose, mb16 splash battery), `range.tres` (practice-range shape).
- **Render/UI (LOOK-LOCK port of mockup rev 3):** battleship-scale hull (×2.4) with funnel/bridge/
  helipad/bow-jack; class-distinct turret art ON the hull (D1.5) — twin-barrel armored L turret with
  muzzle brakes + rangefinder ears on a hull-fixed barbette, angular single-gun M house with recoil
  sleeve, open-ring S AA mount — all with render-side recoil kick; drones, tracers, shells,
  muzzle/splash/death/hit effects; force-fire reticle with order label; BATTERIES line + kills plate
  in the HUD; LMB/RMB input map.
- **Verify:** `tests/probe_hardpoints.gd` (8 checks mirroring the mockup validation harness:
  determinism incl. force-fire, traverse ceiling, domain filter, policies, both force modes +
  release, kill/respawn, isolated splash kill, bloom rise/decay) as a new `verify.sh` step.
  `probe_movement` now runs with a drone-free range so its zero-RNG movement tripwire stays exact.
  `tests/ScreenshotC2.tscn` drives helm + force-fire under Xvfb for the side-by-side look check.
- **Decisions:** open thread #5 resolved; D1.7 refined (360° engagement, traverse-limited); D1.9
  domain tags are now live mechanics.

## C1 — NAVAL MOVEMENT · 2026-07-08 · Built

The first gameplay system, run through the full design-first pipeline in one day: `/spec-feature`
interview → owner-approved spec (`docs/specs/naval-movement.md`) → interactive HTML mockup
(`design/naval-movement.html`, owner-approved at the gate) → Godot port verified 1:1 against it.

- **Sim:** `scripts/engine/systems/Movement.gd` — system #1 in `Sim.step`'s fixed order. Held-key
  throttle (W ahead; S brakes harder than thrust and carries through the stop to a 35% astern cap),
  speed-coupled turn authority with a standstill floor, anisotropic exponential drag (long along-keel
  coast, visibly decaying lateral slip), heading-drives-velocity. Pure arithmetic, zero `world.rng`
  draws. `scripts/engine/data/InputState.gd` is the one-way input door (Main writes it pre-step);
  `GameWorld` gains `ship_vel` + `input`.
- **Config:** `config/MovementConfig.gd` + `movement.tres` (8 tunables, owner-approved anchors);
  `FieldConfig`/`field.tres` re-scoped from the retired C0 starfield to the sea field (grid, flecks,
  wake) — no dead config left behind.
- **Render/UI (1:1 mockup port):** `FieldRenderer` draws the chart grid, drifting foam flecks
  (toroidal tile, cosmetic RNG), world-anchored wake trail, and the battleship hull silhouette with
  deck hints; `scripts/render/patina.gdshader` ports the scanline/vignette overlay;
  `scripts/ui/HelmGauges.gd` is the gauge bank (engine order, way digits + bar, helm/authority,
  slip, heading) — the first piece of the future gauge-bank HUD. Camera stays north-up at 0.85 zoom.
- **Verify:** `tests/probe_movement.gd` runs the spec's acceptance checks headless (determinism with
  scripted input + zero-RNG tripwire, accel window, coast, brake/astern cap, turn floor, slip) as a
  new `verify.sh` step. Probe numbers match the mockup's JS validation exactly. `probe_sim` checks
  unchanged. `tests/ScreenshotC1.tscn` + `screenshot_c1.gd` is a dev harness (not gated) that drives
  the helm under Xvfb and saves a frame for mockup side-by-side checks.
- **Decisions:** D1.6's deferral resolved; D1.2 (Godot) reviewed at owner request and re-affirmed —
  HTML mockups stay the permanent design surface, Godot is the product.

## C0 — HEARTBEAT · 2026-07-08 · Built

Repo bootstrap from the owner-approved design brief (`docs/DESIGN-BRIEF.md`):

- Governance docs seeded: `DECISIONS.md`, `ARCHITECTURE.md`, `docs/SPEC.md`, `docs/HANDOFF.md`,
  `CLAUDE.md`, this changelog.
- Greenfield Godot 4.7 project (`project.godot`), re-deriving fulfillment's structural patterns rather
  than copying them (DECISIONS D1.3): seeded `Rng`, generic `Pool`, minimal `GameWorld` truth object,
  fixed-timestep `Sim` step root (no systems yet), `Main.gd`/`Main.tscn` accumulator loop, and a
  `FieldRenderer` that draws a placeholder hull + starfield to prove the sim→render loop is alive and
  one-way.
- Config split per-system from the start (`SimConfig`/`sim.tres`, `FieldConfig`/`field.tres`) instead
  of one monolithic balance file — a deliberate departure from fulfillment's ~300-line
  `BalanceConfig.gd`, so tuning any one future system (movement, hardpoints, sonar, …) only ever
  requires reading its own small config file.
- `verify.sh` gate (gdparse sweep / import / boot probe) + `tests/probe_sim.gd`.
- No gameplay systems yet — naval movement, hardpoints, domain-tagged weapons, sonar, and depth charges
  are each a future `/spec-feature` chunk.
