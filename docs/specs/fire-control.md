# C11 — LONG-RANGE FIRE CONTROL (spec — AT THE GATE)

> Status: mockup gate (`design/fire-control.html`, forked from the approved C10 machinery).
> **Formal CR**: supersedes the C3 gate-rev-2 *mechanism within gun range* — "the cursor sets the
> bearing, not the burst point" existed because the fixed camera meant the cursor could only
> express a screen's worth of distance. C10 removed that premise. Beyond gun range the bearing
> mechanism SURVIVES unchanged. Owner directive from the research-pass interview
> (burst-at-cursor chosen over bearing-only and target-designation); spec interview 2026-07-10
> locked LEAD-ASSIST IN as a tech node (**RANGEKEEPER** — advisory, the player still lays the gun).

## 1. The mechanics

**Point burst (sim — the whole change is one condition):** a FORCED splash shell whose aim point
is within gun range ends its flight AT the aim point and bursts there; beyond range it flies the
full range along the bearing exactly as today. Implementation: `Turrets._fire` uses
`life = minf(origin→aim, range_u) / speed` for ALL splash shells (auto already did this; the
`not forced` guard dies). The proximity fuse is untouched — a shell that passes a surface
contact on the way still detonates. No rng, no new state.

**Flight-time readout (HUD):** while the main battery is forced, the reticle shows the mb16
flight time to the burst point ("2.1 s"); when the cursor is beyond range it shows
"MAX RANGE · BEARING" — the mode telltale.

**Fall-of-shot on the scope (HUD):** the radar draws own in-flight mb16 shells as tiny foam
dots and each burst as a brief expanding flash at its scope position. Plumbing: Main hands the
sim's effect batch to HelmGauges as well as FieldRenderer (same one-way channel; the gauges keep
a small render-side flash buffer).

**RANGEKEEPER (tech, advisory lead assist):** new ORDNANCE node `ord7` (cost 2, behind FULL
SALVO — the plotting room comes after the second barrel): while forcing, the HUD finds the
surface contact nearest the cursor within `tech.rangekeeper_snap` (120u default) and draws a
ghost diamond at the computed mb16 intercept, tethered to the contact. Advisory only — shells
go where the cursor points. HUD-side read of sim state; no sim change; flag via the standard
node-mod path (`tech.rangekeeper`, set true).

## 2. Hard rules

- The deaf-deep law is untouched: nothing here can hurt a sub.
- Sim change is deterministic (no rng) and forced-path only; two-world probes stay identical.
- All HUD additions are one-way reads; the gauges' effect feed is the same channel the renderer
  already uses (sim appends, app plumbs, render consumes).
- New tunables: `TechConfig.rangekeeper` + `rangekeeper_snap` (the snap radius belongs to the
  tech config — it parameterizes the node's mechanic, the C4 pattern).

## 3. Probe re-targets

- `probe_hardpoints` check 5: the OTH-trajectory half ("near-aimed forced shell bursts at
  ~900u") inverts by design — re-target: a forced shell aimed INSIDE range bursts at the cursor
  distance; a forced shell aimed BEYOND range still bursts at ~range.
- `probe_tech`: full-catalog totals 63 → 65 (ord7 cost 2); the affordability check re-computes.
- `docs/specs/tech-tree.md` C8 correction note updates (65 points = level 66 for the full tree).

## 4. Acceptance

1. Full verify gate green; determinism probes byte-identical.
2. Forced mb16 at a visible cursor point bursts there (splash column at the point); beyond
   range, today's bearing shot, with the telltale reading MAX RANGE.
3. Scope shows own shells and burst flashes while the world shows the columns.
4. RANGEKEEPER: unowned = nothing; owned = ghost intercept while forcing, snap radius honored.
5. Gate tunes recorded back into configs + this spec + the mockup (the standing pattern).
