# SPEC — Earth Defense Force (working title)

> The design spec, written to **grow one chunk at a time**. It carries full detail only for chunks that
> are actually built; everything ahead of the build front is deliberately high-level, so we don't
> front-load design that will drift. Pairs with `DECISIONS.md` (the manifest) and `ARCHITECTURE.md`
> (the map). Full source narrative: `docs/DESIGN-BRIEF.md`.
>
> **Status:** C0 built. C1+ planned, high-level only — each is locked in detail at the top of its own
> chunk via `/spec-feature`.

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

- **C1 — Naval movement (not started).** Momentum/inertia-based piloting, turning radius, drift.
  *Detailed design locked at the top of C1 via a dedicated interview — do not treat DECISIONS D1.6 as
  more than a deferral.*

- **C2+ — not yet scoped.** Hardpoint hull + purchase economy, weapon catalog (domain-tagged), sonar
  detection, depth charges, wave/spawn director, meta-progression shop. Order and grouping TBD when C1
  is done — see `DECISIONS.md` Build Timeline.
