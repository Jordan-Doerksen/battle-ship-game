# SPEC — Earth Defense Force (working title)

> The design spec, written to **grow one chunk at a time**. It carries full detail only for chunks that
> are actually built; everything ahead of the build front is deliberately high-level, so we don't
> front-load design that will drift. Pairs with `DECISIONS.md` (the manifest) and `ARCHITECTURE.md`
> (the map). Full source narrative: `docs/DESIGN-BRIEF.md`.
>
> **Status:** C0–C3 built — the game plays end to end (sail, fight, sink, restart). C4+ planned,
> high-level only — each is locked in detail at the top of its own chunk via `/spec-feature`.

---

## The game in one paragraph

You command a single Earth Defense Force battleship, alone against AI-piloted alien swarms rising from
air, sea surface, and underwater. The aliens don't personally pilot the drones — they're sheltering
inside motherships that already crash-landed on Earth, running the swarm by remote while consuming the
planet's water for reasons not yet revealed. You pilot the ship directly with real naval momentum and
weight; your hull's hardpoints auto-fire at anything in range regardless of which way you're facing.
Hardpoints are visible, purchasable positions on the hull — small mounts numerous, medium fewer, large
fewest, mirroring a real battleship's gun arrangement. Subs are invisible until sonar range reveals
them; depth charges are a free, inaccurate always-on backstop for whatever sonar misses. Survive waves,
bank a persistent currency, spend it between runs on permanent hardpoint unlocks. Tone: 1950s B-movie
schlock, played completely straight-faced.

## Design pillars

- **Deterministic and reproducible.** Same seed produces the same run, tick for tick. All gameplay
  randomness draws from one seeded stream in a stable order.
- **Piloting is positioning, not aiming.** Hardpoints auto-target and fire in any direction; the only
  thing hull facing and movement decide is domain coverage and sonar range. Steering is a tactical
  choice about *where the ship's sensors and hull are*, never about "bringing guns to bear."
- **A visible hull, not an abstract loadout.** Every hardpoint is a specific position on the ship you can
  see and choose to fill — the opposite of an anonymous bay counter.
- **B-movie schlock, played straight.** Propaganda-poster earnestness, newsreel narration energy. No
  winking self-awareness, no corporate-parody carryover from fulfillment.
- **No dead mechanics.** A system is not "in" until it is fleshed mechanically **and** visually **and**
  cross-checked against `DECISIONS.md`.
- **Hybrid render, sim owns truth.** Same as fulfillment, with one inversion: hardpoint/turret art
  renders on the hull itself, not HUD-only (DECISIONS D1.5).

## The build map (chunks)

Each chunk after C0 opens with its own `/spec-feature` design-first interview that locks its specifics
at the moment it's built — recorded then, not now.

- **C0 — Heartbeat (built 2026-07-08).** The greenfield skeleton everything else hangs on: a
  fixed-timestep deterministic loop, the seeded RNG, the `GameWorld` truth object, and a hybrid render
  harness that proves the loop and determinism are alive on screen. No gameplay yet.

- **C1 — Naval movement (built 2026-07-08).** Momentum/inertia piloting: held-key throttle with
  brake-through-to-astern, speed-coupled turning with a standstill floor, long coast, visible lateral
  slip. Locked by its interview spec `docs/specs/naval-movement.md`; feel proven and owner-approved in
  `design/naval-movement.html` before the port (that mockup stays the C1 visual reference).

- **C2 — Hardpoint hull & gunnery range (built 2026-07-08).** Visible 4S/4M/2L mount plan on a
  battleship-scale hull, 3-weapon domain-tagged catalog with per-weapon policies and finite traverse,
  hold-to-force-fire (LMB all guns / RMB main battery), drifting practice drones. Locked by
  `docs/specs/hardpoint-hull.md` (owner LOOK-LOCK on mockup rev 3 — `design/hardpoint-hull.html`
  stays the visual reference).

- **C3 — Wave director & first enemies (built 2026-07-08).** Seeded budget-director waves with
  lulls; swarmer/gunboat/bomber arriving beyond the edge; hull pips + grace; radar scope with
  fire-control bearing; MMB secondary force-fire; over-the-horizon main battery with proximity
  fuse; SHIP LOST → fresh-seed restart. The C2 practice range retired. Locked by
  `docs/specs/wave-director.md` (`design/wave-director.html` stays the visual reference).

- **C4+ — not yet scoped.** Sonar + subs + depth charges (completes the three domains), hardpoint
  purchase economy (the lull is its shop window), boss ladder + enemy naming (open thread #2),
  meta-progression shop. Order TBD — see `DECISIONS.md` Build Timeline.
