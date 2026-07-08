class_name EnemyDef
extends Resource
# One enemy type in the C3 roster (docs/specs/wave-director.md). Lives as a sub-resource inside
# config/enemies.tres — see EnemyConfig.gd. Ids are mechanical placeholders until the B-movie naming
# pass (DECISIONS open thread #2). Gunboat-only fields stay 0 on divers.

@export var id: String = ""
@export var layer: String = "air"          # air | surf — D1.9 domain for targeting
@export var hp: int = 1
@export var speed: float = 100.0           # u/s
@export var turn: float = 1.0              # rad/s steering cap
@export var dmg: int = 1                   # hull pips on contact (divers; 0 for gunboat)
@export var radius: float = 10.0           # contact/hit radius
@export var cost: int = 1                  # budget price
@export var unlock: int = 1                # first wave this type may appear
@export var standoff: float = 0.0          # gunboat: orbit distance
@export var fire_range: float = 0.0        # gunboat: max shot distance
@export var fire_period: float = 0.0       # gunboat: seconds between shots
@export var shell_speed: float = 0.0       # gunboat: hostile shell speed (dodgeable by design)
@export var shell_dmg: int = 0             # gunboat: pips per shell hit
@export var lead: float = 0.0              # gunboat: fraction of full target lead
@export var spread: float = 0.0            # gunboat: per-shot spread, rad (world.rng draw)
