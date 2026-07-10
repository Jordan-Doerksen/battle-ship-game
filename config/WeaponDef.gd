class_name WeaponDef
extends Resource
# One weapon in the C2 catalog (docs/specs/hardpoint-hull.md). Lives as a sub-resource inside
# config/weapons.tres — see WeaponConfig.gd. `range_u` avoids shadowing GDScript's range().
# Bloom: sustained fire widens the cone by bloom_add per shot up to bloom_max; it tightens at
# bloom_decay rad/s while the gun rests. Zero on non-AA weapons.

@export var id: String = ""
@export var display_name: String = ""
@export var size: String = "S"                    # S | M | L — which mount class carries it
@export var domains: PackedStringArray = []       # air | surface | sub (D1.9 targeting tags)
@export var policy: String = "CLOSE"              # CLOSE | STRONG (per-weapon, owner decision #4)
@export var range_u: float = 400.0                # engagement range, world units
@export var rate: float = 1.0                     # shots per second
@export var traverse: float = 1.0                 # rad/s barrel slew (owner decision #2)
@export var dmg: int = 1
@export var speed: float = 500.0                  # projectile speed, u/s
@export var spread: float = 0.02                  # base per-shot spread, rad
@export var splash: float = 0.0                   # burst radius at aim point (0 = direct-hit shell)
@export var bloom_add: float = 0.0
@export var bloom_max: float = 0.0
@export var bloom_decay: float = 0.0
# Crewed-MG texture (CREWED GUNS CR, 2026-07-09): burst_rounds > 0 makes the weapon fire in human
# bursts — burst_rounds shots at `rate`, then burst_rest seconds while the crew re-lays. reach_min
# rolls each round's flight to reach_min…1.0 of the gun's reach (world.rng) — short rounds stitch the
# water walking toward the target. 0 / 0 / 1.0 = continuous precision fire (non-crewed weapons).
@export var burst_rounds: int = 0
@export var burst_rest: float = 0.0
@export var reach_min: float = 1.0
