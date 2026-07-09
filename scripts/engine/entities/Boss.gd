class_name Boss
extends RefCounted
# The single active war machine (C7). Plain data — lives at world.boss (null between rungs);
# Bosses.gd owns every mutation. `parts` mirrors BossDef.parts by index:
# { "hp": float, "max": float, "dead": bool, "cool": float }.

var rung: int = 0                 # index into BossConfig.defs
var lap: int = 1                  # ladder lap (scales hp and the bounty)
var pos: Vector2 = Vector2.ZERO
var heading: float = 0.0
var core: float = 0.0
var core_max: float = 0.0
var parts: Array = []
var cool: float = 0.0             # machine-level attack clock (MAW torpedo fans)
var hive_cool: float = 0.0        # CANOPY hive clock
var speed_bonus: float = 0.0      # JUGGERNAUT phase speed
var rate_mult: float = 1.0        # CANOPY phase acceleration
var submerged: bool = false       # MAW breach cycle
var cycle_t: float = 0.0
var breach_bonus: float = 0.0     # accumulated breach extension (it can't seal)
var detected_until: float = -1.0  # sonar latch while it stalks (D1.10 applies to machines too)
