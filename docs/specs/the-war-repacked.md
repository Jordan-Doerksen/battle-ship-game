# C16 — THE WAR, REPACKED (spec — AT THE GATE)

> Status: mockup gate (`design/the-war-repacked.html`, forked from the C15 machinery — the
> owner fights the new waves in real waters). The world arc's closer. Interviews locked:
> **formations with shape** (not blobs) · **echelons + real quiet** (vanguard → main body
> ~15 s → sting; longer, genuinely empty lulls) · **terrain-aware packing** (open-water lanes;
> ambushes staged behind features) · **domain mix explicitly KEPT** (the budget cocktail
> stays). Retunes against the C14 hull, the AIR THREAT sky, and the C15 waters.

## 1. The director (supersedes the C3 greedy spend — a formal CR when built)

- **Formation templates as config data** (the waves config owns them): GNAT SWARM (wedge),
  GNAT SCREEN + JACKAL LINE (the screened advance — screen lands ~8 s ahead on the same
  bearing), JACKAL PINCER (split bearings ~70°), WASP FLIGHT (loose echelon, flank), VULTURE
  RAID (near-opposite bearings — torpedoes as an anvil), WOLFPACK (one quiet bearing, wide,
  min wave 7). Template cost = Σ member costs; unlocks respect member unlocks.
- **Composition per wave** (one rng stream, stable order): weighted template draws until the
  budget can't buy one, singles fill the remainder — the budget still spends exactly.
  Purchases are assigned to **echelons**: vanguard (0 s), main body (~15 s), sting (~28 s).
  Members spawn at a shared anchor + shape offsets and arrive as a body.
- **Terrain-aware:** anchor bearings scored by open-water clearance along the approach
  (surface/sub formations strongly prefer lanes; air ignores); `ambush_ok` templates may
  instead stage just behind a feature 600–1100u out on its far side (seeded, ~35% when a
  candidate exists). C15's spawn exclusion still backstops everything.
- **Real quiet:** the between-wave lull lengthens (≈12 s) and nothing arrives during it.

## 2. Hard rules

- All draws from `world.rng` in one defined order (the C3 director's own law) — same seed,
  same war. Two-world probes stay byte-identical.
- Tunables in the waves config (templates, echelon delays, quiet, ambush chance) — no
  hardcoded composition.
- Domain mix preserved: templates span all three domains; the budget curve itself is unchanged
  unless the gate tunes it.

## 3. Probe re-targets (expected)

`probe_waves`: exact-spend survives (singles fill); lull timing re-targets to the new quiet;
new checks — formation cohesion (members share an anchor/arrival), echelon separation,
ambush placement validity (behind a feature, outside its circle), lane preference sanity,
and the determinism check re-baselines rng.calls.

## 4. Acceptance

1. Full verify gate green; two-world determinism intact.
2. A wave visibly reads as an engagement: a screen, then the body, then the sting — with real
   quiet after.
3. Surface formations arrive through open water; ambushes appear from behind rock.
4. Gate tunes recorded into configs + this spec + the mockup (the standing pattern).
