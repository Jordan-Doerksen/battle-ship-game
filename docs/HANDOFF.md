# THE STRAIT OF HORMUZ — Project Handoff

> **Read this first.** It is the canonical current-state pickup doc for a fresh agent: what the game
> is, its identity, everything that's built, where it stands, the hard rules that will bite you, and
> how to build/verify. Pairs with `DECISIONS.md` (the manifest — locked decisions + Change Log) and
> `ARCHITECTURE.md` (the one-page map). Keep this file current as the project moves.
>
> **Last updated:** 2026-07-11.

---

## 0. TL;DR — the canon in ten lines

- **The game:** THE STRAIT OF HORMUZ — a deterministic top-down naval wave-survival roguelite in
  **Godot 4.7 / GDScript**. You command a lone battleship, cut off holding the strait against
  improvised asymmetric forces, surviving until a relief fleet arrives (it never does — the win
  condition is a future chunk).
- **Where the code is:** `C:\projects\battle-ship-game` (git, branch `main`, origin
  `github.com/Jordan-Doerksen/battle-ship-game`).
- **Repo state (2026-07-11):** **fully pushed and in sync** with `origin/main` — nothing uncommitted,
  nothing ahead or behind.
- **Built:** C0–C16 (the founding brief, systems-complete) + the polish arc + the world arc + the
  **identity pivot/reskin** + the **DC rework** + the **FLEET RADIO** + enemy-craft polish + the
  HelmGauges housekeeping split. All shipped, all gated green, all pushed.
- **What's NOT built / next:** the **WIN-MODE chunk** ("hold until the fleet arrives" payoff; ZAHHAK
  reserved as the final boss) — its own future interview.
- **Recently scrapped (do not rebuild unprompted):** an **RPG-depth card-draft arc** (a between-wave
  card draft + progressive damage + doubled waves) was researched, spec'd, and mockup'd on 2026-07-11,
  then **scrapped at the owner's request — he is reworking that direction himself.** Zero Godot code
  was ever touched by it; it reverted clean. See §4.
- **The one rule above all:** determinism is sacred (all gameplay randomness through `world.rng`),
  one-way sim→render, config in per-system `.tres`, and every visual change goes through the mockup
  gate (mock → approve → port).

---

## 1. What this is

**THE STRAIT OF HORMUZ** is a deterministic naval wave-survival roguelite. One battleship, alone,
against swarms rising from **air, sea surface, and the deep**. The whole point is a visible,
purchasable-feeling hardpoint layout on a heavy hull you actually pilot (real momentum, wide turns),
guns that auto-target with a hold-to-force-fire override, over-the-horizon main-battery fire, sonar +
depth charges for the deep, an ASW helicopter wing, war-machine bosses, seeded terrain, and a
formation-based wave director.

It is a **sibling project of `fulfillment`**, reusing its proven architecture (deterministic sim,
hybrid render, entity pooling) **re-derived fresh, never copied** (`DECISIONS.md` D1.1/D1.3). Full
narrative/systems brief: `docs/DESIGN-BRIEF.md`.

**The process is the project:** build **design-first, one fully-fleshed chunk at a time — mechanics
AND visuals — cross-checked against the manifest before the next chunk.** No dead mechanics, no orphan
pointers, no dead tags left behind. Every visual chunk is proven as an HTML mockup in `design/` and
owner-approved before it is ported to Godot.

---

## 2. Identity & tone (CANON since 2026-07-10 — the reskin)

The game was formerly the working title "Earth Defense Force" with B-movie alien schlock. **That is
retired.** The current, canonical identity (owner-decided, reskin applied and pushed):

- **Name:** *The Strait of Hormuz* (`project.godot` `config/name="The Strait of Hormuz"`). Title:
  THE STRAIT / OF HORMUZ · HOLD THE LINE · "Cut off in the strait. Hold until the fleet arrives." ·
  STAND TO · TASK FORCE 50 · STRAIT PICKET.
- **Premise:** a lone battleship cut off holding the strait, surviving until the relief fleet arrives
  — which never comes (that promise is the story hook; the actual win condition is a future chunk).
- **The enemy:** improvised, mass-produced asymmetric forces — jury-rigged drones, small craft, and
  midget-subs thrown in numbers (the in-fiction reason each contact is individually weak).
- **Voice: a grounded holdout thriller** — strictly tactical/hardware register. The B-movie camp is
  gone.
- **⚠ SENSITIVITY GUARDRAIL (hard rule):** the enemy fiction stays **tactical and hardware-focused**.
  **Never caricature a people, culture, or religion.** Keep it to gear and tactics — grounded
  military fiction only.
- **Reporting names KEPT** (they read as NATO callsigns): GNAT / JACKAL / VULTURE / WASP / LAMPREY.
- **Boss codenames = Persian folklore** (Shahnameh/Avesta *monster*-bestiary, sensitivity-vetted — no
  sacred/benevolent figures), display-name only, mechanical ids unchanged:
  - **FULAD** (the surface juggernaut — "steel-clad demon" with one weak point)
  - **KAMAK** (the air canopy — the sky-blotting bird)
  - **GANDAREVA** (the deep maw — the sea-dragon "half in air, half in ocean")
  - **ZAHHAK** (the arch-dragon) is **reserved for the future final boss** (win-mode chunk).
- **The FLEET RADIO** (TF50 ACTUAL) is the story engine: animated fleet comms that warn about incoming
  formations, teach mechanics, flag obstacles, and run a relief-cycle that never resolves.

---

## 3. What's built (chunk history — all BUILT, gated green, and PUSHED)

Each chunk went interview → approved spec → owner-approved HTML mockup → Godot port verified against
it, with a `probe_*.gd` gating it in `verify.sh`. Specs live in `docs/specs/`; mockups in `design/`;
the full narrative is `docs/CHANGELOG.md`.

**Founding systems (C0–C7):**
- **C0 Heartbeat** — fixed-60Hz deterministic loop, seeded `Rng`, `GameWorld` truth object.
- **C1 Naval movement** — `Movement.gd`, `InputState` one-way input door, `movement.tres`;
  held-throttle w/ brake-to-astern, speed-coupled turn authority, anisotropic drag.
- **C2 Hardpoint hull & gunnery** — `Turrets`/`Projectiles`, the `Configs` bundle, class-distinct
  traversing turret art **on the hull**, hold-force-fire (LMB all / RMB main). The C2 render is
  **LOOK-LOCKED**.
- **C3 Wave director & first enemies** — seeded budget director, swarmer/gunboat/bomber roster, hull
  pips + grace, SHIP LOST + fresh-seed restart, radar scope + fire-control bearing, over-the-horizon
  main battery. *(Superseded by the C16 director — see below.)*
- **Economy direction change (D-level):** the hardpoint *purchase* economy is DEAD — ships have set
  hulls/turrets; progression is persistent levels unlocking a **tech tree**.
- **C4 Levels & tech tree** — persistent career XP/levels in the FIRST save file
  (`user://profile.cfg`, app-layer only); `Tech.apply` derives each sortie's Configs from duplicated
  base resources + unlocked nodes (zero tech = byte-identical baseline, probe-gated); the tree screen,
  title hub, lost-card XP report; four "marquee" sim features behind default-OFF flags; the DEV TEST
  KIT (debug builds only, `` ` `` to toggle).
- **C5 Sonar, subs & depth charges** — `sub` elite torpedoing from standoff; `Sonar.gd` passive
  detection + contact latch; `DepthCharges.gd` contact-gated volleys; NO gun can hurt a sub (domain
  exclusion). SONAR tech branch.
- **C6 AIR WING** — the stern pad flies an autonomous, invulnerable ASW wingman (`AirWing.gd`):
  escort weave + speed-coupled throttle, dipping sonar on the C5 latch, contact-centered light drops,
  door gunners. The "deaf-deep" law went physical (shells/airbursts skip submerged hulls).
- **C7 Boss ladder & naming** — every 5th wave a war machine (`Bosses.gd`): parts + phases +
  soft-gated cores; per-part XP + lap bounty + hull patch. The reporting-name newsreel tally +
  PRIORITY TARGET plate.

**Polish arc (C8–C13):**
- **C8 Bug batch** — nine fixes from the first adversarial full-code sweep, all red-green probe-gated.
- **C9 THE LIVING SEA** — render-only sea shader on Main's `SeaLayer` (bands/glints/crests), heave/
  roll/hull-shadow ride, churned wake + bow wave, splash columns w/ per-battery dye, DC glow, air
  shadows; **`FieldRenderer` split** into `SeaRender`/`ShipRender`/`HostileRender`/`FxRender`.
  `verify.sh` now also fails on **SHADER ERROR**. Probes stay byte-identical (render-only proof).
- **C10 TACTICAL ZOOM** — wheel 0.40–0.85, home 0.51, `H` snaps home; `CameraConfig`/`camera.tres`;
  stroke compensation through render helpers (LOOK-LOCK intact); 10 px min-size floor on hostiles.
- **CREWED GUNS** — the S mounts are person-manned MGs (bursts w/ rest gaps, wild spread, per-round
  reach rolls stitching the water; air+surface, the deep stays deaf). Planes made scarier by design.
- **C11 LONG-RANGE FIRE CONTROL** — forced main-battery shells burst AT the cursor within range;
  flight-time + MAX RANGE reticle telltales; fall-of-shot on the scope; RANGEKEEPER (ord7 advisory
  intercept ghost). Tree = 37 nodes / 65 pts / level 66 = everything.
- **C12 READABILITY & FEEL** — 13 baked WAVs (`tools/gen_sfx.py`) + `SfxPlayer` on the effect channel
  (`AudioConfig`/`audio.tres`); klaxon/waveclear/torpwater; `P` pause (the war waits, the sea drifts);
  key-only lost card; five once-per-profile drip hints; wounded tells.
- **C13 FIELD MANUAL** — nine live-vignette pages (`M`) + a show-off attract mode (full tree, godmode,
  cranked director). `TutorialScreen.gd` / `TutorialVignettes.gd`.

**World arc (C14–C16) + the air-threat rework:**
- **C14 THE HULL** — ×2.75, art + capsule together.
- **AIR THREAT** — VULTURE became a torpedo bomber; the WASP rocket plane joined the roster
  (`EnemyDef.salvo`). Fixed the "AFK to a boss" problem.
- **C15 THE WATERS** — seeded archipelagos (`Terrain.gd`/`terrain.tres`, `TerrainRender.gd`), the
  land-rule blocking matrix (land blocks all vessels + all naval gunfire incl. mb16; air ordnance/AA/
  doorgun pass; torpedoes die on rock; the deep does not pass under), sliding collision + grind pips,
  waterborne avoidance. `probe_terrain`.
- **C16 THE WAR, REPACKED** — the formation/echelon director (`WaveConfig.templates()`: 6 formations;
  vanguard/main/sting echelons; real quiet; terrain-aware lanes + behind-the-rock ambushes),
  composition on a **`(seed, wave)` substream** (zero director `world.rng` draws → the war is
  play-independent per seed). Superseded the C3 greedy spend. Spec: `docs/specs/the-war-repacked.md`.

**Identity & comms batch (2026-07-10, all built + pushed):**
- **The reskin** — see §2 (title/wave-plate/`project.godot` copy grounded; name audit clean).
- **DC REWORK** — the stern racks now **RANGE the scattered pattern onto the detected contact**
  (toward it, clamped to `dc_range`, at least `dc_ring` to clear the hull) instead of a blind stern
  arc; sonar/reach values retuned; rng draw-count per volley unchanged (determinism holds). A cosmetic
  sweeping radio/radar dish rides the render clock.
- **FLEET RADIO** — `RadioComms.gd` (app-layer, one-way, never touches `world.rng`) drives TF50 ACTUAL
  traffic (wave-forming reads the formation + bearing, boss-arrival names the folklore boss, obstacle/
  wave-clear, the C12 teaching drips absorbed, the relief cycle that never resolves); `RadioPanel.gd`
  teletype top-right (fixed 300×92); the dish pulses a foam ring; `radio.wav` chime.
- **Enemy-craft polish** — menacing improvised-craft silhouettes in `HostileRender` (JACKAL fast-
  attack boat w/ welded rocket rail + deck-gun turret; GNAT seeker core; WASP rocket rails; VULTURE
  twin-boom torpedo bomber). Render-only.
- **HelmGauges housekeeping split** — `HelmGauges.gd` reduced to a slim orchestrator over render-domain
  helpers `GaugePanel` / `StatusPlates` / `RadarScope` / `HudOverlays` / `RadioPanel` (the C9
  FieldRenderer precedent). No behavior change.

**Demo packaging (works):** 4.7 Windows export templates are installed; `export_presets.cfg` (local,
gitignored) builds a single self-contained ~110 MB exe (`embed_pck`, excludes tests/design/docs). See
§8 for the recipe. A first demo zip shipped to Downloads.

---

## 4. Where it stands & what's next

**The founding brief is SYSTEMS-COMPLETE; the polish, world-arc, and reskin directives are all
discharged and pushed.** `main` is in sync with `origin/main`, working tree clean.

**Next (open, not started):**
- **The WIN-MODE chunk** — the payoff of the relief-fleet promise ("hold until the fleet arrives").
  Interview the shape (survive-the-ladder vs a countdown vs endless-with-a-horizon); **ZAHHAK** is the
  reserved final boss. This is a fresh `/spec-feature` interview.

**Recently SCRAPPED — do not rebuild unprompted (2026-07-11):**
An **RPG-depth card-draft arc** was explored and then scrapped at the owner's request — he is
**reworking that direction himself.** For the record (in case it's revisited): it was a between-wave
**card draft** (pick 1-of-3 + reroll/banish), **progressive damage** (a weighted crit table disabling
up to 5-of-10 mounts, never fully), and **doubled wave sizes**, backed by a 6-angle genre-research
pass, a spec, a DECISIONS chapter, and an interactive mockup. **All of it was deleted; zero Godot code
was ever touched** (it was design-only and reverted clean). If the owner brings RPG-depth back, treat
**his own rework as the source of truth** — the prior research/decisions are recoverable from the
2026-07-11 session transcript but are not canon.

**Open narrative threads** (`DECISIONS.md` "Not Yet Decided"): #1 the water-mystery/mission framing
(low priority). The old working-title/trademark thread is effectively resolved by the rename to *The
Strait of Hormuz* (a public repo/store rename is an optional later step; the folder is still named
`battle-ship-game`).

**Scope guard:** D1.12 locks ONE hull until explicitly revisited — hull variety is a scope expansion
requiring a Change Request, not a drift.

---

## 5. Tree layout (accurate as of 2026-07-11)

```
scripts/
  app/            root scene + loop plumbing + meta + comms
                    Main.gd        state machine (title|tree|game|manual), InputState pre-step,
                                   effects plumbing post-step, sortie restarts, pause, attract
                    Profile.gd     the save file (xp, unlocked nodes, seen_hints) — app-layer only
                    Tech.gd        config derivation (Tech.apply) + spend/respec rules
                    RadioComms.gd  FLEET RADIO engine (TF50 ACTUAL), one-way, never touches world.rng
  engine/         the deterministic sim
    Sim.gd        step root — FIXED order: Movement, Waves, Enemies, Bosses, Sonar, DepthCharges,
                  AirWing, Turrets, Projectiles  (the order IS part of determinism)
    data/         GameWorld (truth object + rng + effects queue), InputState, Configs (bundle)
    entities/     plain data classes: Enemy, Projectile, Mount, Boss
    systems/      static funcs mutating GameWorld: Movement, Turrets, Projectiles, Waves, Enemies,
                  Hull, Sonar, DepthCharges, AirWing, Bosses, Terrain
    util/         Rng (seeded, .calls tripwire), Pool (projectile pooling)
  render/         one-way sim → view (never mutates sim)
                    FieldRenderer (orchestrator) + SeaRender / ShipRender / HostileRender / FxRender /
                    TerrainRender ; SfxPlayer (audio off the same effect batch) ; sea.gdshader,
                    patina.gdshader
  ui/             screens + HUD
                    HelmGauges (orchestrator) + GaugePanel / StatusPlates / RadarScope / HudOverlays /
                    RadioPanel ; TitleScreen, TechTreeScreen ; TutorialScreen + TutorialVignettes
                    (field manual) ; DevKit (debug builds only)
config/           typed Resource tunables — one <Domain>Config.gd + .tres per system
                    movement · hardpoint · weapons · sim · field · camera · audio · progress · tech ·
                    sonar · airwing · bosses · enemies · waves · terrain  (+ their *Def.gd sub-resources)
docs/             HANDOFF.md (this file) · DECISIONS.md · ARCHITECTURE.md · CHANGELOG.md ·
                  DESIGN-BRIEF.md · specs/*.md (one per chunk)
design/           approved HTML mockups (visual spec — mock → approve → port)
tests/            probe_*.gd (verify.sh runtime checks) + ScreenshotC*.tscn harnesses
tools/            gen_sfx.py (seeded WAV generator)
play.bat          double-click launcher
```

**Config-per-system rule:** each system owns a small `<Domain>Config.gd extends Resource` + a `.tres`,
carried by `Configs.gd` (`defaults()` + `load_all()`) and duplicated in `Tech.apply()` so it rides the
per-sortie derivation. Never a shared monolith; never `.json` (repo law is `.tres`).

---

## 6. Hard rules (full detail in `DECISIONS.md`)

- **Determinism is sacred** — ALL gameplay randomness through `world.rng` (seeded, stable order); same
  seed ⇒ same run. Cosmetic-only effects may use a separate `RandomNumberGenerator`, never the sim's.
  Determinism precedent worth copying: the C16 director draws ZERO from `world.rng` (per-wave
  `(seed, wave)` substream) so player timing can't shift the stream.
- **One-way sim → render** — the sim never reads node/render state; render/UI/SFX never mutate sim.
  The only channel is `world.effects` (sim appends dicts; `Main._process` drains to
  field/gauges/sfx, then clears).
- **Tunables live in `config/*.tres`**, never hardcoded; one small config per system, never a monolith.
- **No dead mechanics** — a system is "in" only when mechanical AND visual AND cross-checked against
  the manifest, and its probe is wired into `verify.sh`.
- **Turret/hardpoint art renders ON the hull**, not HUD-only (inverts fulfillment's D1.5 — intentional).
- **Mockup gate** — every visual chunk is proven as an HTML mockup in `design/` and owner-approved
  BEFORE porting to Godot.
- **`prefers-reduced-motion` is honored** everywhere (the `reduced_motion` field in `field.tres`).
- **Grounded-fiction sensitivity guardrail** — see §2: tactical/hardware only, never caricature a
  people/culture/religion.
- **No silent architecture drift** — anything touching design/behavior/config/determinism gets a
  Change Request that updates `DECISIONS.md`'s Change Log. New feature → `/spec-feature` interview →
  spec → owner approval → implement in a fresh session.

---

## 7. Build / run / verify

**The gate (run the full stack before any push):**
```bash
GODOT="/c/Users/Doerk/Downloads/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64_console.exe" \
  ./verify.sh
```
- The Downloads item `Godot_v4.7-stable_win64.exe` is a **folder** named `.exe`; the **console** build
  `Godot_v4.7-stable_win64_console.exe` inside it is the one to use (it surfaces SCRIPT/SHADER errors
  to stdout). Without the `GODOT=` override, verify.sh looks for a bare `godot` on PATH (absent here)
  and aborts.
- **Quick (syntax only, after every edit):** `./verify.sh quick`
- **Full stack:** gdparse sweep → import (.godot/.uid regen) → boot the real game 300 frames → all 9
  probe suites: `probe_{sim,movement,hardpoints,waves,tech,sonar,airwing,bosses,terrain}.gd`.
- **What FAILS the gate:** any nonzero Godot exit, OR the string **`SCRIPT ERROR`** or **`SHADER
  ERROR`** anywhere in stdout/stderr (the grep exists because Godot exits 0 even on runtime script
  errors). Quick mode fails on any gdparse `PARSE FAIL`.
- A green run ends with `ALL VERIFY STEPS PASSED` and zero SCRIPT/SHADER ERROR.

**Play it (human gate):** double-click **`play.bat`** (launches the Downloads Godot against the
project; window title may still say the old working title — cosmetic only).

**GOTCHAS (from `CLAUDE.md` / `windows-dev-gotchas`):**
1. **gdparse is necessary-not-sufficient** — syntax only; a method can parse and not exist at runtime.
   Only the import/boot gate proves a script compiles.
2. **Godot rejects nested same-name loop vars** (`for i` inside `for i`) that gdparse tolerates — a
   hard parse error (found at C12). Rename inner loop vars.
3. **The `%~dp0` quoted-arg trap** in `play.bat` — `%~dp0` ends in a backslash; the fix is a trailing
   dot: `--path "%~dp0."`. Don't remove the dot.
4. **A `.bat` written by an LF-only editor mis-parses in cmd.exe** — CRLF-normalize any `.bat` you
   generate.

**Git convention (owner):** finished work goes **direct to `main`, then push — no PRs** (git is
backup, not process). Only branch/PR if explicitly asked. Currently `main` is in sync with
`origin/main` (no ahead/behind).

---

## 8. Demo packaging (the recipe — works)

```bash
GODOT_EDITOR="/c/Users/Doerk/Downloads/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64.exe"
"$GODOT_EDITOR" --headless --path . --export-release "Windows Desktop" "<out>/The Strait of Hormuz.exe"
```
Produces one self-contained ~110 MB exe (engine embedded, no install; unsigned → SmartScreen "Run
anyway"). Smoke-test with `--headless --quit-after 200`. Zip via .NET `ZipFile`
(`includeBaseDirectory=$true`), NOT `Compress-Archive`; retry once on a Defender read-lock; verify the
zip with Python `zipfile`; deliver to `C:\Users\Doerk\Downloads` + `explorer /select`. `export_presets.cfg`
is local/gitignored (product name "The Strait of Hormuz", excludes tests/design/docs).

---
*This is the canonical pickup doc. Depth lives in `DECISIONS.md` (the law), `ARCHITECTURE.md` (the
map), `docs/CHANGELOG.md` (chunk-by-chunk), and `docs/specs/*.md` (per-chunk specs). Keep it current.*
