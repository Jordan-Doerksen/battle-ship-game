# Earth Defense Force (working title) — Design Brief

Spinoff of `pentafall/fulfillment`. Captured from an owner interview on 2026-07-08.
This is a **design brief**, not yet a portable spec — no Change Request/DECISIONS.md
process applies here, that starts once the sibling repo exists and adopts its own
locked-decisions doc. Treat this file as the seed for that repo's `DECISIONS.md` +
`SPEC.md`.

Status: core systems design settled through interview. Two threads intentionally
left open (see **Open Threads** at bottom) — everything else below is locked as of
this writing and should not be silently redesigned; if something here needs to
change, that's a conscious call, not a drift.

---

## 1. Pitch

You command a single Earth Defense Force battleship, alone against AI-piloted
alien swarms rising from air, sea surface, and underwater. Aliens don't personally
pilot the drones attacking you — they're sheltering inside motherships that
already crash-landed on Earth, running the swarm by remote while consuming the
planet's water for reasons not yet revealed. Tone is 1950s B-movie schlock:
propaganda-poster earnestness, newsreel narration energy, played completely
straight-faced.

Reuses fulfillment's deterministic sim/render architecture, auto-targeting turret
AI, and Depot-style persistent economy — reflavored, and extended with a genuinely
new mechanic fulfillment doesn't have: a real hull with discrete, purchasable
hardpoint positions instead of an anonymous "bay count."

## 2. Setting & Tone

- **Ocean, not space.** Real WW2 battleship aesthetic — riveted hull, gun
  barbettes, bridge — exaggerated with way more mounted weapons, modern tech
  systems, and a helipad in place of the usual hangar/fighter bay.
- **Tone**: B-movie/1950s schlocky pastiche. This is a real tonal departure from
  fulfillment's corporate-parody voice — do not carry over "Supervisor / Regional
  Manager" style bureaucratic humor. New voice: invasion-newsreel, propaganda-poster,
  campy-serious.
- **Enemies**: AI-piloted swarm drones. Aliens themselves are not the drones —
  they're remote operators sheltering in crashed motherships already on/in Earth.
  Motive: consuming Earth's water. *Why* is an open narrative hook (see Open
  Threads) — doesn't block any systems work.
- **Working title**: "Earth Defense Force." Flagged during interview: this is also
  the name of a long-running real game franchise (Sandlot/D3 Publisher). Owner has
  not yet decided whether to keep the literal name or shift to a close variant —
  revisit before the name goes into a public repo/store listing.

## 3. Core Loop

- Player **pilots the ship directly** — full naval physics: real momentum/inertia,
  wide turning radius, weight. This is **new movement code**; fulfillment's
  `Flight.gd` (arcade boost-dash, free 2D flight) is not a fit and should not be
  reused as a base, only possibly mined for structural patterns (fixed-tick
  integration, camera-follow).
- **Hardpoints auto-fire** via targeting AI — the player does not hand-aim
  individual guns. This adapts fulfillment's `Turrets.gd` closely: per-turret
  target acquisition, `CLOSE/FAR/STRONG` target-mode selection, ammo/reload model.
- **360° auto-turrets** — hull position does NOT constrain firing arc. A hardpoint
  can engage anything in range regardless of which way the hull is facing. Hull
  position is purely a cosmetic + economic identity (where the mount visually sits,
  what it costs to install) — not a tactical arc constraint. This was a deliberate
  choice to keep piloting a maneuvering/positioning decision for *domain coverage
  and sonar range*, not for "bringing guns to bear."
- **Single hull health pool** (pip-style, like fulfillment's discrete hull pips) —
  no per-hardpoint destruction/knockout system. Hardpoints matter for offense and
  loadout, not as a targetable damage layer.

## 4. Threat Domains: Air / Surface / Sub

Swarms attack from three domains simultaneously:

- **Air** — drones/aircraft.
- **Surface** — boats/torpedo craft on the water.
- **Sub** — submarines/torpedoes underwater.

Every weapon is tagged with which domain(s) it can engage. Some weapons are
dual-domain (e.g. can hit both air and surface), some are single-domain. This
domain tag is the new axis that replaces fulfillment's elemental system
(Blaze/Frost/Shock/Void) for this game — it's a targeting-capability tag, not a
damage-type/resistance system (no decision yet on whether a *separate* elemental/
status layer sits on top of this — out of scope for MVP, revisit later if wanted).

**Sonar**: subs are invisible on radar by default. A **Sonar system**, upgraded
with points through the same economy as hardpoints, is a **passive detection
radius** — the wider it's upgraded, the earlier subs light up on the radar/minimap
(direct extension of fulfillment's `RadarView.gd` minimap). No active "ping"
ability for MVP — passive radius only.

**Depth charges**: a free, always-on, non-purchased ship system (parallel to
fulfillment's fixed per-hull "prow" gun that's never drafted/upgraded) that
automatically fires at subs once they close to a tight range, with deliberately
bad accuracy. This is the failsafe for players who under-invest in sonar — subs
that sneak in past your detection radius get some free hits in before depth
charges even get a swing at them. Creates the intended tension: invest in sonar
to fight subs at range with real guns, or skimp and rely on the inaccurate
backstop.

## 5. Hardpoints & Weapon Catalog

- **Dense hull**: ~12-20+ fixed hardpoint positions. Full layout is visible from
  the start — empty mounts show on the hull — each gated by an increasing point
  cost to install/activate. (Mirrors fulfillment's Depot "Bay Lease" rider pattern:
  cost curve + persistent unlock, just repositioned from an anonymous per-hull
  count to a specific visible hull location.)
- **Sized tiers**: small / medium / large. Bigger guns need bigger mounts —
  mirrors fulfillment's weight-class gating (light/medium/heavy) but per-hardpoint
  instead of per-hull.
- **Inverse-pyramid count**: small mounts are the most numerous, medium fewer,
  large fewest — matches a real battleship's actual gun arrangement (a cluster of
  CIWS/AA emplacements, several secondary batteries, a couple of main guns).
- **Weapon variety scales with size tier**: more distinct weapon *types* available
  at the small tier (more hardpoints to fill, more variety needed to avoid
  repetition), fewer at medium, fewest at large.
- **Weapon catalog is compact**: ~6-8 distinct types total, fresh-designed (not a
  reskin of fulfillment's 9 weapons), clear functional roles, spread across the
  three domains and three size tiers. Exact roster (e.g. CIWS/flak, deck gun,
  missile pod, depth-charge launcher upgrade, main gun, torpedo tube) is
  next-pass content design, not yet locked line-by-line.

## 6. Meta Structure & Scope

- **Run structure**: same as fulfillment — one self-contained combat run (survive
  waves, die or win) plus a **persistent cross-run points economy** (Depot-style
  shop) for permanent hardpoint-slot/upgrade unlocks between runs.
- **Scope lock**: **one hull shape only** until the rest of the game is built out.
  All balance work targets that single hull — do not design for hull variety yet
  (this deliberately sidesteps fulfillment's 3-hull-class system entirely).

## 7. Reuse Map (from fulfillment)

Strong reuse candidates, from a direct systems audit of fulfillment:

| Keep / adapt closely | Rebuild from scratch |
|---|---|
| Sim/render one-way split, `GameWorld`-as-source-of-truth, entity pooling, static-system-per-tick architecture | Naval movement/physics (momentum, turning, drift) — `Flight.gd` is arcade-only, wrong fit |
| `Turrets.gd` targeting/firing logic (CLOSE/FAR/STRONG modes, ammo/reload model) | Hull hardpoint **position** data model — hull is currently one flat polygon, no sub-positions at all |
| Cockpit HUD gauge-bank pattern, `RadarView.gd` minimap (extend for sonar-gated sub visibility) | Turret geometry rendered ON the hull — fulfillment's D1.5 explicitly locks weapon art to the HUD rack only, never the hull; this game needs the opposite |
| Depot rider-buy/refund shop pattern (cost curve, level cap, refund) as template for hardpoint purchase UI | Deliberate hardpoint-purchase-by-position shop UI (Depot today has no "pick a specific slot" concept) |
| Archetype/boss escalation structure (corner-count=strength, champion/element system, title-ladder bosses) — reskinnable | Fresh weapon catalog (6-8 types, domain-tagged) |
| Discrete hull-pip health display | Domain-tagging system for weapons (air/surface/sub) — new axis, no fulfillment analog |
| | Sonar detection-radius mechanic + depth-charge auto-defense — no analog in fulfillment |

## 8. Project Setup

- **New sibling repo**, forked from fulfillment. Not created yet — first concrete
  setup step once this brief is approved.
- Repo will need its own `DECISIONS.md`/`ARCHITECTURE.md` seeded from fulfillment's,
  amended for the systems in §7's "rebuild" column.

## Open Threads (intentionally deferred, not blocking)

1. **Water-mystery payoff** — why the aliens want Earth's water. No decision yet;
   doesn't block any systems work. Revisit when writing narrative/mission framing.
2. **Boss ladder & enemy roster naming** — fulfillment's corporate title-ladder
   (Supervisor → VP Logistics) needs a B-movie-appropriate replacement (mothership
   hierarchy, drone type names). Not yet designed.
3. **Helipad** — mentioned as part of the hull's identity (replaces a
   hangar/fighter bay) but its gameplay function (support ability? cosmetic only?
   analog to fulfillment's `Fighters.gd` system?) hasn't been defined.
4. **Trademark-adjacent working title** — see §2, revisit before public naming.
