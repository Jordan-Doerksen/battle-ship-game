class_name RangeConfig
extends Resource
# The C2 practice range (docs/specs/hardpoint-hull.md): drifting dumb drones, air + surface, that
# respawn at distance when killed or culled. Instance lives at config/range.tres. Per the
# config-split rule this holds range/target tunables ONLY.

@export var air_count: int = 4
@export var surf_count: int = 3
@export var ring_min: float = 500.0     # spawn ring around the ship, world units
@export var ring_max: float = 1000.0
@export var air_spd_min: float = 30.0
@export var air_spd_max: float = 45.0
@export var surf_spd_min: float = 20.0
@export var surf_spd_max: float = 30.0
@export var respawn: float = 2.0        # seconds after a kill before the slot refills
@export var air_hp: int = 1
@export var surf_hp: int = 3
@export var cull_dist: float = 1400.0   # drones farther than this respawn (keeps the range populated)
