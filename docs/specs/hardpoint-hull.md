# Spec — C2: Hardpoint Hull & Gunnery Range

**Status:** APPROVED 2026-07-08 (owner) · Interviewed 2026-07-08 · Mockup pending (gate) · Not built
**Consumes:** DECISIONS.md open thread #5 (force-fire override + turret tracking — owner input at C1
mockup approval). **Builds on:** D1.5 (turret art ON the hull), D1.7 (360° auto-turrets), D1.9
(domain tags), D1.12 (one hull).

## Goal

Make the hull real: visible hardpoint positions carrying real weapons that track, fire, and kill —
proven on a gunnery range of drifting practice drones, not against a designed enemy wave. C1 gave the
ship weight; C2 gives it teeth and hands the player their second verb: **hold-to-force-fire**. The
turrets must read as heavy machinery on a heavy ship — finite traverse, one weapon class per mount
size — so that where you sail (C1) decides which guns bear soonest.

## Owner interview decisions (2026-07-08)

1. **Scope:** hardpoints + weapons + practice targets. No enemy AI, no return fire, no damage to the
   ship, no waves — those are later chunks.
2. **Tracking:** **finite traverse speed** per weapon class — turrets visibly swing to bear; large
   mounts slew slowest. This is the "thing to worry about": traverse feel is the chunk's core risk.
3. **Force-fire (hold, never toggle):** **LMB held = ALL mounts** slew to the cursor and fire when
   aligned — domain tags are overridden (you may strafe empty water; it's an order, not a suggestion).
   **RMB held = LARGE mounts only** (bombard the point). Release = instant return to auto-targeting.
4. **Auto-targeting: policy fixed per weapon type** (fulfillment's CLOSE/FAR/STRONG adapted), not
   per-mount and not player-assignable yet.
5. **Hull layout: 4 small / 4 medium / 2 large** — 2 large centerline (fore/aft), 4 medium at the
   beam, 4 small sponsons (fore + quarter pairs). Helipad stays clear (open thread #3).
   *Originally 6 small; owner cut to 4 at the mockup gate, compensating the AA with doubled fire
   rate, wider base spread, and a bloom mechanic (see catalog + gate revisions).*
6. **Catalog: 3 starters, one per size.** Sub-hunting weapons wait for the sonar chunk.
7. **Loadout: fixed test loadout in config** — every mount pre-filled. Purchase/economy is its own
   future interview.
8. **Targets: drifting dumb drones, air + surface layers**, respawning at range. A range, not a fight.

## Player-facing behavior

- The hull now carries **12 visible mounts**: turret bases with barrels that independently swing
  toward their targets at their class's traverse rate, fire with muzzle flashes, and go quiet when
  nothing is in range+domain. All art ON the hull (D1.5), rotating with it.
- **Practice drones** drift around the ship: air drones (fast, fragile) and surface drones (slow
  rafts, tougher). Killed drones splash/flash and a replacement spawns at range a moment later.
- **LMB held:** every barrel comes around to the cursor — small AA arrives first, the main battery
  swings in ponderously last — and fires on alignment. **RMB held:** only the two large turrets obey;
  the rest keep fighting their own targets. A cursor reticle shows the active order
  (`ALL GUNS` / `MAIN BATTERY`); release returns everything to auto.
- Weapons differ visibly: small = fast tracer streams (air-only); medium = steady dual-purpose shots
  (air + surface); large = slow heavy shells with a splash ring that kills in an area (surface-only,
  and the reason RMB area-denial works).

## Mechanics

- **Mount data:** mount layout (position on hull, size class) is config; runtime mount state
  (current barrel angle, cooldown, current target uid) lives on `GameWorld` in fixed index order.
- **New sim systems** (static `step(world, dt, cfg)`, appended to `Sim.step`'s fixed order after
  `Movement`):
  - `Drones.gd` — drift practice targets, respawn timers. Spawn position/heading/speed draw from
    `world.rng` in stable order (gameplay randomness — deterministic per seed).
  - `Turrets.gd` — per mount, in index order: pick target by the weapon's policy (or the forced
    cursor point), rotate barrel toward it clamped by `traverse rate × dt`, fire when aligned within
    a tolerance and cooldown elapsed. Per-shot spread draws from `world.rng`.
  - `Projectiles.gd` — pooled projectiles integrate, hit-test against drones (large shells splash on
    arrival at their target point). First real `Pool` consumers (drones + projectiles).
- **`InputState` grows:** `force_all: bool`, `force_large: bool`, `aim_world: Vector2`. Main converts
  the mouse cursor to world space render-side and writes it pre-step — the sim never touches camera
  or screen coordinates (one-way boundary unchanged).
- **Domain rule:** auto-targeting strictly filters by the weapon's domain tags (D1.9); force-fire
  overrides domain entirely (owner decision #3). Hull facing never gates firing (D1.7) — only
  traverse time does.
- **Render:** turret bases/barrels drawn on the hull per mount angle; tracers, muzzle flashes, splash
  rings, drone silhouettes (air reads winged/light, surface reads raft/dark), hit flashes — all
  render-side cosmetics reading the world one-way. HUD adds the force-fire reticle only.

## Config (per-system rule — three small new files)

**`config/HardpointConfig.gd` + `hardpoint.tres`** — the hull's mount plan: 12 entries
`(local position, size class)` + the fixed C2 test loadout (`mount → weapon id`), barrel lengths per
class, alignment tolerance.

**`config/WeaponConfig.gd` + `weapons.tres`** — the catalog (start values, owner tunes by feel):

| id | size | domains | policy | range | fire rate | traverse | dmg | proj. speed | spread | splash |
|---|---|---|---|---|---|---|---|---|---|---|
| `aa20` "Vigilant" | small | air | CLOSE | 420 | 12.0/s | 4.0 rad/s | 1 | 700 | 0.045 + bloom | — |
| `dp5` "Sentinel" | medium | air+surface | CLOSE | 560 | 1.2/s | 2.2 rad/s | 2 | 620 | 0.02 | — |
| `mb16` "Judgement" | large | surface | STRONG | 900 | 0.33/s | 0.9 rad/s | 4 | 420 | 0.012 | 36 |

**Bloom (AA texture, owner gate revision):** sustained fire widens a mount's spread by `bloom_add`
(0.01 rad) per shot up to `bloom_max` (0.10 rad); the cone tightens at `bloom_decay` (0.06 rad/s)
whenever the gun isn't firing. Pure per-mount arithmetic — no RNG state; only the per-shot spread
draw touches `world.rng`, exactly as before. `dp5`/`mb16` carry the fields at 0.

**`config/RangeConfig.gd` + `range.tres`** — the practice range: 4 air + 3 surface drones concurrent,
spawn ring 500–1000 u, drift 20–45 u/s, respawn delay 2.0 s, HP air 1 / surface 3.

## Visual spec (mockup gate: mock → approve → port)

`design/hardpoint-hull.html` — extends the approved C1 mockup (same sea, hull, gauges, patina; same
movement model underneath) with: the 12 mounts and their traversing barrels, the 3 weapon classes
firing, drifting air/surface drones with kills and respawns, LMB/RMB hold force-fire with the
reticle, and a tuning drawer for the weapon/range tables. Owner judges by hand — especially traverse
feel (decision #2) and the two force-fire orders — then approves; then it ports.

**Gate revision (owner, 2026-07-08):** first cut approved on feel ("love the feel") but the hull was
too small for its turrets. Hull upscaled ×1.7 (~150 u overall) with the mount plan re-laid for real
deck room; the C2 port must carry this hull scale into `FieldRenderer` (C1's silhouette proportions,
new size — wake stern offset and deck furniture scale with it).

**Gate revision 2 (owner, 2026-07-08):** small mounts cut 6 → 4 (fore + quarter pairs; layout is now
4S/4M/2L). The AA compensates as a hose: fire rate 6 → 12/s, base spread 0.035 → 0.045, plus the
bloom mechanic above. Acceptance gains check 9 (bloom rises under sustained fire, decays at rest).

## Determinism notes

- Drone spawns/drift and per-shot spread are **gameplay randomness → `world.rng`**, drawn in stable
  order (drones by pool index, mounts by mount index). Same seed + same scripted input (including
  cursor) ⇒ same run, same `rng.calls`.
- Traverse, target selection, and projectile flight are pure arithmetic — no draws.
- Muzzle flash/splash/tracer jitter are render-side cosmetics — own RNG, never the sim's.

## Acceptance checks (`tests/probe_hardpoints.gd`; new `verify.sh` step)

1. **Determinism:** two worlds, same seed, same scripted input (sail + force-fire at a scripted
   cursor), 1200 ticks → identical world state and identical `rng.calls`.
2. **Traverse limit:** no mount's barrel angle ever changes faster than its weapon's traverse rate.
3. **Domain filter:** with only a surface drone in range, `aa20` mounts never fire in auto; `dp5` and
   `mb16` do.
4. **Policy:** with a near-weak and a far-tough drone both in range, `dp5` (CLOSE) engages the near
   one while `mb16` (STRONG) engages the tough one.
5. **Force-fire:** LMB-hold slews ALL mounts toward the cursor point (domain ignored) and they fire
   only once aligned within tolerance; RMB-hold moves large mounts only; release resumes auto within
   a tick.
6. **Kill & respawn:** a drone at 0 HP deactivates (pool release) and a replacement spawns after the
   configured delay; concurrent counts hold.
7. **Splash:** an `mb16` shell kills a drone it never directly hit when inside splash radius.
8. **Bloom:** sustained `aa20` fire drives mount bloom toward `bloom_max`; after a few seconds of
   rest it decays back to zero.
9. Existing `probe_sim` + `probe_movement` checks still pass unchanged.

## Out of scope (explicit cuts from the interview)

- Enemy AI, return fire, ship damage/hull pips, waves/spawn director.
- Purchase economy / loadout UI — mounts come pre-filled from config (own future interview).
- Sub-domain weapons, sonar, depth charges (sonar chunk).
- Ammo/magazine management — fire rate only for C2; revisit with combat chunks.
- Per-mount player-assignable policies (future loadout chunk).

## DECISIONS.md impact

No conflicts with locked decisions. At implementation time: log resolution of open thread #5 (its
force-fire/tracking questions are answered here), note that D1.7's "360° auto-turrets" now reads as
"360° eventually — traverse-rate-limited" (a refinement, not a reversal), and add the three new
config files to the per-system list. D1.9's domain tags become live mechanics.
