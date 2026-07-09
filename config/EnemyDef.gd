class_name EnemyDef
extends Resource
# One enemy type in the roster (docs/specs/{wave-director,sonar-subs,boss-ladder}.md). Lives as a
# sub-resource inside config/enemies.tres — see EnemyConfig.gd. Ids stay MECHANICAL (determinism,
# config paths, probes); `rep` carries the C7 reporting name the HUD speaks. Standoff-shooter
# fields stay 0 on divers.

@export var id: String = ""
@export var rep: String = ""               # EDF reporting name (C7 naming pass) — display only
@export var layer: String = "air"          # air | surf | sub — D1.9 domain for targeting
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
@export var torp_run: float = 0.0          # sub only (C5): torpedo run distance, u (0 = fires shells)
