# C9 — THE LIVING SEA (spec)

> Owner-approved at the mockup gate 2026-07-09. `design/living-sea.html` is the visual reference —
> **direction B "HEAVY WEATHER" ships**, with the owner's gate tunes (splash column scale 1.4,
> foam disc life 3.4 s, wake foam life 9.0 s). Direction A "NEWSREEL SWELL" stays in the mockup
> as the rejected-but-kept reference. This chunk supersedes the C2 LOOK-LOCK *for the water and
> ride only* — hull/turret art, palette, and line weights are C2-verbatim and stay locked.

## 1. The problem (owner, research-pass interview 2026-07-09)

The game reads flat. The water is a `#0A1E28` clear-color, a faint chart grid, drifting foam
flecks, and fading wake circles — no motion, no depth cues, and shell impacts are a thin
expanding ring. The owner's asks: **wave feeling** and **splash effects from rounds**.

## 2. Hard rules

- **Render-only.** No sim system reads or writes anything in this chunk. All sea/ride/splash
  state lives render-side; cosmetic randomness uses render-side RNG, never `world.rng`.
  Two-world determinism probes must stay byte-identical (nothing here touches them).
- **The sim's effects queue is the only input** — splash positions come from real impact events
  (`splash`, `gunsplash`, `dcblast`, hostile shell expiries), never from render guesses.
- **Reduced motion is law.** A `field.tres` flag (`reduced_motion`) freezes sea animation,
  zeroes heave/roll, and de-animates splash columns — but **keeps the foam discs** (they carry
  gameplay information). Godot has no OS `prefers-reduced-motion` query; the flag is the v1
  switch, a title-screen toggle is C12 territory.
- **Tunables in `field.tres`** (FieldConfig owns sea cosmetics), values = the approved mockup's
  direction-B preset.
- **Must read at the C10 zoom floor.** High-frequency layers (fine band, glints, crest streaks)
  fade below zoom ≈ 0.75→0.42; splash/foam sizes clamp to minimum screen pixels. Owner judged
  the look at zoom 0.51 — noted for C10: the tactical camera should make that wide view home.

## 3. The layer stack (bottom → top), per the approved mockup

1. **Sea shader** — one fullscreen quad (CanvasLayer −1, screen-space, world-space math from
   `cam_pos`/`zoom`/`sea_time` uniforms): base `#0A1E28`; two band layers (sums of integer-
   wavevector sines: broad diagonal swell + finer counter-diagonal chop) mapped crest-light /
   trough-dark; glint field (two counter-scrolled noise fields multiplied, smoothstep-
   thresholded, soft — never hard sparkle).
2. **Chart grid** — unchanged language.
3. **Crest-biased flecks** — existing flecks, density up, alpha biased toward analytic-swell
   crests (`swellH`, the GDScript twin of the shader bands: shared direction/tempo, phase
   approximate — documented as acceptable in the mockup).
4. **Crest-foam streaks** — thin white lines that form and break along swell crests
   (direction B's weather). Render particles, spawn near crests, grow/arc/fade.
5. **Wake** — persistent churned foam: prop-churn line + widening V shoulders that drift
   outboard; ~9 s foam life. Plus torpedo **bubble trails** (existing torpedo wake, brighter
   bubbling look). Bow wave strokes at the stem, speed-scaled.
6. **Water-level fx (under hulls):** splash **foam discs** (linger 3.4 s, ring + pale fill),
   splash **column shadows** (sun-opposite, offset tracks column height), **DC blast domes**
   (subsurface teal glow + white core + chasing dark ring), sinking-charge plop.
7. **Hull shadows** — sun-opposite silhouette fills; offset breathes with the heave.
8. **Ships with ride** — heave (screen-px lift toward the light, from `swellH` under the keel)
   + roll (whisper of rotation from the swell differential across the beam) — applied at draw
   time only. Enemy surface craft get scaled-down bob/rock.
9. **Tracers** — unchanged.
10. **Above-ship fx:** splash **columns** — the owner's ask, five cues: occluding white plume
    (stacked sun-biased blobs), overshoot pop (easeOutBack rise ~0.2–0.26 s, hang, fall),
    droplets flying outward then stopping, the under-layer shadow + lingering disc. Sizes:
    mb16 36u · dp5 16u · gunsplash 6u, ×1.4 column scale, min screen px 12/7/4. **Splash dye
    ON** (per-battery rim tint: mb16 brass, dp5 steel — WWII spotting practice; hostile
    splashes never dyed). Muzzle flashes unchanged.

## 4. Sim-side effect mapping (emission additions are cosmetic-only)

| event | today | C9 |
|---|---|---|
| `splash` (mb16 burst, bay bomb) | expanding ring | full mb16-class column + disc |
| `gunsplash` (door guns) | small slap | gun-class column (stitch scale) |
| `dcblast` | ring | dome + core + chasing ring (existing ring language kept) |
| dp5/aa20 shells expiring over water | *nothing* | **new `splash` emission** (dp5/gun class) — near-miss straddles are the point; append-only, no rng, no behavior change (Change-Log noted) |
| hostile gunboat shells expiring | *nothing* | same — hostile class (never dyed) |

## 5. Prep refactor (house rule, before the feature)

`FieldRenderer.gd` is 556 lines (> the 500 split rule) and grows here. Split by seam into
render-domain helpers called from the one `_draw` (one CanvasItem, draw order unchanged):
sea/field · own ship · hostiles · projectiles · fx. State (fx arrays, recoil) stays on the
renderer; helpers are static draw funcs.

## 6. Acceptance

1. Full verify gate green; two-world determinism probes byte-identical (render-only proof).
2. `tests/screenshot_c9.gd` harness captures the port for side-by-side against the mockup.
3. Every §3 layer present and knob-mapped to `field.tres`; values = approved preset B + tunes.
4. `reduced_motion = true`: sea static, ride zero, columns de-animated, discs intact.
5. At zoom 0.4 (dev-forced): hf layers faded, splash/disc/wake clamp to min px, scene legible.
6. The mockup stays the reference: any port-time deviation goes back into the mockup file.
