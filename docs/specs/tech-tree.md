# Spec — C4: Levels & Tech Tree

**Status:** APPROVED 2026-07-08 (owner) · Interviewed 2026-07-08 · Mockup pending (gate) · Not built
**Implements:** the 2026-07-08 Change Request (set hulls/turrets; persistent levels unlock a tech
tree — replaced the purchasable-hardpoint economy). **Builds on:** every tunable the tree modifies
already living in per-system `.tres` configs — the tree is config modification, by design.

## Goal

Give the war a career. Every sortie banks XP (kills + wave bonuses — dying loses nothing); XP earns
persistent LEVELS; each level grants a tech point spent on a branching TECH TREE that makes the
next sortie's ship measurably yours: faster keel, tighter flak, harder-hitting guns, and one
showpiece effect at the end of every branch. The helicopter branch is on the board but CLASSIFIED —
its function gets its own interview. This chunk also builds the game's first out-of-run home: a
briefing-room title screen.

## Owner interview decisions (2026-07-08)

1. **XP = kills (by enemy type) + wave-clear bonuses.** Everything earned is kept on death.
2. **Tree shape: branches off a core** — SEAMANSHIP (movement), FLAK (small mounts), GUNNERY
   (medium), ORDNANCE (large + shells), AIR WING (helicopter — visible, locked). Linear
   prerequisites within a branch.
3. **1 tech point per level; node costs vary** (small stat nodes 1, mid nodes 2, marquee 3).
4. **Free respec between runs** — points refund fully at the tree screen, never mid-run. Levels are
   the permanent thing; the build is fluid.
5. **C4 scope: 4 live branches × 6 nodes (~24 real nodes)** + the locked AIR WING.
6. **Node content: meaningful stat mods + ONE marquee effect per branch tip** (bullet effects are
   the headline).
7. **Home: title hub** — BEGIN SORTIE / TECH TREE — plus a TECH TREE shortcut and XP report on the
   SHIP LOST card.
8. **Helicopter parked as "AIR WING — ████ CLASSIFIED ████"**, redacted B-movie flavor ("PENDING
   BUREAU AUTHORIZATION"), designed later in its own interview (open thread #3 continues).

## Player-facing behavior

- **In-run:** the wave plate gains a small running `XP +N` tally. Nothing else changes mid-run — no
  mid-run spending (owner decision #4/#7).
- **SHIP LOST card** now reports the sortie: `WAVE 6 · 42 DRONES DESTROYED · +1,240 XP` plus
  `LEVEL UP → 7` when crossed, and offers `[R] NEW SORTIE · [T] TECH TREE`.
- **Title screen** (first boot home): EDF propaganda-poster treatment, `BEGIN SORTIE` / `TECH TREE`,
  current level + XP bar.
- **Tech tree screen:** five branch columns on a plotting-board plate; nodes show name, cost, and
  effect; buying lights the node and updates the points counter; RESPEC refunds everything; AIR
  WING renders redacted and unbuyable. Effects apply to the NEXT sortie.

## The tree (start values — all tunable in `tech.tres`)

Within a branch, nodes unlock strictly in order. Costs: tier 1–3 = 1 pt, tier 4–5 = 2 pts,
marquee = 3 pts (10 pts per branch, 40 total = the long game).

**SEAMANSHIP** — 1 Trim Ballast (+10% max speed) · 2 Keel Shave (+15% turn rate) · 3 Engine
Overhaul (+20% thrust accel) · 4 Hard Rudder (turn floor 0.25→0.40) · 5 Sea Legs (+2 hull pips) ·
6 **CRASH TURN** (marquee): ordering EMERGENCY BACK above 70% speed grants ×1.8 turn rate for 3 s
(10 s cooldown) — the battleship snaps around once, when it matters.

**FLAK** — 1 Gun Oil (+15% aa20 fire rate) · 2 Tight Chokes (−25% aa20 base spread) · 3 Rapid
Traverse (+25% S traverse) · 4 Cooling Jackets (−40% bloom gain) · 5 Extended Belts (+15% aa20
range) · 6 **INCENDIARY LOAD** (marquee): aa20 hits ignite air enemies — 3 damage over 3 s
(burning drones trail flame; the swarm melts).

**GUNNERY** — 1 Calibrated Sights (−30% dp5 spread) · 2 Power Rammer (+25% dp5 fire rate) ·
3 Fast Slew (+25% M traverse) · 4 Long Barrels (+15% dp5 range & shell speed) · 5 Heavy Shells
(+1 dp5 damage) · 6 **PROXIMITY BURST** (marquee): dp5 shells airburst near air enemies — 20 u
radius flak cloud (the secondaries become true dual-purpose).

**ORDNANCE** — 1 Turret Gearing (+30% L traverse) · 2 Bigger Charges (+15% mb16 range) · 3 Wide
Bursting (+25% splash radius) · 4 Fire Control (−50% mb16 spread) · 5 Fast Reload (+30% mb16 fire
rate) · 6 **FULL SALVO** (marquee): both barrels fire — 2 shells per trigger with a small angular
offset (the twin-barrel art finally tells the truth).

**AIR WING** — ████████ (5 redacted nodes, locked; helipad art already on the hull).

## XP & levels (start values — `config/ProgressConfig.gd` + `progress.tres`)

| Tunable | Start | Meaning |
|---|---|---|
| `xp_swarmer / xp_gunboat / xp_bomber` | 10 / 30 / 50 | per kill |
| `xp_wave_bonus` | 25 | × wave number, on each clear |
| `level_xp_base` | 150 | XP for level 1 |
| `level_xp_step` | 100 | added per subsequent level (linear ramp) |

A decent early run (wave ~6) ≈ 1,000–1,300 XP ≈ 4–5 levels — the tree opens fast, finishes slow.

## Mechanics

- **Profile persistence (new, meta layer):** `scripts/app/Profile.gd` — level, XP, unlocked node
  ids — saved to `user://profile.cfg`. The FIRST save file. Strictly outside the sim: the sim never
  reads the profile; it reads configs.
- **Tech application = config derivation.** At sortie start, Main builds the run's `Configs` by
  deep-copying the `.tres` values and applying the unlocked nodes' modifiers
  (`Tech.apply(cfgs, unlocked)`) — multipliers/adders on existing tunables, in node-id order.
  Same unlock set ⇒ same derived configs ⇒ determinism per (seed, build) holds.
- **Marquee effects are sim features behind config flags** (each defaults OFF = exact pre-C4
  behavior): burn DoT on `Enemy` (Enemies.step ticks it), dp5 air-burst (Projectiles: proximity
  fuse vs air with small AoE), mb16 twin salvo (Turrets: second projectile at an angular offset),
  crash-turn window (Movement: conditional turn-rate multiplier + cooldown on `GameWorld`).
- **XP accounting in-sim:** `world.xp_run` accrues from kills/wave clears (pure arithmetic, derived
  from existing deterministic events — no new draws). Main banks it into the Profile at run end.
- **`config/TechConfig.gd` + `tech.tres`:** the node catalog (`TechDef` sub-resources: id, branch,
  tier, cost, display name/desc, stat mods dictionary, marquee flag). `ProgressConfig` holds the XP
  table. Per-system config rule holds — tech/progress get their own files; modified values still
  live in their home configs.
- **UI:** `TitleScreen` and `TechTreeScreen` (new `scripts/ui/` scenes, plate/brass language),
  wave-plate XP tally, lost-card XP report. Scene flow: Title → game → lost card → tree/restart.

## Visual spec (mockup gate: mock → approve → port)

Two-part mockup, one page: `design/tech-tree.html` —
1. the **title hub** and the **tech tree screen** fully interactive (fake profile: grant-XP button,
   level bar, buy/refund every node, respec, AIR WING redacted),
2. a **SORTIE button that launches the existing wave-director game** with the purchased tech
   applied, so every stat node and all four marquee effects are FELT, not read — incendiary trails,
   airbursts, full salvos, crash turns. XP earned in the mock sortie feeds the fake profile: the
   whole loop, in the browser.
Owner judges the loop (earn → level → spend → feel it next sortie), tree readability, and each
marquee; approves; then it ports. C2/C3 look stays LOOK-LOCKED.

## Determinism notes

- The tree changes CONFIG VALUES before the sim starts, never sim state mid-run. Same seed + same
  unlock set ⇒ same run. `rng` draw order is unchanged by stat mods; marquee features add draws
  ONLY where specified (none — burn/airburst/salvo/crash-turn are pure arithmetic).
- Profile I/O happens in Main/UI (app layer) only.

## Acceptance checks (`tests/probe_tech.gd`; verify.sh step)

1. **Baseline invariance:** with zero nodes unlocked, derived configs equal the `.tres` values and
   all existing probes' behaviors are unchanged.
2. **Derivation determinism:** same unlock set applied twice ⇒ identical configs; a modded run is
   byte-identical across two worlds on one seed.
3. **XP accounting:** a scripted run's kills/waves produce the exact XP sum and correct level-ups
   at the curve thresholds.
4. **Marquees:** burn DoT finishes a swarmer after ignition; a dp5 airburst damages an air enemy it
   never touched; FULL SALVO emits exactly 2 shells per trigger; CRASH TURN multiplies turn rate
   only inside its window and honors its cooldown.
5. **Spend/respec:** buying respects order + costs + points; respec refunds everything; AIR WING
   rejects purchase.
6. **Profile roundtrip:** save → load restores level/XP/unlocks exactly.

## Out of scope (explicit cuts from the interview)

- The helicopter's actual function (own interview; branch stays CLASSIFIED).
- Sonar/subs/depth charges (still the other C4 candidate — order decided after this spec).
- Prestige/reset systems, achievements, difficulty modes, per-run (in-run) upgrades.
- Enemy naming pass (open thread #2).

## DECISIONS.md impact

Implements the 2026-07-08 Change Request. At implementation time: log the tree as the game's meta
axis, note the first save file (`user://profile.cfg`), and record that marquee flags default OFF so
the pre-C4 sim is the zero-tech baseline. Open thread #3 (helipad/helicopter) stays open, now
anchored to the AIR WING branch.
