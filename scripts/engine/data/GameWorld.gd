class_name GameWorld
extends RefCounted
# THE WORLD — the single mutable source of truth. Grows one chunk at a time; carries ONLY state a
# landed system reads (DECISIONS Non-Negotiable Constraints: no dead mechanics). C1 added the ship;
# C2 added mounts, practice drones, pooled shells, the kill tally, and the effects queue.
#
# `effects` is the one-way sim→render event stream (muzzle/splash/death/hit). The sim appends;
# Main (app layer) hands the batch to the renderer after stepping and clears it — the renderer
# itself never touches the world beyond reads.
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
var mounts: Array = []                   # Mount runtime state, index-locked to HardpointConfig
var drones: Array = []                   # Drone slots, fixed order (Drones.gd sizes lazily)
var projectiles: Pool
var kills: int = 0
var effects: Array = []

func _init(seed_val: int) -> void:
	world_seed = seed_val
	rng = Rng.new(seed_val)
	projectiles = Pool.new(func() -> Projectile: return Projectile.new())
