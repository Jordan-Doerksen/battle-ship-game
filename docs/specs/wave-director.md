# Spec — C3: Wave Director & First Enemies

**Status:** APPROVED 2026-07-08 (owner) · Interviewed 2026-07-08 · Mockup pending (gate) · Not built
**Builds on:** C1 movement (dodging is piloting), C2 hardpoints (the guns finally have a war),
D1.8 (single hull pool, pip-style), D1.9 (domain tags). **Retires:** the C2 practice range (owner
decision — waves replace it; no dead mechanics left behind).

## Goal

Make it a game: real enemies that attack from air and surface, a hull that takes damage, and a run
that can end. The gunnery range proved the guns; C3 gives them a war — waves of remote-piloted alien
drones arriving from beyond the horizon, composed by a seeded **budget director** so every wave is a
fresh-but-fair spend of threat points. Survive the wave, breathe through the lull, meet a bigger
budget. When the hull gives out, the run ends on a card and a fresh seed starts.

## Owner interview decisions (2026-07-08)

1. **Discrete waves + lulls.** A wave spawns, you fight it down to zero contacts, a lull follows
   (future shop window), the next wave hits harder.
2. **Roster of 3** (air + surface only — subs wait for the sonar chunk): air **swarmer** (fast,
   fragile, dives into the hull), surface **gunboat** (keeps standoff, lobs dodgeable shells), air
   **bomber** (slow, tanky, heavy contact hit).
3. **Mixed threat model:** swarmers/bombers damage by reaching the hull; gunboats fire projectiles
   you can steer away from. C1 piloting and C2 gunnery both matter.
4. **Hull: 10 pips + brief post-hit grace window** (invulnerability ~0.8 s) so a swarm pile-on can't
   chain-delete the ship. Pip-style per D1.8; no per-hardpoint damage.
5. **Budget director:** each wave gets a point budget spent across unlocked types with seeded
   variance — composition varies run to run on the same knobs (and is identical on the same seed).
6. **Score = waves survived + kills.** No currency yet — an earn-only salvage number would be a dead
   mechanic until the economy chunk lands.
7. **Naturalistic arrival:** enemies spawn beyond the detection edge and physically sail/fly in.
   No warp-in telegraph; seeing a formation approach at range IS the warning.
8. **The practice range retires.** Drones, `RangeConfig`, and `range.tres` are removed; the turret
   acceptance checks re-target hand-placed enemies. Waves are the game now.

## Gate revision 1 (owner, 2026-07-08 — at the mockup)

- **MMB (scroll-wheel click) force-fires the MEDIUM battery** at the cursor, hold-only, exactly like
  LMB (all) and RMB (large). Orders combine: RMB+MMB = main + secondary on point while the AA keeps
  fighting its own war. Extends the C2 force-fire design (open thread #5's resolution); the Godot
  port maps it to `MOUSE_BUTTON_MIDDLE`.
- **Radar scope** (bottom-right, circular): north-up, ship-centered, ~2200 u range — covers the
  spawn ring so approaching formations are visible before they reach the screen ("with boat
  mechanics, ranged attackers are a serious threat" — planning tool, not decoration). Shows enemy
  blips by type/layer, incoming hostile shells, the current viewport extent, and the main-battery
  range ring. This is the fulfillment `RadarView` analog arriving early; the sonar chunk (D1.10)
  later gates SUB blips by detection radius — air/surface blips are free, as here. Render-side
  one-way read; scope range lives in config (`radar_range`, future sonar config's neighbor).

## Player-facing behavior

- A run starts at **WAVE 1**: a small formation of swarmers appears at long range and bores in. The
  wave plate reads `WAVE 1 · CONTACTS: 4`. Kill everything → `WAVE CLEARED` → a lull countdown →
  the next, bigger wave arrives from new bearings.
- **Gunboats** (wave 3+) stop at standoff range and shell you — incoming rounds are visible, slow
  enough to dodge with way on, and hurt if you sit still. **Bombers** (wave 5+) are the AA triage
  test: big, slow, and 2 pips if one reaches you.
- **Hull pips** (10) live on the gauge plate. A hit flashes the hull and knocks a pip; for a beat
  afterward (grace window) the ship shrugs off further hits — visible as a flicker.
- At 0 pips the ship dies on screen (B-movie explosion — flash, ring, sinking silhouette) and the
  run-over card slams in: `SHIP LOST — WAVE N · K DRONES DESTROYED — [R] NEW SORTIE`. Restart
  begins a fresh seed instantly.
- Turrets, policies, force-fire, and handling are exactly C2/C1 — now aimed at things that fight back.

## Mechanics

- **New entity `Enemy.gd`** (pooled): type id, layer (air/surface), pos/vel/heading, hp, fire
  cooldown. **`Drone.gd` and the range retire.**
- **New sim systems** (fixed order after `Movement`, replacing `Drones`):
  - `Waves.gd` — the director. States: `spawning → fighting → lull → spawning…`. At wave start it
    spends the wave's budget with `world.rng` draws (type choice among unlocked, cluster bearings,
    per-enemy ring position/phase), spawning enemies beyond the view ring. Wave clears when all
    enemies die; lull timer then arms the next wave. All draws in one defined order.
  - `Enemies.gd` — per-type movement in slot order: swarmers/bombers pursue the ship with a per-type
    turn-rate cap; gunboats approach to standoff, then orbit tangentially and fire at their period
    (aim = ship pos + `lead` × ship vel × flight time, plus seeded spread — dodgeable by design).
    Contact hits test the hull **capsule** (keel segment ± beam radius).
  - `Turrets.gd`/`Projectiles.gd` re-target enemies (same policies, domains, traverse, bloom).
    `Projectile` gains `hostile: bool`; hostile shells test the hull capsule + grace instead of
    enemies. Friendly splash ignores air, as before.
  - `Hull.gd` — damage intake, grace window, pips, and run end: at 0 pips `world.run_over = true`;
    systems stop stepping enemies/turrets; Main shows the card and restarts on input with a new seed.
- **`GameWorld` gains:** `enemies` (pool), `hull` (pips), `grace_until`, `wave` (number), 
  `wave_state`, `lull_until`, `run_over`. Drone fields retire.
- **HUD:** hull pip row on the gauge plate; the top-left plate becomes the wave plate
  (`WAVE N · CONTACTS: X` / `WAVE CLEARED — NEXT IN 0:06`); run-over card. Kills stay.

## Config (per-system rule — two new files; `RangeConfig`/`range.tres` deleted)

**`config/WaveConfig.gd` + `waves.tres`** — the director:

| Tunable | Start | Meaning |
|---|---|---|
| `base_budget` | `6` | wave 1 threat points |
| `budget_per_wave` | `4` | added points per wave |
| `lull_secs` | `8.0` | breather between waves |
| `spawn_ring_min/max` | `1700 / 2000` | arrival distance (beyond view) |
| `cluster_min/max` | `1 / 3` | attack bearings per wave (seeded) |
| `costs` | swarmer 1 · gunboat 3 · bomber 5 | budget prices |
| `unlock_wave` | swarmer 1 · gunboat 3 · bomber 5 | first wave each type may appear |
| `hull_pips` | `10` | run health |
| `grace_secs` | `0.8` | post-hit invulnerability |

**`config/EnemyConfig.gd` + `enemies.tres`** (`EnemyDef` sub-resources, like weapons):

| id | layer | hp | speed | turn | contact dmg | radius | notes |
|---|---|---|---|---|---|---|---|
| `swarmer` | air | 2 | 115 | 2.2 | 1 | 9 | dives the hull |
| `gunboat` | surface | 5 | 65 | 1.2 | — | 14 | standoff 500, fire range 700, period 4.0 s, shell speed 150, dmg 1, lead 0.6, spread 0.05 |
| `bomber` | air | 8 | 45 | 0.5 | 2 | 16 | AA triage test |

Hull capsule: keel half-length 85, radius 26 (matches the ×2.4 silhouette). Display names for the
roster wait on open thread #2 (B-movie naming pass) — ids are mechanical placeholders.

## Visual spec (mockup gate: mock → approve → port)

`design/wave-director.html` — extends the LOOK-LOCKED C2 mockup (same hull, turrets, sea, gauges):
1. the three enemy silhouettes (swarmer: small darting delta; gunboat: low dark hull with a gun
   flash; bomber: broad heavy delta) approaching from beyond the edge,
2. hostile shells visibly incoming (distinct hot color) and dodgeable at speed,
3. hull pips draining, hit flash + grace flicker, B-movie death blast, run-over card + restart,
4. the wave plate rhythm: contacts counting down, lull countdown, next wave arriving on new bearings,
5. a tuning drawer for the wave/enemy tables.
Owner judges wave rhythm, threat readability, and dodge feel hands-on; approves; then it ports.
The C2 LOOK-LOCK carries: everything already locked must still look that good with a war on screen.

## Determinism notes

- Director spends (type picks, cluster bearings, spawn positions) and gunboat spread are gameplay
  randomness → `world.rng`, drawn in a single defined order (director first, then per-slot).
- Enemy steering, contact tests, hull damage, grace, and wave state are pure arithmetic.
- Restart constructs a fresh `GameWorld` with a new seed (Main's job) — same seed ⇒ same run holds
  for the entire wave sequence.

## Acceptance checks (`tests/probe_waves.gd` + probe_hardpoints re-targeted; verify.sh steps)

1. **Determinism:** 3600 scripted ticks (sail + fight) → two worlds byte-identical (wave, hull,
   enemies, kills, rng.calls).
2. **Budget honored:** each spawned wave's cost sum ≤ its budget, and within one max-cost of it (the
   director spends greedily); no type appears before its unlock wave.
3. **Wave lifecycle:** clearing all enemies enters the lull; lull lasts `lull_secs`; the next wave
   number is +1 with a fresh spend.
4. **Damage + grace:** a scripted contact costs exactly 1 pip; a second contact inside `grace_secs`
   costs nothing; one after it costs again.
5. **Gunboat behavior:** never closes far inside standoff; fires on period; its shell can strip a
   pip from a stationary ship.
6. **Run end + restart:** hull 0 → `run_over`, enemies/turrets freeze; a fresh world on a new seed
   runs clean.
7. **Turret suite retained:** probe_hardpoints' checks (domain filter, policies, force-fire modes —
   now including MMB medium-only and RMB+MMB combining — splash, bloom, traverse ceiling) pass
   against hand-placed enemies.
8. **probe_sim / probe_movement pass unchanged** — movement isolates by running with a zero-budget
   director (no spawns ⇒ zero draws, the C1 tripwire stays exact).

## Out of scope (explicit cuts from the interview)

- Subs, sonar, depth charges (C4 candidate — completes the three domains).
- Purchase economy / salvage currency (own chunk; lulls are its future shop window).
- Boss ladder / motherships and the enemy NAMING pass (open thread #2 stays open).
- Difficulty modes, daily seeds UI (determinism already supports them), meta-progression.
- Enemy-vs-terrain, formations beyond bearing clusters, retreat behavior.

## DECISIONS.md impact

No conflicts. At implementation time: D1.8 gains a refinement note (grace window is a hull-pool
behavior, not a second health layer); the C2 range retirement is logged (Drones/RangeConfig removed
— superseded surface, not silent deletion); Build Timeline gains C3. Open threads #1–#4 remain open;
#2 (naming) is now the nearest one the game visibly wants.
