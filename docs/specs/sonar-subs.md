# Spec — C5: Sonar, Submarines & Depth Charges

**Status:** BUILT 2026-07-09 · Spec APPROVED 2026-07-08 (owner) · Mockup APPROVED 2026-07-09
(owner: "approved thast was totally cool" — `design/sonar-subs.html` stays the visual reference) ·
Gated by `tests/probe_sonar.gd` in `verify.sh`
**Completes:** the founding three-domain fantasy (air / surface / SUB — D1.9). **Implements:** D1.10
(passive sonar, radar-gated sub visibility) and D1.11 (free always-on inaccurate depth charges) —
with one owner refinement at interview: **charges arm only on a sonar CONTACT** (supersedes
D1.11's "backstop for whatever sonar misses" clause; recorded in the Change Log at build).

## Goal

Put something under the water. Submarines are elite, invisible hunters that torpedo you from
standoff; passive sonar is the only thing that can see them; depth charges are the only thing that
can kill them — and they only arm when sonar holds a contact. The third domain plays like nothing
else in the game: you don't shoot at it, you *listen* for it, then drive your stern over it.

## Owner interview decisions (2026-07-08)

1. **Torpedoes with visible wakes.** Subs hold deep at standoff and launch slow, straight-running
   torpedoes that draw a foam wake on the surface — heavy damage, dodgeable by reading the line.
2. **Undetected subs leave a faint ripple tell** when near the surface close to the ship — nothing
   on radar, just water that moves wrong. B-movie dread over readability.
3. **Depth charges are the ONLY sub killer.** Every gun's domain tags exclude `sub`; the deep is
   deaf to gunfire.
4. **New SONAR branch in the tech tree** (sixth column) — detection radius, contact hold, and
   depth-charge pattern upgrades, with a marquee at the tip. D1.10's "upgraded through the same
   economy" now means the tree.
5. **DC trigger: DETECTED subs only** (owner supersession of D1.11's blind-backstop clause).
   Charges stay free / always-on / automatic / deliberately inaccurate — but without a sonar
   contact they never arm. No contact, no ASW: the SONAR branch is load-bearing.
6. **Pattern: stern rolls + side throwers.** A volley scatters charges behind/around the aft half;
   they sink on a fuse, then detonate in underwater blast rings. Bad accuracy = wide scatter — subs
   are fought by DRIVING the stern over the contact.
7. **Sub is an elite:** budget cost 6, unlocks at wave 7 — one or two per wave changes how you sail
   the whole wave.
8. **Torpedoes are slow + relentless:** ~130 u/s with a ~900 u run — seconds of warning off the
   wake line, outrunnable at full ahead, 2 pips if one connects.

## Player-facing behavior

- **Wave 7+:** the wave plate counts a contact you cannot find. Nothing on the scope. Then either
  the water ripples wrong off your beam, a torpedo wake draws a line at your hull — or your sonar
  ring finally sweeps over something and a **diamond blip** appears with a `SONAR CONTACT` ping.
- **Detected subs** show as diamond blips on the radar (and a dark shape with a foam ring in the
  world view). Detection is the ship's **sonar radius** (drawn on the scope as a soft inner ring);
  once held, a contact persists for a short **contact-hold** after it slips outside.
- **Torpedo wakes** are unmissable white lines crawling across the water. Steer off the line; at
  full ahead you can outrun one chasing your stern.
- **Depth charges** are fully automatic: with a detected sub inside close range, racks roll and
  side throwers lob a scattered volley; charges splash, sink for a beat, then the water bulges
  with underwater blasts. Kills read as a deep concussion + oil slick ring.
- **The SONAR tree branch** turns a terrifying lottery into a hunt: longer ears, longer holds,
  tighter and bigger patterns.

## Mechanics

- **Enemy roster + `sub`** (`enemies.tres`): layer `sub`, hp 6, speed 35, turn 0.5, radius 16,
  cost 6, unlock 7, standoff 600, fire range 800, fire period 8.0 s, torpedo speed 130, torpedo
  dmg 2 (pips), lead 0.5, spread 0.03. Movement reuses the gunboat brain (approach → slow orbit at
  standoff). Its "shells" are TORPEDOES: hostile projectiles with a long run (~900 u), a rendered
  wake trail, hull-capsule impact through the grace window.
- **Layer/domain:** `sub` is a first-class D1.9 domain. `pickTarget` already filters by weapon
  domains — no current gun carries `sub`, so turrets ignore submarines by construction (probe-gated).
- **`Sonar.gd`** (new system, after Enemies): per sub, detected := dist(ship) ≤ radius, latched for
  `contact_hold` seconds after leaving. Detection state lives on the Enemy (`detected_until`) — pure
  arithmetic, no draws. Emits a `contact` effect on first acquisition (HUD ping).
- **`DepthCharges.gd`** (new system, after Sonar): when any DETECTED sub is within `dc_range` of
  the ship and the rack cooldown is idle, drop a volley of `dc_count` charges at seeded scatter
  offsets around the aft half (stern arc); each charge inherits a stern position, sinks for
  `dc_fuse` seconds, then detonates: damage `dc_dmg` to SUBS within `dc_blast` (underwater blast —
  surface/air enemies and the ship are unaffected). Scatter draws from `world.rng` in volley order.
  Charges are pooled `Projectile`s (`wid: "dc"`, near-zero velocity, life = fuse).
- **Ripple tell (render-only):** an undetected sub within `ripple_range` of the ship draws a
  barely-visible drifting disturbance at its true position — cosmetic, no sim state.
- **Radar:** sonar radius as a soft inner ring; detected subs = diamond blips; torpedoes = bright
  wake sparks (they're surface-visible by design). Undetected subs: nothing, per D1.10.

## Config — `config/SonarConfig.gd` + `sonar.tres` (per-system rule)

| Tunable | Start | Meaning |
|---|---|---|
| `radius` | `350` | base passive detection radius (torpedo range is 800 — close the gap in the tree) |
| `contact_hold` | `2.5` | seconds a contact persists after leaving the radius |
| `ripple_range` | `260` | undetected-sub cosmetic tell distance |
| `dc_range` | `220` | contact distance that arms the racks |
| `dc_count` | `4` | charges per volley |
| `dc_ring` | `85` | throw-station ring radius (added 2026-07-09, owner tune at the C7 gate: the volley became a K-GUN SPREAD — stations evenly around the beams and stern, scatter jittering each station — because the auto-firing racks were "too hard" when piled on one stern point) |
| `dc_scatter` | `90` | jitter around each throw station (was: scatter around the single stern point) |
| `dc_fuse` | `1.5` | sink time before detonation |
| `dc_blast` | `55` | underwater blast radius |
| `dc_dmg` | `3` | damage per blast (hp-6 sub ≈ two good volleys) |
| `dc_cooldown` | `4.0` | seconds between volleys |

**SONAR tree branch** (`tech.tres`, sixth column; costs 1/1/2/2/3): son1 *Hydrophones* +25% radius ·
son2 *Trained Ears* +2.0 s contact hold · son3 *Deep Pattern* +2 charges/volley · son4 *Quick
Racks* −30% volley cooldown · son5 **ASDIC LOCK** (marquee): −50% scatter, +30% blast radius — the
pattern falls tight on the contact. Sub kill XP: 80 (`progress.tres`).

## Visual spec (mockup gate: mock → approve → port)

`design/sonar-subs.html` — extends the approved C4 career mockup (full loop, LOOK-LOCK carried):
subs + torpedo wakes + ripple tell + sonar ring/diamond blips/contact ping + DC volleys
(splash → sink → underwater blast → oil-slick kill) + the SONAR tree column + a dev-kit `+SUB`
button. Owner judges the dread (ripple), the torpedo dodge, the stern-positioning DC game, and
whether the SONAR branch feels worth the points; approves; then it ports.

## Determinism notes

- New `world.rng` draws: DC scatter (per charge, volley order) and the sub's torpedo spread (same
  slot-order rule as gunboats). Detection/latch/fuses are pure arithmetic.
- The ripple tell and all sonar HUD reads are render-side one-way; the sim never stores a
  "visible" flag beyond `detected_until`.

## Acceptance checks (`tests/probe_sonar.gd`; verify.sh step)

1. **Determinism:** scripted run with subs, torpedoes, and DC volleys → two worlds byte-identical,
   `rng.calls` equal.
2. **Deaf guns:** a lone sub inside every gun's range draws ZERO muzzle effects in auto (domain
   exclusion by construction).
3. **Detection + latch:** outside radius → not detected; inside → detected + one `contact` effect;
   after leaving, detected persists exactly `contact_hold` then drops.
4. **DC trigger law (owner rule):** an UNDETECTED sub at point-blank never triggers a volley; a
   detected sub inside `dc_range` triggers on cadence; scatter stays within bounds; detonation at
   `dc_fuse`.
5. **DC kill + isolation:** volleys kill an anchored sub; the same blasts leave a surface gunboat
   and the ship untouched.
6. **Torpedo:** fired on period from standoff; runs straight and expires ~900 u; a hull hit costs
   exactly 2 pips through the grace window; a stern-chase at full ahead never connects.
7. **Tree:** SONAR nodes derive radius/hold/count/cooldown/scatter correctly; with zero tech,
   behavior is byte-identical to pre-C5 for waves 1–6 (sub unlocks at 7).
8. Existing probes (sim, movement, hardpoints, waves, tech) pass unchanged.

## Out of scope (explicit cuts from the interview)

- Active sonar ping (D1.10 locks passive-only for MVP).
- Sub-capable GUNS (hedgehog/mortar etc.) — a future tree/weapon chunk if ever.
- Helicopter/AIR WING (open thread #3), boss ladder + naming (open thread #2).
- Depth simulation (subs have no depth value — they're "under", binary).

## DECISIONS.md impact

At build time: log D1.11's refinement (owner: charges require a sonar contact — the blind-backstop
clause and the old "fight subs at range with real guns" framing are superseded; free/always-on/
auto/inaccurate all stand). D1.10 is implemented as specced (passive radius, radar-gated blips,
tree-upgraded). D1.9's third domain goes live.
