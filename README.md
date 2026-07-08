# Earth Defense Force (working title)

A deterministic, deadpan-serious 1950s-B-movie naval wave-survival roguelite. Godot 4.7 / GDScript.

You command a single Earth Defense Force battleship, alone against AI-piloted alien swarms rising from
air, sea surface, and underwater. Hardpoints are visible, purchasable positions on the hull that
auto-fire at anything in range regardless of hull facing; piloting decides domain coverage and sonar
range, not aim. Subs stay hidden until sonar reveals them; depth charges are a free, inaccurate,
always-on backstop.

A sibling project of [`fulfillment`](../fulfillment) — same architecture discipline (deterministic sim,
one-way render, design-first process), different tone and systems. See `docs/DESIGN-BRIEF.md` for the
full pitch, `DECISIONS.md` for locked calls, and `docs/HANDOFF.md` for a project pick-up.

Status: **C0 — Heartbeat** built (deterministic loop skeleton, no gameplay yet). Proprietary/commercial
— see `LICENSE`.

```bash
./verify.sh          # gdparse sweep → import → boot probe
./verify.sh quick    # gdparse sweep only
```
