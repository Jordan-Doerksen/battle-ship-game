class_name Drone
extends RefCounted
# Practice-range target (C2). Plain pooled-style data — fixed slot array on GameWorld, slot order IS
# the deterministic iteration/spawn-draw order. No engine coupling.

var layer: String = "air"      # air | surf
var active: bool = false
var respawn_at: float = 0.0    # sim time when an inactive slot refills
var pos: Vector2 = Vector2.ZERO
var vel: Vector2 = Vector2.ZERO
var hp: int = 0
var hp_max: int = 1
