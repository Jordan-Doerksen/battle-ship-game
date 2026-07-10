# CREWED GUNS (spec)

> Status: BUILT 2026-07-09. Owner directive recorded verbatim in the DECISIONS Change Log
> ("whatever that little strafe fire is we need to add that into the game… more like
> person-manned machine guns… planes would become more dangerous. I do like that anyways").
> Spec interview locked two decisions same day: **bursts with rest gaps** and **air + surface**.
> Sim-behavior CR with shipped visual language (C6 door-gun tracers + gunsplash, C9 columns) —
> the K-GUN precedent; no new mockup gate, parity ported into the mockups that model aa20.

## 1. The change

The four S mounts stop being clinical 12/s auto-hoses and become **person-manned machine guns**
firing the C6 door-gunner texture from the deck:

| aa20 | before | after |
|---|---|---|
| firing | continuous 12/s | **bursts**: 10 rounds at 12/s, then 1.5 s while the crew re-lays |
| spread | 0.045 + bloom | **0.14** + bloom (wild, human) |
| reach | full 420u always | **each round rolls 40–100%** of reach (`world.rng`) — short rounds slap the sea |
| domains | air only | **air + surface** (never sub — the deep-deaf law untouched) |
| sustained output | 12/s | ≈ 4.3/s on paper, less on target — the honest AA nerf |

- New `WeaponDef` fields `burst_rounds` / `burst_rest` / `reach_min` (0 / 0 / 1.0 defaults —
  dp5/mb16 byte-identical), mirrored in `weapons.tres` AND `WeaponConfig.spec_defaults()`.
- `Mount.burst_left` runtime state; burst logic in `Turrets.step` is config-generic; the reach
  roll in `Turrets._fire` is guarded (`reach_min < 1.0`) so precision weapons draw no extra rng.
- `Bosses.WPN_DOMAINS["aa20"]` gains surface — the MGs chip surfaced machines.
- The stitching is free: C9 already splashes every spent round (`gunsplash` → gun-class columns).
- FLAK branch: all six nodes stay live (rate = in-burst cadence, spread, traverse, bloom gain —
  bursts self-limit heat so bloom peaks lower by design, probe re-targeted — range, INCENDIARY).

## 2. Accepted consequences (owner, in the directive)

Planes are more dangerous: wilder spread + reach rolls + rest gaps cut real AA DPS hard.
Compensation, if wanted after play, comes through FLAK tech or `weapons.tres` tunes — not code.

## 3. Verify

`probe_hardpoints` re-targeted: check 2 (surface target now draws all three sizes), check 6
(bloom asserts accumulate-and-decay, not the hose-era ceiling), check 7 → **burst rhythm**
(count matches cycle math ± one burst; in-burst gap = the exact period — the C8 sub-tick fix
still guards it; rest gaps observed; stitches land on the water), check 8 unchanged (no
catch-up after idle). Full gate green; two-world determinism holds (all new randomness through
`world.rng`). `ScreenshotCG` harness is the strafe proof.
