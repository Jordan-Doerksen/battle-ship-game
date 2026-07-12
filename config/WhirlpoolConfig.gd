class_name WhirlpoolConfig
extends Resource
# C18 THE WHIRLPOOL (docs/specs/whirlpools.md) — every dial of the one charted vortex. One config
# per system (repo law); instance at config/whirlpool.tres. Field values are the approved TEMPEST
# rail (design/the-tempest.html, gate 2026-07-12); the mass tiers, tide clock, grinder, and helm
# fight are the four owner forks locked 2026-07-12. Raising `count` past one is a CR, not a tune.

@export var enabled: bool = true          # false ⇒ generate() charts nothing (byte-identical pre-C18)
@export var count: int = 1                # ALWAYS EXACTLY ONE (owner fork 2) — raising this is a CR

# ── the field (approved rail; tangential:radial ≈ 3:1 — the swirl dominates the suck) ──
@export var radius: float = 170.0         # influence radius (u) — the darkening IS this circle
@export var tang: float = 30.0            # tangential pull at the curve peak (u/s²-equivalent)
@export var inward: float = 11.0          # radial pull — CAPPED by shape, never a 1/r asymptote
@export var mult_ship: float = 0.25       # mass tiers (owner fork 1): the battleship barely feels it…
@export var mult_small: float = 1.0       # …small waterborne craft ride it hard…
@export var mult_torp: float = 1.6        # …and torpedoes visibly bend off their line
@export var core_frac: float = 0.15       # the eye: this fraction of radius is the core

# ── the tide clock (owner fork 3: wave-keyed cycle, independent of weather) ──
@export var tide_period: int = 6          # full cycle in waves (peak at period/2)
@export var tide_floor: float = 0.15      # dormant intensity — the lane never fully sleeps
@export var capsize_tide: float = 0.8     # at/above this: the grinder bites and the helm fights

# ── the grinder + the helm fight (owner forks 4–5) ──
@export var helm_mult: float = 0.5        # rudder authority inside the core at high tide
@export var yaw_torque: float = 0.25      # rad/s of swirl torque on the bow at full tide (core only)

# ── placement (seeded beside C15 terrain; charted bathymetry, fixed all run) ──
@export var nav_min: float = 120.0        # a constriction must still be navigable…
@export var nav_max: float = 700.0        # …and narrow enough to churn
@export var start_clear: float = 450.0    # never inside the ship's opening water

@export var spin: float = 0.5             # render: base foam-arm rotation rate (tide scales it)
