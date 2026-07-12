# Research — the genre survey, weather, whirlpools, and the detail pass

> Four-angle research pass (2026-07-12) feeding the owner interview for the next arc. Games surveyed:
> World of Warships, HighFleet, Cold Waters, Sea Power, UBOAT, Destroyer: The U-Boat Hunter, Naval
> Action, Sid Meier's Pirates!, Sunless Sea, Dredge, Abandon Ship, Ship of Fools, Sea of Thieves,
> FTL, Nebulous — plus real-world strait oceanography (Naruto, Corryvreckan, Messina) and 2D
> weather-rendering / photosensitivity practice. Everything here is RESEARCH, not decision — the
> owner interview picks; `/spec-feature` locks. Companion mockup: `design/the-tempest.html`.

---

## 1. What the genre has that we don't (ranked by fit × size)

1. **Subsystem damage + one Damage Control party** (WoWS modules / FTL rooms) — turrets/sonar/
   engine knockable, fire/flood DOTs, one repair allocation. The genre's most universal system;
   our ship is a flat 10-pip pool. ⚠ *Adjacent to the scrapped RPG-depth arc (owner is reworking
   that direction himself) — needs his explicit go before any interview.*
2. **Smoke screen / decoy countermeasures** (Sea Power, Nebulous) — the game currently has zero
   defensive verbs besides steering. Small-medium, on-fiction vs drone swarms.
3. **Ammo-type selection per battery** (WoWS HE/AP) — rides the existing domain-tag + force-fire
   systems; multiplies depth without new entities. Small.
4. **Tanker-convoy protect waves** (Destroyer: The U-Boat Hunter) — every Nth wave a tanker
   transits the strait and must survive. *The single best fiction fit found: Hormuz IS tanker
   traffic.* Medium.
5. **Seeded weather fronts** (SoT / Abandon Ship / FTL-node pattern) — see §2. Medium.
6. **Night phase + star-shell illumination** (Dredge, Destroyer) — detection collapse + light as
   counterplay; pairs with weather as one "conditions" chunk. Medium-small.
7. **Thermal layer for subs** (Cold Waters) — a depth band hiding subs from sonar until they rise
   to fire. Small; sharpens C5.
8. **Choice-bearing FLEET RADIO requests** (FTL events in radio-traffic clothing) — rare
   between-wave pick-one tradeoffs. ⚠ Brushes the scrapped draft arc; owner call first.

**Skip (wrong scale/tone):** crew simulation, boarding, player port economy, cargo-Tetris.

## 2. Weather — the design stance

Three tiers seen in the wild: (i) render-only mood; (ii) **light tactical layer — modifiers on
existing systems** (RimWorld accuracy/fog, Dredge information-denial, FTL's known-costed ion-storm
nodes); (iii) full wind physics (Naval Action — colonizes the whole design; skip). **Tier (ii) is
the fit.** Key findings:

- **Discrete seeded schedules beat continuous noise.** Roll a front schedule off the seed at run
  start ("squall arrives wave 6, lasts through 8") — deterministic by construction, forecastable
  ("STORM WARNING: WAVE 6" is a natural FLEET RADIO line), tunable against wave pacing.
- **Best hooks, ranked:** (1) the seeded schedule; (2) rain attenuates detection — radar/sonar/
  visual ranges ×0.5–0.7, symmetric both sides, turns long-range waves into knife fights for one
  multiplier; (3) **lightning flash paints undetected contacts for ~1 s** — spectacle becomes
  information, the flash becomes something you *want*; (4) the squall as a drifting local band you
  can enter/exit (hide your wake in it) rather than a global state flip.
- **Worst hook:** lightning as random damage — unattributed damage poisons a deterministic game.
- **Photosensitivity is a day-one constraint (WCAG 2.3.1):** ≤3 flashes/second (target far fewer),
  flash = a ~16% scene lift with ~150 ms decay, never hard white, never red; minimum strike gap
  enforced in the *schedule* so render can't stack them; a reduce-flashing option that keeps the
  information (UI ping) while dropping the spectacle. No weather camera shake, ever.
- **Pitfall #1: screen noise.** Rain must never out-contrast torpedo wakes and telegraphs — thin
  the streak layer near dense combat.
- **Dead-mechanic law:** render-only rain presented as a "weather system" violates our own D-law —
  every weather state ships with ≥1 sim hook, or it's just a shader preset.

## 3. Whirlpools — the restrained design (the real world is the gift)

Game precedents split into orbit-timer set-pieces (Wind Waker), inert discs (Sunless Sea), drag
fields (Deepwoken), teleporters (Ship of Fools), and boss arenas (God of War) — almost nobody has
shipped the **restrained drag-field-as-terrain** version. Real strait whirlpools point the way:
they are **bathymetric** (fixed at constrictions — Corryvreckan sits on a charted pinnacle),
**tide-clocked** (Naruto's vortices peak every ~6 h on schedule), and **dangerous to small craft,
not big hulls** (no account exists of a large ship pulled under; the real threat is heading
disturbance). Mariners don't fight them — they *time* them.

Recommended shape (all deterministic, zero rng in the force):
- **Placement:** at map-gen beside C15 terrain — score island constrictions, seed 1–2 sites per
  run, fixed for the whole run (a charted feature, not an event).
- **Field:** analytic `v(p) = T(r)·perp(dir) − R(r)·dir`; tangential dominates radial ~3:1 (a rim
  crossed WITH the rotation is a slingshot; against it, a penalty — routing becomes play); radial
  pull **capped** (~30–40 % of battleship thrust — the cap is what makes it a whirlpool, not a
  black hole); intensity × a seeded slow **tide clock** keyed to wave count (dormant = crossable
  lane, peak = lane denied).
- **Mass-tiered:** battleship ×0.25 (a course bend + yaw — helm attention, never doom, no hull
  damage), small craft ×1.0 (shoved hard; capsize only at the very core at peak tide — a grinder
  you can herd GNATs into), torpedoes ×1.6 (visibly bent off their line — a shield you keep
  between yourself and the wolfpack).
- **Visual:** rotating foam spiral arms in the fleck language (rotation speed = tide intensity),
  ~20 % of Sea of Thieves' inky darkening with **darkening radius = influence radius** (the art is
  the hitbox), debris circling the rim, a small eye — no giant hole, no glow, no in-world rings.
  Diegetic audio: a low water-roar ramping with tide + proximity (Corryvreckan is heard for miles).
- **Config:** own `WhirlpoolConfig`/`.tres` (count, radii, T/R curves, tide period/floor,
  per-class multipliers) per the one-config-per-system rule.

## 4. The detail pass — top of the ranked catalog (20 candidates researched)

Pattern from HighFleet/WoWS/Dredge/FTL: **persistence** (the battle marks the world) and
**reactivity** (ambient life responds to you) buy more perceived aliveness than particle count.

| ★ | Detail | Cost | Plumbing |
|---|---|---|---|
| ★ | Funnel smoke tied to throttle, streams downwind | S | render-only |
| ★ | Oil slick + debris field where ships sank (fades ~60–90 s) | M | off existing kill event |
| ★ | Lingering cordite haze after sustained fire | S | render-only |
| ★ | Cloud shadows sliding across the sea | S | one sea-shader layer |
| ★ | Gulls that scatter when guns fire nearby | M | render-only, reacts to muzzle fx |
| ★ | Radar phosphor persistence + sweep trail (pure 1950s) | S | HUD-only |
|   | Ejected brass casings · gauge needle jitter · signal-lamp morse on contact latch · ambient flotsam · channel buoys off shoals · sub-death bubble column · near-miss spall sparkle · heel spray on hard rudder · signal flags per wave | S each | render-only |
|   | Distant neutral tanker silhouette between waves | M | render-only; must never blip the scope |
|   | Deck scorch accumulating where hits landed | M | needs a sim hit-location event |
|   | Lifeboat pulling away from a sinking gunboat | M | tonally heavy — owner call |

Rejected on tone/legibility: jellyfish glow, crew silhouettes (illegible at 0.40–0.85 zoom), fish
shoals. All of the above are render-only or ride existing effects — determinism untouched;
tunables belong in `field.tres` or a small `AmbienceConfig`.

## 5. Owner picks (interview 2026-07-12 — direction only; each chunk still gets its /spec-feature)

- **Weather → LIGHT TACTICAL LAYER.** Seeded front schedule rolled at run start; rain attenuates
  detection (radar/sonar/visual ×0.5–0.7, symmetric); FLEET RADIO forecasts the front. Lightning
  stays spectacle-only (the contact-reveal variant was offered and NOT taken).
- **Whirlpools → FULL TACTICAL TERRAIN.** Seeded at island constrictions, tide clock keyed to wave
  count, mass-tiered pull (battleship ×0.25 / small craft ×1.0 / torpedoes ×1.6), capped radial,
  no player hull damage.
- **Detail pass → three packs greenlit:** ship liveliness (funnel smoke, casings, signal lamp, bow
  spray, heel spray) + battle aftermath (oil slick + debris, cordite haze, sub bubble column) +
  ambient world (gulls-that-scatter, flotsam, buoys, cloud shadows; the neutral tanker silhouette
  stays optional). HUD grit (phosphor/needle jitter) was offered and NOT taken.
- **Next system interview queued: NIGHT + THERMAL LAYER** (dark waves + star shells; sonar layer
  subs hide under). Tankers, countermeasures, and ammo selection were offered and left on the
  shelf for now. Subsystem damage stays owner-reserved (scrapped RPG-depth territory).

## 6. Process notes

- `design/the-tempest.html` demos: 4 weather states (CLEAR / PASSING RAIN / SQUALL LINE /
  THUNDERHEAD with safe lightning), the restrained whirlpool with a live pull demo (ship, torpedo,
  flotsam all bend), and 8 of the detail candidates as individual toggles — on the approved C9-B
  sea, hull art LOOK-LOCK intact, reduced-motion honored.
- Nothing in this pass touches `.gd`/`.tres` — mockup + research only. Whatever the interview
  picks goes through its own `/spec-feature` interview → spec → gate → port, one chunk at a time.
- Determinism spine for everything above: weather = seeded schedule read by tick; whirlpool =
  analytic field, no draws; details = render-only off the existing one-way effects queue.
