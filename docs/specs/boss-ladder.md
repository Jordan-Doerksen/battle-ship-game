# Spec — C7: The Boss Ladder & the Naming Pass

**Status:** BUILT 2026-07-09 · Spec + mockup APPROVED 2026-07-09 (owner — `design/boss-ladder.html`
stays the visual reference) · Gated by `tests/probe_bosses.gd` in `verify.sh`. Mockup-build tune:
THE CANOPY core 35 → 50 (at 35 the default batteries melted it in ~8 s). Owner tune at the port:
the stern racks throw a K-GUN SPREAD around the beams and stern (see `docs/specs/sonar-subs.md`
`dc_ring` and the Change Log).
**Resolves:** open thread #2 (boss ladder & enemy roster naming — the last founding thread with
systems weight). Fulfillment's title-ladder escalation is the reskinnable ancestor (brief §7);
this is its B-movie replacement.

## Goal

Give the war a face and the roster its names. Every 5th wave the operators stop hiding behind
drones and send one of their OWN machines — a huge, named, multi-part war vessel that arrives with
an escort wave and dominates the screen until it dies. Three machines tour your three domains;
the ladder repeats forever, harder each lap. And the whole roster finally gets its reporting
names, newsreel-straight: the age of "swarmer/gunboat/bomber/sub" placeholders ends.

## Owner interview decisions (2026-07-09)

1. **Mothership war machines.** Bosses are the invaders' own vessels — huge, named,
   screen-dominating machines, one per rung, arriving WITH a normal (reduced) wave as escort.
   Not reskinned drones.
2. **Parts AND phases.** Machines have destructible PARTS with their own hp; part losses trigger
   phase changes and minion spawns; the core is what you're really after.
3. **Endless, recurring ladder.** No win screen — the ladder cycles upward forever, scaled per
   lap. The career (XP/tree) stays the long game.
4. **EDF reporting names.** Drones get military reporting names off the newsreel; machines get
   THE-prefixed designations. Propaganda-poster earnest, played straight.
5. **Every 5th wave, 3 rungs.** Waves 5/10/15 = the three machines; wave 20 starts lap 2 (same
   ladder, scaled). A machine every ~4–6 minutes.
6. **The domain tour.** Rung 1 surface, rung 2 air, rung 3 the deep — each machine examines a
   different pillar of the player's kit (main battery / FLAK / the whole ASW game).
7. **Soft-gated cores.** The core always takes SOME damage (25%) but full damage only once every
   part is destroyed — brute force works, the tour of the hull is faster.
8. **Set A names.** GNAT (swarmer) · JACKAL (gunboat) · VULTURE (bomber) · LAMPREY (sub) ·
   **THE JUGGERNAUT** (surface) · **THE CANOPY** (air) · **THE MAW** (deep).
9. **THE MAW breach-cycles.** Submerged: a huge sonar contact stalking you, torpedo fans, only
   racks + the bird can hurt it. Then it BREACHES — surfaces monstrous, parts exposed to the
   batteries — and dives again. The dive/breach rhythm IS its phase structure.
10. **Rewards: bounty + hull patch.** Each destroyed part banks XP on the spot; the core kill
    pays a big lap-scaled bounty AND patches 2 hull pips — the survival loop's first breather.

## The machines (first-lap numbers — tunables, `bosses.tres`)

| | THE JUGGERNAUT (wave 5) | THE CANOPY (wave 10) | THE MAW (wave 15) |
|---|---|---|---|
| Domain | surface | air | sub, breaching to surface |
| Core hp | 40 | 50 (35 at draft; raised at mockup build) | 45 |
| Speed / brain | 30 u/s, standoff 550 orbit | 55 u/s, wide orbit 480 | 45 u/s stalk, standoff 500 |
| Parts (hp) | fore turret (10), aft turret (10), fire director (8) | port bay (9), stbd bay (9), drone hive (10) | 3 vent cowls (8 each), exposed only while breached |
| Attacks | led heavy shells per turret (dmg 1, period 3 s); +30% rate when the director dies (it panics) | bays lob arcing bombs at your position (splash, dmg 2, period 5 s); hive spawns 3 GNATs per period | submerged: 3-torpedo fan (C5 torpedoes) per period 9 s; breached: nothing — it's VENTING |
| Phases | each part loss: +10 speed, spawns 2 GNATs | each part loss: remaining periods −25%, spawns 2 VULTUREs on hive death | breach cycle: 20 s down / 8 s up; each cowl destroyed extends breach +2 s (it can't seal) |
| Counterplay check | main battery duel, splash vs its escorts | FLAK + dp5 (mb16 is surface-only — the air fortress laughs at your big guns) | the full C5/C6 kit: sonar ring, stern racks, the bird marking; batteries only in the breach window |

- **Soft gate:** core damage ×0.25 while ANY part lives; ×1.0 after. THE MAW's core is
  additionally only touchable by ASW while submerged (deaf-deep law holds — it IS a sub) and by
  everything while breached.
- **Escort:** a boss wave also runs the normal director spawn at **50% budget** (tunable) — the
  machine arrives with outriders, not alone.
- **Lap scaling:** every completed lap multiplies machine core/part hp ×1.5 and attack damage +0
  (hp first; damage scaling reconsidered when a lap actually falls).
- **Lifecycle:** a boss wave clears only when the machine AND its escort are dead; the wave-clear
  bonus then applies as usual, on top of the bounty.
- **Rewards:** part kill = 60 XP each, on the spot. Core kill = 250 XP × lap number, plus
  **+2 hull pips** (capped at max). Banked via the C4 XP path — nothing new in the profile.

## The naming pass

- `EnemyDef` gains `display_name`: GNAT / JACKAL / VULTURE / LAMPREY. **Type ids stay mechanical**
  (`swarmer`/`gunboat`/…) — determinism, config paths, probes, and tech mods are untouched. This
  is a presentation layer, per D1.4's spirit: names change nothing about a run.
- Names go LIVE in the HUD (no dead data): the wave plate's contact line becomes a reporting-name
  tally during a fight (`WAVE 3 · GNAT ×3 · JACKAL ×2`), and the SHIP LOST card counts kills the
  same way. The dev kit keeps mechanical labels (debug tool, not diegesis).
- Machines announce themselves: a **PRIORITY TARGET** plate (top center) with the THE-name, core
  bar, and part pips for the duration of the fight, plus an arrival klaxon effect and a
  distinctive oversized radar blip.

## Mechanics (build shape)

- **`BossConfig.gd` + `bosses.tres`** (per-system rule): cadence (`every_n: 5`), escort budget
  fraction, lap hp multiplier, and three `BossDef` sub-resources (stats + parts tables + phase
  tunables above).
- **`Bosses.gd`** (new system, stepped with/inside the wave flow): owns the single active machine —
  movement brain, part positions (hull-relative, rotating with its heading), attack/phase clocks,
  breach cycle. Parts and core are hit-tested by the EXISTING projectile paths: they register as
  pseudo-entries the turrets can target (domain-tagged per machine), so targeting policies, lead,
  splash, and the deaf-deep law all apply unchanged. The soft gate lives in the boss damage
  intake, not in Projectiles.
- **`Waves.gd`**: every `every_n`-th wave spawns the next rung's machine (+ 50%-budget escort)
  instead of a plain wave; wave-clear waits for machine + escort.
- All boss randomness (attack spreads, spawn bearings) draws from `world.rng` in fixed order —
  same law as everything else. The ladder sequence itself is deterministic (wave number → rung).

## Visual spec (mockup gate: mock → approve → port)

`design/boss-ladder.html` — extends the approved C6 mockup: all three machines (each a distinct
multi-part silhouette ~3–5× a gunboat with visibly destructible parts), the PRIORITY TARGET
plate, arrival klaxon, reporting-name wave plate, THE MAW's breach drama (huge ripple → foam
eruption → monstrous hull), dev-kit `+BOSS 1/2/3` buttons. Owner judges each machine's menace,
the part-shooting feel, the breach window tension, and whether the names sing; approves; ports.

## Acceptance checks (`tests/probe_bosses.gd`; verify.sh step)

1. **Determinism:** a full boss fight (parts, phases, minions, kill) → two worlds byte-identical.
2. **Cadence + ladder:** waves 5/10/15 field the right machines; waves 1–4 are byte-identical to
   pre-C7; wave 20 fields THE JUGGERNAUT again at ×1.5 hp (lap 2).
3. **Soft gate:** core takes 25% damage while a part lives, 100% once parts are gone.
4. **Parts + phases:** each part death banks 60 XP and fires its phase change (speed/rate/minions).
5. **Domain tour:** mb16 shells cannot touch THE CANOPY (air tags); nothing but ASW touches THE
   MAW submerged; its parts take gunfire only while breached.
6. **Rewards:** core kill pays 250 × lap XP and patches exactly +2 pips, capped at hull max.
7. **Lifecycle:** the boss wave clears only when machine + escort are dead; lull + wave bonus
   follow as normal.
8. **Names:** every roster entry and machine carries a display_name; the HUD tally renders them
   (no dead data).
9. Existing probes pass unchanged.

## Out of scope (explicit cuts from the interview)

- A win condition / final rung (endless by owner decision #3; revisit as its own chunk if ever).
- New drone types (the four reporting names cover the existing roster; new minions reuse them).
- Water-mystery narrative framing (open thread #1) and the working-title decision (thread #4).
- Boss-specific tech-tree branches or loot beyond XP + the hull patch.

## DECISIONS.md impact

At build time: resolve open thread #2 (this spec); the naming pass supersedes the "mechanical
placeholder names" notes in EnemyDef/Enemy comments; D1.9's domain law and the deaf-deep physical
rule extend to machines unchanged (THE MAW is probe-gated on it). D1.8 (single hull pool) is
REFINED, not superseded: the +2-pip patch is a reward event, not a second health system.
