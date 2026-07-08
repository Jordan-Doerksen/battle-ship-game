# Changelog — Earth Defense Force (working title)

Chunk log, newest first. Each chunk ships only after it passes the cross-check against `DECISIONS.md`.

---

## C1 — NAVAL MOVEMENT · 2026-07-08 · Built

The first gameplay system, run through the full design-first pipeline in one day: `/spec-feature`
interview → owner-approved spec (`docs/specs/naval-movement.md`) → interactive HTML mockup
(`design/naval-movement.html`, owner-approved at the gate) → Godot port verified 1:1 against it.

- **Sim:** `scripts/engine/systems/Movement.gd` — system #1 in `Sim.step`'s fixed order. Held-key
  throttle (W ahead; S brakes harder than thrust and carries through the stop to a 35% astern cap),
  speed-coupled turn authority with a standstill floor, anisotropic exponential drag (long along-keel
  coast, visibly decaying lateral slip), heading-drives-velocity. Pure arithmetic, zero `world.rng`
  draws. `scripts/engine/data/InputState.gd` is the one-way input door (Main writes it pre-step);
  `GameWorld` gains `ship_vel` + `input`.
- **Config:** `config/MovementConfig.gd` + `movement.tres` (8 tunables, owner-approved anchors);
  `FieldConfig`/`field.tres` re-scoped from the retired C0 starfield to the sea field (grid, flecks,
  wake) — no dead config left behind.
- **Render/UI (1:1 mockup port):** `FieldRenderer` draws the chart grid, drifting foam flecks
  (toroidal tile, cosmetic RNG), world-anchored wake trail, and the battleship hull silhouette with
  deck hints; `scripts/render/patina.gdshader` ports the scanline/vignette overlay;
  `scripts/ui/HelmGauges.gd` is the gauge bank (engine order, way digits + bar, helm/authority,
  slip, heading) — the first piece of the future gauge-bank HUD. Camera stays north-up at 0.85 zoom.
- **Verify:** `tests/probe_movement.gd` runs the spec's acceptance checks headless (determinism with
  scripted input + zero-RNG tripwire, accel window, coast, brake/astern cap, turn floor, slip) as a
  new `verify.sh` step. Probe numbers match the mockup's JS validation exactly. `probe_sim` checks
  unchanged. `tests/ScreenshotC1.tscn` + `screenshot_c1.gd` is a dev harness (not gated) that drives
  the helm under Xvfb and saves a frame for mockup side-by-side checks.
- **Decisions:** D1.6's deferral resolved; D1.2 (Godot) reviewed at owner request and re-affirmed —
  HTML mockups stay the permanent design surface, Godot is the product.

## C0 — HEARTBEAT · 2026-07-08 · Built

Repo bootstrap from the owner-approved design brief (`docs/DESIGN-BRIEF.md`):

- Governance docs seeded: `DECISIONS.md`, `ARCHITECTURE.md`, `docs/SPEC.md`, `docs/HANDOFF.md`,
  `CLAUDE.md`, this changelog.
- Greenfield Godot 4.7 project (`project.godot`), re-deriving fulfillment's structural patterns rather
  than copying them (DECISIONS D1.3): seeded `Rng`, generic `Pool`, minimal `GameWorld` truth object,
  fixed-timestep `Sim` step root (no systems yet), `Main.gd`/`Main.tscn` accumulator loop, and a
  `FieldRenderer` that draws a placeholder hull + starfield to prove the sim→render loop is alive and
  one-way.
- Config split per-system from the start (`SimConfig`/`sim.tres`, `FieldConfig`/`field.tres`) instead
  of one monolithic balance file — a deliberate departure from fulfillment's ~300-line
  `BalanceConfig.gd`, so tuning any one future system (movement, hardpoints, sonar, …) only ever
  requires reading its own small config file.
- `verify.sh` gate (gdparse sweep / import / boot probe) + `tests/probe_sim.gd`.
- No gameplay systems yet — naval movement, hardpoints, domain-tagged weapons, sonar, and depth charges
  are each a future `/spec-feature` chunk.
