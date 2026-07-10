# CLAUDE.md — Earth Defense Force (working title)

Deterministic naval wave-survival roguelite. Godot 4.7 / GDScript. Sibling project of `fulfillment`,
sharing its architecture discipline, not its tone or content. Design-first, no cruft — that discipline
IS the project (same as fulfillment).

## Read first (in this order)
1. `DECISIONS.md` — THE LAW. Consult before any architectural/behavioral change.
   Never silently rewrite a locked decision — supersede via Change Request + Change Log.
2. `ARCHITECTURE.md` — the one-page map. Open ONLY the owning domain folder.
3. `docs/HANDOFF.md` — full pick-up doc for a fresh agent. `docs/SPEC.md` — the design.
   `docs/DESIGN-BRIEF.md` — the original owner interview this whole repo is seeded from.
4. `docs/CHANGELOG.md` — what shipped, chunk by chunk.

## Verify (before ANY push)
```bash
./verify.sh          # gdparse sweep → import → boot probe
./verify.sh quick    # gdparse sweep only, after every edit
```
- No Godot in the container? The verify.sh header has the SourceForge install one-liner.
- `gdparse` (pip install gdtoolkit) checks SYNTAX ONLY — a method can parse and still not exist at
  runtime. Reason about method/property existence yourself; the probes catch it.
- gdparse also tolerates things Godot's parser REJECTS — e.g. nested `for i` loops shadowing the
  same variable name (a hard parse error in Godot 4, found at C12). A clean gdparse is necessary,
  never sufficient; only the import/boot gate proves a script compiles.

## Non-negotiables (from DECISIONS.md)
- **Determinism is sacred.** ALL gameplay randomness through `world.rng` (seeded, stable order). Same
  seed ⇒ same run. Cosmetic-only effects may use Godot's global RNG — never the sim's.
- **One-way sim → render.** Sim never reads node/render state; renderer never mutates sim.
- **No dead mechanics.** A system is "in" only when fleshed mechanically AND visually AND cross-checked
  against the manifest. No orphan pointers, unused tables, dead tags.
- **Tunables live in `config/*.tres`**, never hardcoded.
- **One small config file per system**, never a shared monolithic balance file — see `config/SimConfig.gd`
  for the rationale. Adding a system means adding its own `<Domain>Config.gd`/`.tres`.
- **Mockup gate.** Every visual chunk is proven as an HTML mockup in `design/` and approved BEFORE
  porting to Godot (mock → approve → port).
- **Hardpoint/turret art renders ON the hull**, never HUD-only — this inverts fulfillment's equivalent
  rule on purpose (DECISIONS D1.5).
- **Fulfillment is a reference to read, never a folder to copy.** Re-derive patterns fresh (DECISIONS
  D1.1/D1.3).
- Secrets only in gitignored `.env`. Proprietary/commercial — see `LICENSE`.

## Process
- New feature? Start with `/spec-feature` (interview → spec → owner approval), then implement in a
  FRESH session. `docs/DESIGN-BRIEF.md` is the seed narrative but each system (movement, hardpoints,
  domain tagging, sonar, depth charges) still needs its own dedicated interview before implementation —
  the brief intentionally leaves the specifics for that pass.
- Plan mode for any task of 3+ steps; if execution goes off track, stop and re-plan.
- Commit a checkpoint before any long autonomous stretch.
- Sim-touching diffs: check against `DECISIONS.md`'s Non-Negotiable Constraints before merge.
- Touching design / behavior / config / determinism → file a Change Request and update `DECISIONS.md`'s
  Change Log.

## When corrected
Add a rule to this file so the mistake never recurs. Keep the file lean — for each line ask: "would
removing this cause a mistake?" If not, cut it.
