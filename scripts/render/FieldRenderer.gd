class_name FieldRenderer
extends Node2D
# Draws the world in WORLD coordinates; the Camera2D centers on `world.ship_pos` (Main sets this each
# frame). Reads the world, writes nothing back (one-way sim → render, DECISIONS Non-Negotiable
# Constraints). C0 placeholder: an ocean-tinted toroidal starfield (cosmetic — own RNG, never
# `world.rng`) and a drawn hull dot at the ship position, proving the sim→render loop is alive. Real
# hull/hardpoint art lands in a future chunk (ARCHITECTURE.md — turret art renders ON the hull here,
# not HUD-only, per DECISIONS D1.5).

var _world: GameWorld
var _field_cfg: FieldConfig
var _stars: Array = []

func bind(world: GameWorld, field_cfg: FieldConfig) -> void:
	_world = world
	_field_cfg = field_cfg
	_build_starfield()

func _build_starfield() -> void:
	var srng := RandomNumberGenerator.new()
	srng.seed = _world.world_seed ^ 0x51ED2317
	_stars.clear()
	for i in range(_field_cfg.star_count):
		_stars.append({
			"x": srng.randf() * _field_cfg.field_tile,
			"y": srng.randf() * _field_cfg.field_tile,
			"size": _field_cfg.star_min_size + srng.randf() * (_field_cfg.star_max_size - _field_cfg.star_min_size),
			"bright": 0.35 + srng.randf() * 0.65,
		})

func _draw() -> void:
	if _world == null:
		return
	var cam_pos: Vector2 = _world.ship_pos
	var tile: float = _field_cfg.field_tile
	for s in _stars:
		var wx: float = fposmod(s["x"] - cam_pos.x + tile * 0.5, tile) - tile * 0.5 + cam_pos.x
		var wy: float = fposmod(s["y"] - cam_pos.y + tile * 0.5, tile) - tile * 0.5 + cam_pos.y
		var b: float = s["bright"]
		draw_circle(Vector2(wx, wy), s["size"], Color(0.55, 0.78, 0.9, b * 0.5))
	# placeholder hull — a filled circle at the ship position (no movement writes it yet, C1)
	draw_circle(_world.ship_pos, 14.0, Color(0.56, 0.84, 1.0, 0.9))
