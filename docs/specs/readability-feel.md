# C12 — READABILITY & FEEL (spec — AT THE GATE)

> Status: mockup gate (`design/readability-feel.html` — the FEEL BOARD: the SFX palette playable
> in-browser plus live demos of every readability fix). The polish arc's last chunk, from the
> owner-approved directive (research-pass interview 2026-07-09). Spec interview 2026-07-10:
> onboarding = **CONTEXTUAL DRIP** (one-line plates, once per profile, at the moment each thing
> matters). Everything here is app/render/UI + audio assets — **zero sim changes**; the
> two-world determinism probes must pass untouched.

## 1. Readability (HUD/render)

- **Torpedo blips** (the scope's least legible critical element — today identical to shell
  motes): a bright foam dash oriented along the run + trailing wake sparks (the C5 spec's
  promised language, finally realized). `HelmGauges._draw_radar` reads `p.wid == "torpedo"`.
- **DC arm ring + rack state**: the 220u arm range (`sonar.dc_range`) as a dashed foam ring on
  the scope (dashed vs the solid 350u sonar ring), plus a small cooldown arc near the own-ship
  blip that fills over the volley cooldown and blinks when the racks are ready.
- **Wounded tells** (`HostileRender`): surface enemies below half hp take a slight list
  (render-only heel) + darkened hull + a drifting smoke wisp; at the last pip, a small flame
  flicker. Air enemies smoke only. Render-side, cosmetic RNG only.

## 2. Flow (app)

- **Pause**: `P` toggles mid-sortie; the sim stops stepping, a PAUSED plate shows
  ("The war waits. The sea doesn't." — the sea shader keeps drifting, it runs on the render
  clock by design). Input snapshot frozen; DevKit still reachable in debug.
- **Lost-card guard**: on SHIP LOST, clicks are dead — the card holds for 1.5 s, then shows
  `R — NEW SORTIE · T — THE TREE`; restart is key-only. The XP report can no longer be skipped
  by the combat button.
- **Contextual drip onboarding**: one-line deadpan hint plates, each shown once per profile at
  the trigger moment — first sortie (helm; force-fire), first sonar contact (the deaf-deep
  rule), first torpedo in the water, first war machine. Seen-flags persist in
  `user://profile.cfg` (app layer, beside XP). Copy lives in the mockup and ports verbatim.

## 3. Sound (the minimal SFX pass — no music)

- **Assets**: procedurally synthesized offline — `tools/gen_sfx.py` (stdlib-only) writes
  `audio/*.wav` from the exact recipes the mockup's WebAudio plays (oscillator + filtered noise
  + envelope per sound). The mockup is the sound reference; the generator is committed so the
  palette is reproducible, tunable, and asset-free in spirit.
- **Wiring**: an `SfxPlayer` node under Main consumes the SAME one-way effect batch
  (`consume_effects`, the C11 channel) and maps event types → streams with per-type rate
  limits (the crewed MGs must not machine-gun the mixer). `klaxon` and `waveclear` — emitted
  and dropped since C3 — finally sound.
- **Palette** (from the board): mb16/dp5 fire, MG burst ticks, splash column, gunsplash stitch,
  torpedo KLAXON, sonar contact ping, DC volley clunk + underwater blast, ship hit, wave-clear
  sting, machine-arrival swell, ship lost settle.
- **Config**: new `AudioConfig`/`audio.tres` (per-system rule): `master_volume`, `muted`,
  per-type cooldowns. Sounds duplicate visual information, never carry it alone (mute loses
  nothing but feel).

## 4. Acceptance

1. Full verify gate green; determinism probes byte-identical (nothing sim-side changed).
2. Scope: torpedoes unmistakable at a glance; DC ring + rack state readable; C11 fall-of-shot
   unaffected.
3. Pause holds the war, not the water; the lost card can't be skipped by a click.
4. Hints fire once each on a fresh profile, never on an old one (flags persist).
5. Every mapped effect sounds in-game at the mockup's character; mute/volume respected;
   no mixer spam under sustained MG fire.
6. Gate tunes recorded back into configs + this spec + the mockup (the standing pattern).
