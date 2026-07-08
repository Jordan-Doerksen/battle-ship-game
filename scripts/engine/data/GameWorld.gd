class_name GameWorld
extends RefCounted
# THE WORLD — the single mutable source of truth. Grows one chunk at a time; carries ONLY state a
# landed system reads (DECISIONS Non-Negotiable Constraints: no dead mechanics). As of C1 it holds the
# sim clock and the real ship state that Movement.step integrates each tick.
#
# The world holds NO view/window/camera size — the renderer owns the camera + sea-field tile. No sim
# system may ever read screen size.

var world_seed: int = 0
var rng: Rng
var elapsed: float = 0.0
var tick: int = 0
var ship_pos: Vector2 = Vector2.ZERO
var ship_vel: Vector2 = Vector2.ZERO
var ship_heading: float = 0.0            # radians; 0 = north (screen up), positive = clockwise
var input: InputState = InputState.new() # written by Main pre-step; read-only inside the sim

func _init(seed_val: int) -> void:
	world_seed = seed_val
	rng = Rng.new(seed_val)
