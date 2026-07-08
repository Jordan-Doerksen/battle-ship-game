class_name Enemy
extends RefCounted
# One hostile drone (C3). Plain data — lives in world.enemies, a flat array the director fills per
# wave and clears on wave-clear; array order IS the deterministic iteration order. Ids are
# mechanical placeholders until the naming pass (DECISIONS open thread #2).

var type_id: String = "swarmer"
var layer: String = "air"      # air | surf
var active: bool = false
var pos: Vector2 = Vector2.ZERO
var heading: float = 0.0       # radians, heading space (0 = north)
var hp: int = 1
var hp_max: int = 1
var cool: float = 0.0          # gunboat fire cooldown
var burn_left: int = 0         # INCENDIARY LOAD ticks remaining (C4 marquee)
var next_burn: float = 0.0     # sim time of the next burn tick
