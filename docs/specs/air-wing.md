# Spec — C6: AIR WING (the Helicopter)

**Status:** APPROVED 2026-07-09 (owner) · Interviewed 2026-07-09 · Mockup BUILT (`design/air-wing.html`,
harness 8/8 incl. zero-tech byte-parity vs the shipped C5 sim) — AT THE GATE, awaiting owner
feel-approval · Not ported
**Resolves:** open thread #3 (helipad function — DECISIONS "Not Yet Decided" list). The helipad has
been part of the hull's visual identity since C1; the AIR WING tech column has sat CLASSIFIED since
C4. This chunk gives both their function.

## Goal

Put the bird in the air. An autonomous ASW helicopter flies off the stern pad — an AI-flown wingman
that extends the C5 sonar game outward: it makes contacts far from the hull, softens and marks what
it finds, and hands the kill back to your stern racks. It never replaces the drive-over-the-contact
game; it feeds it. B-movie spectacle first: rotor thump over the fleet, a dipping sonar, depth
bombs off a whirlybird.

## Owner interview decisions (2026-07-09)

1. **Autonomous wingman.** AI-flown, launches itself, fights alongside — zero player
   micromanagement. You command the ship; the bird flies its own war. (Fulfillment's `Fighters.gd`
   is the pattern ancestor, re-derived per D1.1/D1.3.)
2. **ASW specialist, nothing else.** Its whole job is the deep: it hunts submarines only. AA stays
   FLAK's job, surface stays the batteries'.
3. **Fuel loop, invulnerable.** It cycles: launch → long patrol → return to pad → rearm → relaunch.
   The rhythm is the limiter; enemies can never shoot it down (a tech investment is never lost to
   RNG).
4. **Node 1 IS the bird.** `air1` unlocks the helicopter itself — no tech, empty pad. Buying it
   declassifies the column (air2–5 stay ████-redacted on the board until air1 is owned).
5. **Detector-first kill chain (the C5-protection rule).** Its dipping sonar DETECTS — writing the
   exact same contact latch as ship sonar, lighting subs up on the radar far beyond your ring. It
   carries a LIGHT depth-charge rack (small pattern, 1 dmg) that softens and marks; the ship's
   stern racks remain the real killer. The stern game stays king.
6. **Contact-led patrol brain.** Default: hold a picket orbit AHEAD of the ship's course. The
   moment anything sub-shaped exists — a live contact (anyone's), or a fresh torpedo launch
   point — it breaks off and prosecutes that position. Reads like a real ASW screen.
7. **Long patrols:** ~45 s on station, ~10 s pad turnaround. The bird is a fixture of the battle;
   the pad visit is punctuation.
8. **Flies every wave regardless.** Sub-free skies still get the patrol — spectacle, and it's
   already on station when wave 7 hits. Its dips just find nothing.
9. **Marquee (`air5`): MAD GEAR.** Magnetic Anomaly Detector — any sub the BIRD detects stays
   permanently marked for the rest of the wave (no latch decay on its contacts). Ship-made
   contacts still decay normally.
10. **air2–air4 = Ears / Legs / Teeth.** One node per axis (see the tree table).

## Player-facing behavior

- **Buy `air1`, start a sortie:** the pad is no longer set dressing. A helicopter spins up on the
  stern helipad, lifts off, and takes station ahead of your course — a small orbiting silhouette
  with a rotor disc, drawing a soft dip-ring wherever it hovers.
- **When a sub exists** (a live diamond on anyone's scope, or a torpedo wake just appeared), the
  bird breaks orbit and runs it down. Over the position it dips — and if a detected sub is under
  it, it lobs a tight little 2-charge pattern: splash, sink, small underwater blasts. Light damage,
  but the contact is now LIT on your radar and holding — sail your stern in and finish it.
- **Fuel loop:** after ~45 s airborne the bird turns for home, flares over the stern pad, sits for
  ~10 s of rearm (visible on the pad), and lifts off again. While it's down, your ears shrink back
  to the hull ring.
- **The tree column declassifies:** air1 buyable as the program itself; owning it reveals the
  remaining four. MAD GEAR at the tip makes the bird's contacts permanent for the wave.
- **The wave plate and radar change nothing** — the bird only makes more diamonds happen, further
  out. D1.10's rule stands: no contact, nothing shown.

## Mechanics

- **`AirWing.gd`** (new system, after DepthCharges, before Turrets — fixed order): a single helo
  state machine on `GameWorld` (`helo_state`: `pad | outbound | patrol | prosecute | rtb`,
  `helo_pos`, `helo_heading`, `helo_fuel`, `helo_rearm`, `helo_drop_cool`). Inert (zero state
  writes, zero draws) unless `tech.helo` is set — zero-tech runs stay byte-identical to C5
  (probe-gated).
- **Picket:** patrol target = ship_pos + heading-forward × `picket_dist`; the bird orbits it at
  `orbit_radius`, matching the ship's advance. Launch/recover at the stern pad point (the C1 hull's
  helipad, y ≈ +65 hull-local).
- **Detection:** continuous passive radius `dip_radius` around the helo (the "dip" is render
  flavor — a periodic ring pulse). Writes `Enemy.detected_until = elapsed + contact_hold`
  (SonarConfig's hold — one latch, two listeners) via the same rule as `Sonar.gd`; emits the same
  `contact` effect on first acquisition. With MAD GEAR, bird-made contacts set an effectively
  permanent latch (wave-clear wipes the array anyway).
- **Prosecute:** priority = nearest live-contact sub (to the helo) → else the most recent torpedo
  launch point (`helo_mark`, recorded by Enemies.gd when a sub fires, held `investigate_hold`
  seconds) → else picket. Over a DETECTED sub within `drop_range`, if the drop cooldown is idle:
  a volley of `dc_count` light charges at seeded scatter (world.rng, volley order — same shape as
  the ship's racks), fuse/sink/blast reusing the C5 `"dc"` projectile branch with the helo's
  `dc_dmg`.
- **Fuel:** burns only airborne; at zero → `rtb`, fly home, land, `turnaround_secs` on the pad,
  relaunch full. State machine is pure arithmetic — the ONLY draws are drop scatter.
- **Invulnerable by construction:** the helo is not an `Enemy`, no hostile projectile tests it,
  nothing targets it. There is no damage path to close.
- **Render:** helo silhouette + spinning rotor disc + shadow offset, dip-ring pulse while
  hovering/prosecuting, pad spin-up/down animation, light-pattern splashes. Radar: a small
  friendly rotor blip + its dip ring (soft, like the sonar ring).

## Config — `config/AirWingConfig.gd` + `airwing.tres` (per-system rule)

| Tunable | Start | Meaning |
|---|---|---|
| `speed` | `160` | helo flight speed, u/s (faster than the ship, slower than shells) |
| `turn` | `2.6` | steering cap, rad/s (added at mockup build — per the tunables-in-config rule) |
| `picket_dist` | `360` | patrol station distance ahead of the ship's course (450 at draft; pulled in at mockup build so the orbit sweeps into the viewport — an always-off-screen wingman is a radar rumor, not a crewmate) |
| `orbit_radius` | `150` | circle radius at the patrol station (180 at draft, same reason) |
| `dip_radius` | `240` | passive detection radius around the bird |
| `drop_range` | `70` | must be nearly overhead a DETECTED sub to drop |
| `dc_count` | `2` | light charges per drop |
| `dc_scatter` | `40` | drop scatter (tighter than the ship's racks) |
| `dc_dmg` | `1` | per blast — softens, never finishes an hp-6 sub alone fast |
| `dc_cooldown` | `9.0` | seconds between drops (6.0 at draft; slowed at mockup build — at 6.0 the bird soloed an hp-6 sub in ~15 s, crossing into the declined HUNTER-KILLER fantasy; at 9.0 it grinds ~27 s alone while the stern racks finish in ~8) |
| `patrol_secs` | `45.0` | airborne endurance |
| `turnaround_secs` | `10.0` | pad rearm time |
| `investigate_hold` | `6.0` | how long a torpedo launch point stays worth visiting |

(Blast radius + fuse reuse `SonarConfig.dc_blast`/`dc_fuse` — one underwater-physics truth.)

**AIR WING tree column** (`tech.tres`, replacing the five ████ placeholders; costs 1/1/2/2/3,
strict in-branch order like every branch):

| id | Name | Cost | Effect |
|---|---|---|---|
| `air1` | **WHIRLYBIRD** | 1 | the bird itself (`tech.helo = true`); owning it de-redacts air2–5 |
| `air2` | Big Dipper | 1 | +40% dip radius (`airwing.dip_radius` ×1.4) |
| `air3` | Drop Tanks | 2 | +50% endurance, −40% turnaround (`patrol_secs` ×1.5, `turnaround_secs` ×0.6) |
| `air4` | Weapons Free | 2 | +2 charges per drop (`airwing.dc_count` +2) |
| `air5` | **MAD GEAR** (marquee) | 3 | bird-made contacts never decay this wave (`tech.mad_gear = true`) |

## Determinism notes

- New `world.rng` draws: helo drop scatter only (per charge, volley order). The state machine,
  picket geometry, fuel clock, and detection are pure arithmetic.
- `AirWing.step` sits at a fixed slot (after DepthCharges); with `tech.helo` off it returns before
  touching state or RNG — baseline invariance is a probe check.
- Rotor spin, dip-ring pulse, pad animations: render-only cosmetics on their own clock.

## Visual spec (mockup gate: mock → approve → port)

`design/air-wing.html` — extends the approved C5 mockup (full loop carried): the pad spin-up,
launch, picket orbit + dip ring, a contact-led prosecution with the light pattern, the RTB/rearm
beat, the declassified tree column (redacted until air1), MAD GEAR feel, dev-kit unchanged (+SUB
spawns are how you feed the bird). Owner judges the wingman fantasy (does the bird feel like a
crewmate?), the picket read, the softens-but-never-steals kill balance, and whether the fuel
rhythm is drama or annoyance; approves; then it ports.

## Acceptance checks (`tests/probe_airwing.gd`; verify.sh step)

1. **Determinism:** scripted run with the bird patrolling, prosecuting, and dropping → two worlds
   byte-identical, `rng.calls` equal.
2. **Baseline invariance:** zero-tech (no `air1`) run is byte-identical to C5 behavior — the helo
   system never touches state or RNG; the pad stays empty.
3. **Picket + extended ears:** with the bird up, a sub ahead at picket range gets detected (same
   latch, `contact` effect) well outside the ship's sonar radius; radar diamond appears.
4. **Contact-led prosecution:** given a live contact off-axis, the bird breaks orbit, closes to
   `drop_range`, and drops on cooldown; the sub takes light damage but survives a single pattern;
   the SHIP's racks still finish it (dc_dmg 1 × 2 charges < hp 6).
5. **Fuel loop:** airborne ≈ `patrol_secs`, then RTB → pad for ≈ `turnaround_secs` → relaunch;
   detection contributes nothing while it's on the pad.
6. **MAD GEAR:** a bird-made contact outlives `contact_hold` indefinitely; a SHIP-made contact
   still decays on schedule.
7. **Tree:** air nodes derive dip radius / endurance / turnaround / charge count correctly; air2–5
   unbuyable before air1 (strict order); the old locked/0-cost placeholders are fully replaced (no
   dead nodes).
8. Existing probes (sim, movement, hardpoints, waves, tech, sonar) pass unchanged.

## Out of scope (explicit cuts from the interview)

- Any non-ASW helo role (AA escort, surface strikes, scouting/spotting for the batteries) — the
  bird is a sub hunter, full stop.
- Shoot-downs / helo health / airframe loss (invulnerable by owner decision #3).
- Player helo orders of any kind (autonomous by owner decision #1).
- A second airframe (TWIN BIRDS was considered and passed over for MAD GEAR).
- Night/searchlight mechanics (no night in this game).

## DECISIONS.md impact

At build time: resolve open thread #3 (helipad function → THE AIR WING, this spec); note under the
C4 Change Request entry that the "helicopter tech tree" question is answered; D1.9/D1.10/D1.11
untouched (the bird plugs into C5's latch — it adds a listener, changes no rules). The CLASSIFIED
placeholders in `tech.tres` are superseded by real nodes (recorded in the Change Log).
