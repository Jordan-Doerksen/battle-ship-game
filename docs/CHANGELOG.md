# Changelog — The Strait of Hormuz

Chunk log, newest first. Each chunk ships only after it passes the cross-check against `DECISIONS.md`.

---

## C18 — THE WHIRLPOOL · 2026-07-12 · Built

Every strait has THE whirlpool. Second system of the TEMPEST arc (spec `docs/specs/whirlpools.md`,
four owner forks locked; mockup `design/the-tempest.html` approved as-is). Restrained by decision:
a charted tactical terrain feature, never a black hole.

- **Charted, not spawned:** `Whirlpool.generate` scores island constrictions (narrowest navigable
  gap, midpoint clear of the opening water) and charts ONE vortex per seed — pure geometry over
  seed-pure terrain, an open-water eddy fallback on a dedicated substream, ZERO `world.rng` draws.
  The C15 idiom: an unset vortex no-ops every query, pre-C18 probes never notice.
- **The tide clock (owner fork 3):** a pure cosine of the WAVE COUNT — floor 0.15 at wave 0, full
  churn at period/2. Dormant = a crossable lane with a lazy foam ring; peak = lane denied. The
  MET SECTION calls the transitions ("vortex at full churn — that lane is closed" / "slack water").
- **Mass tiers (owner fork 1):** the analytic field (clockwise swirl ~3:1 over a CAPPED inward
  pull, smoothstep rim) bends the battleship ×0.25 (a course bend, never a trap — applied to
  `ship_vel` in Movement), rides surface small craft ×1.0 (kinematic drift in Enemies), and bends
  torpedoes ×1.6 in flight (Projectiles) — a shield you keep between yourself and the wolfpack.
  Subs run beneath it; air never feels it.
- **The grinder (owner fork 4):** a small craft in the core at tide ≥ 0.8 CAPSIZES — the player's
  kill at full XP (herding is play and pays like play), a grounded spin-under fx, no fireball.
  Subs and machines immune. **The hull NEVER pays** — probe-gated.
- **The helm fight (owner fork 5):** inside the eye at high tide the rudder answers at half
  authority and the swirl torques the bow — you fight the wheel while the waves keep coming.
- **The look:** `WhirlpoolRender` — stepped darkening well whose radius IS the influence radius,
  three spiral arms of foam dashes (rotation speed encodes the tide), small eye, circling debris;
  reduced-motion freezes the spiral. Charted swirl glyph + faint ring on the scope (bathymetry,
  never a blip). `vortex_roar` loop rides tide × proximity (heard for miles — Corryvreckan).
  First-encounter teach line via the radio, once per profile.
- **Verify:** `probe_whirlpool` (7 checks) joins `verify.sh` — 11 suites. Two probe fixes at the
  gate (a control-world torpedo spawned off an unset vortex; unkillable targets so the ship's own
  turrets can't end a drift measurement). All pre-C18 probes pass untouched.

## C17 — WEATHER FRONTS · 2026-07-12 · Built

The strait grew a sky. First system of the TEMPEST arc (research: `docs/research/naval-systems.md`;
mockup gate `design/the-tempest.html` approved as-is 2026-07-12; spec `docs/specs/weather-fronts.md`
— four owner forks locked at interview). A light tactical layer, not a physics sim.

- **The schedule:** `Weather.generate` rolls the run's fronts ONCE on a dedicated substream
  (`seed ^ "WX17"`) — ZERO `world.rng` draws, the C16 director discipline. Escalating cadence:
  first front ~wave 4–6, then heavier (RAIN → SQUALL → THUNDERHEAD), longer, and closer with
  depth. Called by Main beside `Terrain.generate` (the C15 pattern: probes that never generate
  run clear-sky byte-identical). States land at wave boundaries in `Waves._begin_wave`; a `wx`
  effect fires on each front edge only.
- **One sim surface, symmetric:** `world.wx_mult` (1.0/0.75/0.6/0.5) cuts ALL detection both
  ways — sonar radius, the bird's dip, turret AUTO acquisition, and the enemy side's standoff +
  fire gates (they close in before they can engage: the knife-fight effect). Forced fire is
  weather-blind (the cursor doesn't need eyes). Gunnery dispersion explicitly not taken.
- **Boss waves stay clear** (the schedule parts around every-Nth machine waves — weather and
  machine difficulty never stack) and **squall+ grounds the bird** (airborne → rtb → lashed to
  the pad until it blows through; RAIN keeps it up on shortened ears).
- **The MET SECTION joins TF50:** forecast during the quiet ("squall line on the front — next
  wave"), arrival/clear lines, the bird-lashed call. Wave plate carries the state tag; the scope
  draws the sonar ring at its ATTENUATED radius (the art never promises ears the weather took)
  plus a dashed red WX horizon that clips air/surface blips.
- **The look (approved TEMPEST values):** `WeatherRender` — wind-angled rain streaks, sea dimple
  rings, visibility veil, THUNDERHEAD lightning under hard photosensitivity caps (flash ≤ 0.16
  alpha, ≥ 4 s between strikes, pre-rolled jag). `reduced_motion` kills streaks/dimples/flash;
  the veil and strike-point water glow stay. `rain_bed` (looping) + `thunder` (decoupled rumble —
  thunder lags lightning in life too) join `gen_sfx.py`; SfxPlayer grew a weather bed with a
  self-stopping watchdog.
- **Verify:** `probe_weather` (7 checks: determinism under fronts, zero-draw baseline, schedule
  shape, boss-clear, symmetric attenuation both sides, grounding cycle, forced-fire blindness)
  joins `verify.sh` — 10 suites. Two probe-design fixes at the gate (the boss-clear rule
  legitimately eats a front that rolls onto a machine wave — shape-check isolated with the
  ladder off; hostile-fire counted by gunflash events, not surviving shells). All pre-C17
  probes pass untouched.

## C16 — THE WAR, REPACKED · 2026-07-10 · Built

The enemy learned drill. The world arc closes: the director stops spending its budget like a
slot machine and fields ENGAGEMENTS. Gate approved as-is. Formal CR — supersedes the C3 greedy
spend; every pre-C16 probe still passes (no cross-system regression).

- **Formations, not blobs:** six templates as config data (`WaveConfig.templates()`) — GNAT
  SWARM (wedge), GNAT SCREEN + JACKAL LINE (the screened advance, gunboats +8s behind the
  gnats), JACKAL PINCER (split bearings), WASP FLIGHT (loose, flank), VULTURE RAID (near-
  opposite anvil), WOLFPACK (subs, wave 7+). Members share an anchor and arrive as a body.
- **Echelons + real quiet:** the budget's buys land in a vanguard (0s) → main body (+15s) →
  sting (+28s), normalized so the earliest lands at 0. Between waves, a genuinely longer,
  empty quiet (`quiet_secs` 12, was the 8s lull) — the sonar-sweep breather. Singles fill the
  budget remainder exactly (the C3 greedy path survives inside the new composer).
- **Terrain-aware packing:** surface/sub formations pick OPEN-WATER lanes (approach scored
  against the C15 rocks); `ambush_ok` templates (pincer, wolfpack) stage behind a feature's far
  side ~35% of the time — "they were waiting behind the rock." Air ignores terrain.
- **Determinism, stronger:** composition runs entirely on a per-wave substream keyed
  `(world_seed, wave)` — ZERO `world.rng` draws — so the same seed fields the same war no
  matter how you fought the last one (the C15 "same seed = same archipelago" guarantee, now
  for the war too). `world.rng` stays byte-identical across two worlds; the probe re-baselines.
- **HUD:** the wave-plate names the drill phase (WAVE 3 · MAIN BODY · JACKAL ×2) alongside the
  newsreel tally. C7 boss ladder integration preserved verbatim (machine every Nth wave, escort
  composed from the reduced budget).
- Integration seams fixed at the gate run (the `lull_secs → quiet_secs` rename): `probe_bosses`
  (1,2), `probe_sonar` (8), and Main's attract all switched to `quiet_secs`. `probe_waves`
  re-targeted: exact spend read off the composed plan, +4 C16 checks (formation cohesion,
  echelon separation, same-seed reproduction, ambush validity) — 11 checks, all green.

## C15 — THE WATERS · 2026-07-10 · Built

The ocean grew teeth. Gate approved as-is with the owner's recipe (3 islets · 9 rocks ·
size ×1.35 · shoal 1.54×); `design/the-waters.html` is the reference, tunes back-ported.

- **Seeded archipelagos:** `Terrain.generate` draws the world's FIRST rng — same seed, same
  waters, every run its own map. Rejection-sampled placement honors the ship's start clearing
  and feature gaps. New `TerrainConfig`/`terrain.tres` owns every dial.
- **The land rules (owner, verbatim in the Change Log):** terrain blocks all water vessels —
  the ship (sliding collision, speed-scaled grind pip through the grace window), gunboats,
  subs, and the MAW in both states (the deep does NOT pass under); air crosses freely.
  Naval gunfire dies on rock — including the main battery (supersedes arc-over): islands are
  hard cover both ways. Air ordnance, the door guns, and the AA pass. Torpedoes die on stone
  whoever dropped them; depth charges thrown onto land are duds. Segment-swept blocking — no
  tunneling.
- **Waterborne AI gives way:** the mockup's tangent avoidance (with its sticky-side and
  inside-ring fixes) steers gunboats, subs, and machines around the coast; spawns re-roll out
  of rock; a hard push-out guarantees nothing ever parks in stone.
- **The look:** shoal halos, breathing foam fringes, wobbled basalt bodies with facets, scrub
  and blinking nav lights on islets, dust puffs where fire meets rock, a grind churn where the
  hull does — and the coastlines on the scope as solid land, drawn from the same verts as the
  world. The attract war fights in real waters too.
- Integration seam caught at the gate run: `Tech.apply` (app-owned) needed the one-line
  terrain-config copy every other system has. `probe_terrain` (14 checks across determinism /
  placement / collision / the blocking matrix / avoidance / open-water no-op) joins verify.sh;
  every pre-C15 probe passes untouched — open water is byte-identical.
- Housekeeping flag: `HelmGauges.gd` is past the 500-line split guide (~619) — a candidate CR
  after the arc.

## AIR THREAT · 2026-07-10 · Built

Owner play-test verdict: "I can literally just go AFK and make it to a boss" — the flak was
still auto-solving an air war flown by commuters. Interview locked BOTH fixes:

- **The VULTURE is a torpedo bomber now, not a suicide diver.** It orbits at 380u standoff and
  drops a running torpedo (~every 12 s, 650u run) — inheriting the ENTIRE torpedo kit for free:
  the wake, the klaxon, the turn-into-it counterplay, the bird's investigate mark, and (come
  C15) rocks to hide behind. Its dead contact-damage field zeroed with the identity change.
- **The WASP enlisted** (new roster plane, cost 4, unlock wave 4): fast, flimsy (hp 2), and
  rude — ripples FOUR unguided rockets per pass with a wide cone; misses straddle the water
  around you (the C9 splash kit sells every one) and overshoots sail right overtop (the 1.4×
  overfly). XP 40; slim-dart silhouette with rocket rails; newsreel tally speaks its name.
- Engine: one `EnemyDef.salvo` field + a salvo loop in `Enemies.step` (per-rocket spread from
  `world.rng`, stable order — determinism intact); GNATs stay the suicide swarm untouched.
- `probe_waves` check 7 (peak-sampled: the drop + the full ripple); `probe_bosses` roster-name
  pin re-targeted. Manual TORPEDOES page now credits the sky. Mockup parity for the roster
  rides with C16's wave-director rework.

## C14 — THE HULL · 2026-07-10 · Built

The world arc opens (owner directives + interview: C14 hull → C15 waters → C16 the war,
repacked). The battleship grew ~15% — art and hit capsule TOGETHER (`HULL_SCALE` 2.4 → 2.75;
`Hull.HALF_LEN` 85 → 97, `RADIUS` 26 → 30) — a visual-only bump would have let shells ghost
through the bow. Deck furniture and mounts deliberately DON'T scale: the grown hull around
them is the requested deck room. Bow-anchored details ride the new stem (jack line, bow wave,
wake emission point); the K-gun throw ring follows the hull (`dc_ring` 85 → 97). The owner
accepts being a larger target — C16 retunes the war against it. Probes tracked automatically
(they read the Hull symbols); full gate green. Mockup parity for the scale rides with C15's
terrain mockup.

## C13 — FIELD MANUAL & THE SHOW-OFF TITLE · 2026-07-10 · Built

Owner directives at the play-test: "a tutorial page that explains a function in text then
underneath has a live example of all the mechanics," and make the title demo "invulnerable,
tons of shit on screen, max ALL its upgrades — JUST for the title."

- **THE FIELD MANUAL** (`TutorialScreen` + `TutorialVignettes`, M or the new title button):
  nine pages, each a deadpan explanation over a live looping TRAINING FILM — the helm's
  S-carve with WASD glyphs lighting from the path itself, the batteries slewing through the
  three force orders, long-range fire walking SHORT → STRADDLE → HIT, the crewed guns
  stitching, the deep (ping → diamond → drive-over → K-guns), torpedo evasion, the air wing's
  kill chain, a machine losing its parts, and the scope decoder ring by ring. ←/→ or A/D to
  turn pages, dots clickable, ESC/M home. Vignettes are deterministic hand-staged loops (no
  randf, local clock); reduced motion holds each film at a readable still.
- **The attract shows off:** the demo ship owns all 37 nodes (bird flying, flak bursting,
  full salvos), `godmode` on (a presentation use of the DEV flag — honest sim otherwise),
  and a cranked director: dense budgets, 2 s lulls, in-frame spawn ring, every bearing at
  once, a war machine every 2nd wave, quiet relaunch at 90 s. `start_sortie` re-derives
  honest configs — nothing leaks into a real run.

## PLAY-TEST TUNE — the scope, and a title with a pulse · 2026-07-10

Owner feedback, first C12 play-test: the rack dial "looks so weird inside the minimap," the
scope was "very unclear what everything is," and "the title screen needs some action."

- **The rack dial left the scope** (it read as a contact floating in the water) — rack state
  now lives on the gauge plate's instrument line: `RACKS ARMED` in foam / `RACKS · · ·` while
  reloading. Same width both ways; the plate never reflows. This placement supersedes the feel
  board's panel-2 on-scope dial.
- **The scope got named and dieted:** 500u range rings thinned to 1000u marks; the three
  meaning-bearing rings carry micro-labels — `16-IN` (dashed brass, gun reach), `SONAR` (solid
  foam, your ears), `DC` (dashed foam, the racks' arm range) — and the viewport rectangle reads
  `VIEW`.
- **The title fights back:** an ATTRACT sortie runs behind the menu — real sim, the player's
  own unlocks, synthetic helm on a lazy S-course, sound on; a lost demo ship relaunches after
  3 s. The title text sits on a quiet scrim; the camera rides off-center so the demo battleship
  stays visible beside the plate. `FieldRenderer.view_rect()` now culls around the CAMERA (the
  C9 audit's noted trap — ship-centered culling would have popped the attract view's edges).
- `ScreenshotC12` harness (attract title + labeled scope proofs).

## C12 — READABILITY & FEEL · 2026-07-10 · Built

The instruments learn to speak. The polish arc's closer — zero sim changes beyond two
cosmetic-only effect appends; the determinism probes never noticed. Gate: the FEEL BOARD
(`design/readability-feel.html`) approved as-is with sound on.

- **The game has a voice.** Thirteen procedural sounds baked offline (`tools/gen_sfx.py`,
  stdlib-only, seeded — reruns are byte-identical) from the board's exact recipes →
  `audio/*.wav`; `SfxPlayer` (a node under Main) consumes the same one-way effect batch as the
  renderer and the scope, with per-sound rate limits so the crewed MGs can't flood the mixer.
  The long-dropped events finally sound: `klaxon` (machine arrival — the ominous swell) and
  `waveclear` (two dry notes, no fanfare). Torpedo launches now emit a cosmetic `torpwater`
  event — the two-tone navy horn. `AudioConfig`/`audio.tres`: master volume, mute, gaps.
- **The scope got legible.** Torpedoes are a bright foam dash with trailing wake sparks (the
  C5 promise, kept at last) — never again the same mote as a shell. The 220u depth-charge arm
  range draws as a dashed ring beside the solid sonar ring, and a small rack dial fills over
  the volley cooldown and blinks READY.
- **The war waits; the sea doesn't.** `P` pauses mid-sortie — the sim holds, the water keeps
  drifting (it lives on the render clock by design).
- **The lost card is key-only.** Clicks bounce off; after 1.5 s the card offers
  `R — NEW SORTIE · T — THE TREE`. The XP report can no longer be skipped by the combat button.
- **The contextual drip** (owner interview): five one-line advisories, each shown once per
  profile at the moment it matters — the helm, force-fire, the deaf deep, the first torpedo,
  the first machine. Seen-flags persist in the profile beside XP.
- **Wounded enemies read wounded:** below half hp a gunboat lists ~7° (side picked per roster
  slot — stable, deterministic, rng-free), chars darker, and trails smoke; at the last pip, a
  small flame. Bombers smoke without listing. All render-only.
- Gotcha recorded in CLAUDE.md: gdparse tolerates nested same-name loop variables that Godot's
  parser hard-rejects — a clean gdparse is necessary, never sufficient.

## C11 — LONG-RANGE FIRE CONTROL · 2026-07-10 · Built

The cursor was taught distance; the battery is expected to use it. Formal CR: the C3 "cursor
sets bearing, not burst point" rule is superseded *within gun range* — its premise (a fixed
camera) died with C10. Beyond range the bearing shot survives untouched. Gate:
`design/fire-control.html` approved as-is.

- **Point burst (the whole sim change is one condition):** a forced splash shell whose aim point
  is within reach ends its flight AT the cursor and bursts there — `life = minf(dist, range)/speed`
  for all splash shells; the `not forced` guard died. Proximity fuse untouched; the deep stays deaf.
- **Flight time at the reticle:** while the main battery is ordered, the reticle reads the shot —
  "2.1 s · 880 u" live, or **MAX RANGE · BEARING** when the cursor is past reach (the mode telltale).
- **Fall-of-shot on the scope:** own main-battery shells cross the radar as foam dots and every
  burst blooms a brief flash where it landed — your salvos finally exist on the scope. Plumbing:
  Main hands the same one-way effect batch to HelmGauges (a 24-entry render-side flash buffer).
- **RANGEKEEPER (ord7, cost 2, behind FULL SALVO — owner interview: lead-assist IN, advisory):**
  the plotting room draws a steel ghost diamond at the computed intercept for the surface contact
  nearest the cursor (120u snap, `tech.rangekeeper_snap`), tethered to the target. Shells still
  obey the cursor. HUD-side one-way read; velocity derived exactly as the turrets lead.
- Tree: 36 → 37 nodes, 63 → 65 points (level 66 buys everything; dev-kit MAX LVL tracks
  automatically). `probe_tech` totals re-targeted; `probe_hardpoints` check 5 re-targeted
  (cursor at 200u → burst at ~200u; cursor beyond → bearing shot to ~900u).
- Full gate green; two-world determinism byte-identical (no rng anywhere in this chunk).

## CREWED GUNS · 2026-07-09 · Built

The owner saw the door gunners stitch the water and wanted it aboard: "whatever that little
strafe fire is we need to add that into the game." The four S mounts stop being clinical 12/s
auto-hoses and become **person-manned machine guns** — the honest fix for "the AA guns feel a
little powerful 'cause there's so many."

- **Bursts with rest gaps** (owner interview): 10 rounds at 12/s, then 1.5 s while the crew
  re-lays. Wild 0.14 spread. **Each round rolls 40–100% reach** (`world.rng`) — short rounds
  slap the sea and every burst walks a stitch-line toward the target (the C9 splash kit renders
  it for free).
- **Air + surface** (owner interview): the MGs always have something to strafe — gunboats and
  surfaced machines take chip fire. The deep stays deaf; the deaf-deep law untouched.
- **Planes are more dangerous now — accepted in the directive itself.** Sustained output drops
  from 12/s to ≈4.3/s, less on target. Compensation lives in FLAK tech / `weapons.tres`, not code.
- Config-generic: `WeaponDef.burst_rounds/burst_rest/reach_min` (defaults leave dp5/mb16
  byte-identical), `Mount.burst_left`, values mirrored in `weapons.tres` + `spec_defaults()`.
  All six FLAK nodes stay live (bursts self-limit heat, so bloom asserts its accumulation, not
  the hose-era ceiling).
- **Verify:** `probe_hardpoints` re-targeted — surface targets draw all three sizes; burst
  rhythm (count = cycle math ± one burst, in-burst gap = the exact period, rests observed,
  stitches on the water); no-catch-up unchanged. Full gate green, determinism intact.
  `ScreenshotCG` strafe-proof harness. Parity ported into the mockup sims that model aa20.

## C10 — TACTICAL ZOOM · 2026-07-09 · Built

The camera got sea room. Formal CR: the C1 hardcoded 0.85 died; `CameraConfig`/`camera.tres`
rule the view. Owner gate: `design/tactical-zoom.html` approved as-is (defaults shipped).
App/render only — the sim never sees the camera; probes byte-identical.

- **Wheel zoom 0.40–0.85**, exponential lerp (half-life 0.12 s), sorties boot at **home 0.51**
  (the owner's judged view), `H` snaps home. Fades key off the wheel TARGET so nothing shimmers
  mid-lerp. Camera stays ship-centered (the cursor-anchor idea superseded with rationale in the
  spec — it would fight the C1 ship lock and skew the radar's viewport read).
- **Stroke compensation**: world-art outline widths hold their 0.85-baseline apparent weight
  (`×clamp(0.85/zoom, 1, 2.2)`) — hull rim, deck lines, barbettes, turret houses, AA rings,
  enemy outlines, sub silhouette + ripple tell, tracers, streaks, splash/dye rings, helo. At
  0.85 the factor is exactly 1: the LOOK-LOCKED view is byte-identical.
- **Minimum-apparent-size floor** (`enemy_min_px` 10): the smallest hostiles never render under
  10 px — a GNAT at the floor stays a GNAT, not mush. Inert at 0.85.
- Glint tune at port fidelity check: envelope/grain thresholds tightened (0.55–0.85 / 0.82–0.94)
  — the close view was reading snowier than the approved mockup's sparse flecks.
- `zoom_in`/`zoom_out`/`zoom_home` input actions; `ScreenshotC10` harness (home / floor / max);
  `ScreenshotC9` re-pointed at the target-zoom path.

## C9 — THE LIVING SEA · 2026-07-09 · Built

The water learned to move. Owner gate: two directions built as live presets on one mockup
(`design/living-sea.html`) — **HEAVY WEATHER approved** with tunes at the gate (column scale 1.4,
foam disc life 3.4 s, wake foam life 9 s; judged at zoom 0.51, noted for C10). Spec:
`docs/specs/living-sea.md`. Render-only: the two-world determinism probes stay byte-identical.

- **The sea:** one fullscreen canvas_item shader (`sea.gdshader` on Main's new `SeaLayer`,
  behind the world) — two swell-band layers over the C1 `#0A1E28`, a glint field (slow envelope
  picks where the sea catches light, high-frequency grain keeps the catches tiny), all
  world-anchored from cam/zoom/sea-time uniforms. Crest-biased flecks and breaking crest-foam
  streaks ride the analytic swell twin.
- **The ride:** heave + a whisper of roll on the hull draw (render-only — the sim's
  ship_pos/heading untouched), a hull shadow that breathes with the heave, a bow wave, and a
  churned wake: prop churn + V shoulders drifting outboard, 9 s foam. Gunboats bob on the same
  swell; air enemies cast slide-off shadows (the C6/C7 shadow language).
- **Splash columns — the owner's ask.** Shell impacts read as vertical water columns from above:
  occluding white plume, sun-opposite shadow tracking column height, overshoot pop, droplets
  flying out then stopping, a pale foam disc lingering seconds. Per-battery dye rims (mb16 brass,
  dp5 steel — WWII spotting practice; hostiles never dyed). Depth-charge blasts got their
  subsurface glow.
- **Misses hit the sea now** (cosmetic-only sim appends, no rng): hostile shells that miss the
  hull, spent dp5/aa20 rounds, and unburst flak all splash where they fall — near-miss straddles
  read as water, not nothing.
- **Reduced motion is law:** `field.tres` `reduced_motion` freezes the sea and ride and
  de-animates columns — foam discs stay (they carry gameplay information).
- **The split (house 500-line rule):** `FieldRenderer` (556 lines) became a ~150-line
  orchestrator over four render-domain helpers — `SeaRender` / `ShipRender` / `HostileRender` /
  `FxRender` — one CanvasItem, draw order unchanged, C2 art verbatim.
- **Gate hardening:** `verify.sh` now fails on `SHADER ERROR` too (a broken sea shader slipped
  through the SCRIPT-ERROR-only grep once — never again). `ScreenshotC9` harness proves the sea,
  the 0.4× zoom floor (hf layers fade, splash px clamp), and reduced motion.
- New `field.tres` tables: sea_amp/drift/scale, glint_intensity, crest_bias/streaks,
  heave/roll/shadow, splash scale/foam-life/dye, wake width — values are the approved preset.

## C8 — BUG BATCH · 2026-07-09 · Built

Nine bugs from the first full-code adversarial sweep (research pass, owner-approved plan). No new
mechanics — the ones already shipped now do what their specs say. CR-free per the fix precedents;
every fix that could be probed is.

- **dp5 flak fuses off war machines.** With PROXIMITY BURST the fuse loop scanned only
  `world.enemies` and the airburst branch swallowed every dp5 shell — an upgraded gun that could
  never hurt a boss. The machine is a fuse candidate now (air trigger envelope vs THE CANOPY,
  contact vs surface machines; a submerged MAW neither triggers nor feels it — the deep stays deaf).
- **AoE strikes resolve at the burst point, not the machine's center.** Splash/airburst passed
  `world.boss.pos` to `Bosses.strike`, so off-center parts (turrets, bays) were unhittable by
  blast and hit effects drew at the wrong spot. The strike point is the burst clamped to the hull
  disc — edge bursts that pass the AoE gate still chip the core instead of dealing nothing.
- **THE CANOPY's bay bombs are splash attacks**, as the spec table always said (`bomb_splash` 30 —
  a new `BossDef` field in `bosses.tres`): they burst at flight end and hit the hull within the
  blast. They were point-contact shells; the hostile path had no splash mechanic at all.
- **Sonar extends a latch, never shortens it.** A ship-sonar pass over a bird-marked contact
  rewrote MAD GEAR's permanent latch down to a decaying ~4 s hold, at both write sites (sub +
  submerged MAW). `maxf` at both.
- **Turret cadence carries the sub-tick remainder.** Cooldown-by-assignment quantized every period
  UP to whole 60 Hz ticks — aa20 really fired 10/s against its configured 12/s. Decrement now gates
  at zero (idle guns bank at most one shot, never a backlog burst) and reload accumulates. Balance
  note, not drift: sustained AA DPS rises ~20% to what the config always claimed; dp5/mb16 tighten
  the same way.
- **Posthumous XP banks.** Shells still flying when the ship sank kept scoring kills the profile
  never saw. XP delta-banks every frame while the run is over; the SHIP LOST card shows exactly
  what reached the profile.
- **Dev kit MAX LVL computes from the catalog** (63 points → level 64) instead of the stale
  level-41 grant that left the tree unaffordable. Self-updates if the catalog grows.
- **Menus sit over open sea only.** Enemies, the machine, shells, and combat FX from the dead run
  no longer draw behind the title and tech-tree screens.
- Removed the dead `WPN_DOMAINS["dc"]` entry (depth charges detonate in their own branch and never
  reach `strike()`); `probe_bosses` reads the blast radius from config, not a const.
- **Mockup parity:** the three boss-behavior fixes are ported into `design/boss-ladder.html` too
  (the approved mockup carried the same bugs — C3 precedent: the fix lives in the reference).
- **Verify:** `probe_bosses` 8 → 11 checks (burst-point part attribution, dp5 flak vs machines +
  the deaf deep, bay-bomb splash in/out + live bay build), `probe_sonar` 8 → 9 (MAD latch survives
  ship sonar), `probe_hardpoints` 6 → 8 (sustained cadence == rate·T ±1; no catch-up burst after a
  10 s gap), `probe_tech` 9 → 10 (full-catalog affordability at L64). All red-green verified
  against Godot 4.7 headless; full gate green.

## C7 — BOSS LADDER & NAMING PASS · 2026-07-09 · Built

The war gets a face; the roster gets its names. The last founding system lands — open thread #2
resolves, and the design brief is SYSTEMS-COMPLETE. Full pipeline: interview (10 decisions) →
approved spec → mockup (two real balance findings) → approval → Godot port with one owner tune.

- **The ladder:** every 5th wave a mothership WAR MACHINE arrives with a half-budget escort; the
  wave holds until machine AND escort die. Three rungs tour the domains, then it laps forever at
  ×1.5 hp: THE JUGGERNAUT (wave 5, surface — turret parts + a fire director it panic-fires
  without), THE CANOPY (wave 10, air — the main battery passes under it; bomb bays + a GNAT hive),
  THE MAW (wave 15, the deep — 20 s stalking with torpedo fans, 8 s breached with vent cowls
  exposed; every cowl killed extends the breach. It can't seal).
- **The grammar:** hull-relative destructible parts (60 XP each, banked live), phase changes on
  every loss, soft-gated cores (×0.25 until the parts fall). Core kill: 250 XP × lap + a 2-pip
  hull patch — the survival loop's first breather (D1.8 refined: a reward event, not a second
  pool). Machines plug into every system: sonar and the bird hear a stalking MAW, the racks arm on
  it, turrets compete its parts with drones under the same policies, and strikes respect domain
  tags physically (a C7 machine rule).
- **The names:** GNAT / JACKAL / VULTURE / LAMPREY (`EnemyDef.rep`, display-only — mechanical ids,
  configs, and probes untouched). The wave plate reads like a newsreel tally; machines get a
  PRIORITY TARGET plate (THE-name + lap, core bar, part pips that strike through) and oversized
  radar blips (sonar-gated while the MAW is under). Dev kit: three machine spawn buttons.
- **Owner tune at the gate (C5 behavior change):** the stern racks now throw a K-GUN SPREAD —
  throw stations evenly around the beams and stern (`sonar.dc_ring` 85), scatter jittering each
  station — because blind auto racks piling charges on one stern point were too hard to connect.
  Applied to Godot + all three mockup sims + the C5 spec.
- **Verify:** `probe_bosses.gd` — 8 checks (determinism through boss waves, cadence + ladder +
  lap scaling + boss-free early waves, soft gate, parts + phases + rewards, the domain tour,
  bounty/patch/cap, the K-gun spread geometry, names) — added to `verify.sh`; `probe_waves`
  isolates the C3 director from the ladder. `ScreenshotC7` harness.

## C6 — AIR WING · 2026-07-09 · Built

The pad was never set dressing. Open thread #3 resolves: an autonomous ASW helicopter flies off
the stern, and the CLASSIFIED column declassifies. Full pipeline: interview (10 decisions) →
approved spec → mockup → TWO owner gate revisions → approval ("apoproved") → Godot port.

- **The bird (air1 WHIRLYBIRD unlocks it):** one airframe, one state machine (pad → air → rtb) on
  GameWorld, invulnerable by construction (nothing targets it; no damage path exists). Flies every
  wave regardless — spectacle first.
- **Gate rev 1 — escort weave + throttle:** a smooth S-weave across the bow that rides the ship;
  the aim point leads further ahead as the ship speeds up, and the bird has a real throttle (ease
  to station-keeping near the point — which scales with ship speed — open to ship+80 when behind;
  astern beeline failsafe). Contract, probe-gated: from any transient dip it is back ahead of the
  bow within 5 s. Constant-speed pursuit (draft) plunged ~800 u astern at flank — retired.
- **ASW (detector-first):** dipping sonar (240 u) writes the SAME contact latch as ship sonar —
  its finds are your diamonds and they arm your stern racks. Over a detected sub it drops a tight
  contact-centered 2-charge pattern (1 dmg, 9 s cadence): softens and marks, never finishes fast —
  the stern game stays king. Torpedo launches mark an investigate point it runs down.
- **Gate rev 2 — DOOR GUNNERS (air5/air6):** weak, wild MG fire at the nearest air/surface target
  near the bird; every round rolls spread AND a 40–100% reach fuse, so bursts stitch the water
  short of max range. The deep draws zero fire.
- **MAD GEAR (air7 marquee):** bird-made contacts never decay this wave; ship contacts still do.
- **Deaf-deep law made PHYSICAL (latent C5 gap the gunners exposed):** friendly shells and
  airbursts now skip submerged hulls in `Projectiles.gd` and both mockup sims — depth charges
  remain the only sub killer, by physics and not just targeting.
- **Tree:** the five ████ placeholders superseded by seven real nodes (1/1/2/2/2/2/3); air2+ stay
  redacted on the board until WHIRLYBIRD is owned. `tech.tres` regenerated (36 nodes).
- **Verify:** `probe_airwing.gd` — 10 checks (determinism, zero-tech inertness, extended ears,
  detector-first prosecution, fuel loop, speed-coupling recovery contract, MAD GEAR, tree
  derivation incl. 1-then-2 gunners, invulnerability, door gunners + deaf deep) — added to
  `verify.sh`; `probe_tech`'s AIR-WING-locked check superseded. `ScreenshotC6` harness.

## C5 — SONAR, SUBMARINES & DEPTH CHARGES · 2026-07-09 · Built

Something is under the water. The third D1.9 domain lands, completing the founding air/surface/sub
fantasy. Full pipeline: interview (8 decisions, incl. the owner's D1.11 supersession — depth
charges arm ONLY on a sonar contact) → approved spec → interactive mockup (7/7 validation harness;
two real bugs caught pre-approval: subs tagged "surface" so guns shot them, and the standoff brain
ignoring subs) → owner approval ("totally cool") → Godot port verified side-by-side.

- **Sub (roster elite):** cost 6, unlocks wave 7; hp 6, speed 35, gunboat-pattern standoff brain
  at 600 u. Its "shell" is a TORPEDO: slow (130 u/s), straight-running ~900 u, 2 pips on a hull
  hit, dodgeable off its wake line and outrunnable at full ahead. No gunflash — the deep is silent.
- **Sonar (`Sonar.gd` + `SonarConfig`/`sonar.tres`):** passive radius 350, contact latch 2.5 s on
  `Enemy.detected_until` (pure arithmetic, zero draws), `contact` ping on first acquisition.
  Detected subs: dark silhouette + foam ring in the world, diamond blips on the scope inside a
  soft sonar ring (D1.10). Undetected subs near the ship: a render-only ripple tell. Nothing else.
- **Depth charges (`DepthCharges.gd`):** free, automatic, deliberately inaccurate — and armed only
  by a DETECTED sub inside 220 u. Volleys of 4 scatter around the stern (seeded draws, volley
  order), sink 1.5 s, then blast SUBS ONLY (55 u, 3 dmg) — the ship and surface/air enemies never
  feel them. Guns can't touch subs at all: the domain map is probe-gated deaf.
- **Tech:** the SONAR branch (sixth column) — Hydrophones/Trained Ears/Deep Pattern/Quick Racks +
  ASDIC LOCK (marquee: −50% scatter, +30% blast). `tech.tres` regenerated (34 nodes). Sub kill:
  80 XP.
- **UI/render:** torpedo foam-wake runner, DC sink + underwater-blast fx, contact diamond ping,
  radar sonar ring + gated diamonds, six-column tree board, dev-kit `+SUB`.
- **Verify:** `probe_sonar.gd` — 8 checks (determinism with subs/torpedoes/DC, deaf guns,
  detection+latch, the DC trigger law, DC kill + isolation, torpedo behavior, SONAR derivation,
  zero-tech baseline: waves 1–6 sub-free AND the director provably fields subs once unlocked) —
  added to `verify.sh`. `ScreenshotC5` harness captures volley/blast/torpedo/tree frames.

## C4 — LEVELS & TECH TREE · 2026-07-08 · Built

The war gets a career, implementing the owner's Change Request (fixed hulls/turrets; persistent
levels replace the purchasable-hardpoint economy). Full pipeline: interview (8 decisions) →
approved spec → interactive mockup (career loop + owner-requested DEV TEST KIT) → approval with one
fix condition (muzzle-origin shells) → Godot port verified side-by-side.

- **Meta:** `Profile` — the FIRST save file (`user://profile.cfg`: XP + unlocked nodes; app-layer
  only, the sim never reads it). XP: kills by type (10/30/50) + wave-clear bonuses (25×wave), kept
  on death; linear-ramp level curve; 1 tech point per level.
- **Tech:** `TechConfig`/`tech.tres` (generated from `spec_defaults()` so code and resource cannot
  drift) — 24 buyable nodes across SEAMANSHIP/FLAK/GUNNERY/ORDNANCE with strict in-branch order and
  1/2/3-pt costs, plus the CLASSIFIED AIR WING (5 redacted, unbuyable nodes; open thread #3).
  `Tech.apply` derives each sortie's `Configs` from DUPLICATED base resources + node mods —
  baseline invariance is probe-gated (zero tech = byte-identical C3 behavior).
- **Marquees (sim features behind default-off flags):** CRASH TURN (Movement: emergency-back at
  speed arms a ×1.8 turn window on cooldown), INCENDIARY LOAD (aa20 hits ignite air enemies; burn
  ticks in Enemies), PROXIMITY BURST (dp5 shells airburst near air targets with a small AoE),
  FULL SALVO (mb16 fires both barrels per trigger, one spread draw).
- **UI:** title hub (BEGIN SORTIE / TECH TREE, level + XP bar), tech-tree plotting board
  (buy/respec/points, AIR WING stamp), wave-plate XP tally, lost-card XP report + LEVEL UP line +
  `[T]` shortcut. Main owns the title/tree/game state machine; menus show open sea (no ghost hull).
- **DEV TEST KIT (owner request; debug builds only, ` to toggle):** invulnerable, freeze waves,
  god guns, spawn swarmer/gunboat/bomber/swarm×8, kill all, next wave, heal, max level. Sim
  intercepts (`godmode`, `freeze_waves`) default off; spawns use non-sim RNG.
- **Fixes:** shells spawn at the barrel MUZZLE (owner's approval condition — no more rounds rising
  through the turret house; gunboats too), and the C3 fx dispatcher's silently-dropped
  gunflash/shiphit/shipdeath draws now render (found at port).
- **Verify:** `probe_tech.gd` — 9 checks (baseline invariance, derivation + modded-run determinism,
  XP/level curve + wave bonus, all four marquees behaviorally, spend rules, profile roundtrip on a
  probe-only path) — added to `verify.sh`. `ScreenshotC4` harness walks title → tree → sortie.

## C3 — WAVE DIRECTOR & FIRST ENEMIES · 2026-07-08 · Built

It's a game: enemies attack, the hull takes damage, runs end and restart. Full pipeline again —
interview (8 decisions) → approved spec → interactive mockup through two owner gate revisions
(MMB secondary-battery force-fire + radar scope; over-the-horizon main battery with proximity fuse
and radar fire-control bearing) → approval → Godot port verified side-by-side.

- **Sim:** `Waves.gd` — seeded budget director (base 6 + 4/wave threat points, costs swarmer 1 /
  gunboat 3 / bomber 5, unlock milestones 1/3/5, 1–3 cluster bearings, spawns beyond the view ring;
  discrete waves + lulls). `Enemies.gd` — divers pursue under per-type turn caps and pay themselves
  for hull contact; gunboats hold standoff, orbit, and fire led dodgeable shells. `Hull.gd` — pip
  pool (10) + 0.8s grace window, keel-capsule contact, run end freezing the war. `Turrets.gd` gains
  MMB medium-only force-fire, over-the-horizon forced splash shells (cursor = bearing, full-range
  flight), and — port fix, applied to the mockup reference too — intercept LEAD on auto-fire (no-lead
  fire could never hit an orbiting gunboat; waves stalled forever). `Projectiles.gd` gains hostile
  shells (hull capsule + grace) and the mb16 proximity fuse. Restart = fresh `GameWorld` seed (Main).
- **Retired:** the C2 practice range (owner decision) — `Drones.gd`, `Drone.gd`, `RangeConfig`,
  `range.tres` deleted; the turret probe suite re-targeted at hand-placed enemies.
- **Config:** `waves.tres` (director, hull pips/grace, radar range), `enemies.tres` (EnemyDef
  sub-resources). Roster ids await the naming pass (open thread #2).
- **Render/UI:** red enemy identity (darting swarmer delta / low gunboat hull with deck gun / heavy
  bomber wing), hostile orange shells, ship-hit rings, grace flicker on hull + pips, B-movie death
  blast with the wreck slipping under, wave plate (`WAVE N · CONTACTS: X` / lull countdown), radar
  scope with typed blips, incoming-fire sparks, viewport extent, main-battery ring, and the live
  fire-control bearing while force-firing; SHIP LOST card + `[R] NEW SORTIE`. Input map adds MMB +
  R. C2 LOOK-LOCK carried.
- **Verify:** `probe_waves.gd` (determinism through combat, exact budget spends [6,10,14,18,22,26],
  unlock milestones, lull timing, damage + grace, gunboat standoff/fire, run end + fresh-seed) and
  the re-targeted `probe_hardpoints.gd` (traverse, domain, policy, three force orders + release,
  fuse + trajectory, bloom) both gate in verify.sh. `probe_movement` isolates via a silenced
  director. `ScreenshotC3` harness replaces C2's.

## C2 — HARDPOINT HULL & GUNNERY RANGE · 2026-07-08 · Built

The hull grows teeth: visible hardpoints with real weapons, proven on a practice range. Full
pipeline again — owner interview (8 decisions) → approved spec → interactive mockup through THREE
owner gate revisions (hull ×1.7 then ×2.4; 6→4 small mounts with a blooming hose AA; class-distinct
turret art) → owner LOOK-LOCK ("if it doesn't look this good it doesn't get approved") → Godot port
verified side-by-side.

- **Sim:** three new systems in `Sim.step`'s fixed order behind Movement — `Drones.gd` (drifting
  air/surface practice targets, spawn/cull/respawn drawing 4 `world.rng` values per spawn in slot
  order), `Turrets.gd` (per-mount policy targeting CLOSE/STRONG, finite per-weapon traverse, bloom,
  hold-only force-fire: LMB all mounts with domain tags overridden, RMB large only; per-shot spread
  is the only draw), `Projectiles.gd` (pooled shells — `Pool`'s first real consumer — direct hits +
  splash bursts, kills/respawn). `GameWorld` gains mounts/drones/projectiles/kills and a one-way
  `effects` queue that Main plumbs to the renderer. `InputState` gains force flags + the WORLD-space
  cursor (Main converts; the sim never sees the screen). New `Configs` bundle keeps `Sim.step`'s
  signature flat as systems accumulate.
- **Config (per-system):** `hardpoint.tres` (10-mount plan 4S/4M/2L + fixed test loadout),
  `weapons.tres` (3-starter catalog as `WeaponDef` sub-resources: aa20 hose w/ bloom, dp5
  dual-purpose, mb16 splash battery), `range.tres` (practice-range shape).
- **Render/UI (LOOK-LOCK port of mockup rev 3):** battleship-scale hull (×2.4) with funnel/bridge/
  helipad/bow-jack; class-distinct turret art ON the hull (D1.5) — twin-barrel armored L turret with
  muzzle brakes + rangefinder ears on a hull-fixed barbette, angular single-gun M house with recoil
  sleeve, open-ring S AA mount — all with render-side recoil kick; drones, tracers, shells,
  muzzle/splash/death/hit effects; force-fire reticle with order label; BATTERIES line + kills plate
  in the HUD; LMB/RMB input map.
- **Verify:** `tests/probe_hardpoints.gd` (8 checks mirroring the mockup validation harness:
  determinism incl. force-fire, traverse ceiling, domain filter, policies, both force modes +
  release, kill/respawn, isolated splash kill, bloom rise/decay) as a new `verify.sh` step.
  `probe_movement` now runs with a drone-free range so its zero-RNG movement tripwire stays exact.
  `tests/ScreenshotC2.tscn` drives helm + force-fire under Xvfb for the side-by-side look check.
- **Decisions:** open thread #5 resolved; D1.7 refined (360° engagement, traverse-limited); D1.9
  domain tags are now live mechanics.

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
