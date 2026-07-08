class_name GameWorld
extends RefCounted
# THE WORLD — the single mutable source of truth. Grows one chunk at a time; carries ONLY state a
# landed system reads (DECISIONS Non-Negotiable Constraints: no dead mechanics). C0 has no gameplay
# systems yet, so this holds just the sim clock and a placeholder ship position/heading proving the
# loop is alive.
#
# The world holds NO view/window/camera size — the renderer owns the camera + starfield tile. No sim
# system may ever read screen size.

var world_seed: int = 0
var rng: Rng
var elapsed: float = 0.0
var tick: int = 0
var ship_pos: Vector2 = Vector2.ZERO
var ship_heading: float = 0.0    # radians; no movement system writes this yet (C1)

func _init(seed_val: int) -> void:
	world_seed = seed_val
	rng = Rng.new(seed_val)
