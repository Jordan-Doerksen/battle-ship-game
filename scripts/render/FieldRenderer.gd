class_name FieldRenderer
extends Node2D
# Draws the world in WORLD coordinates; the Camera2D centers on `world.ship_pos` (Main sets this each
# frame). Reads the world, writes nothing back (one-way sim → render, DECISIONS Non-Negotiable
# Constraints). C1: 1:1 port of the owner-approved design/naval-movement.html — dark sea with a
# north-up chart grid, drifting foam flecks (toroidal tile, cosmetic RNG only), a world-anchored wake
# trail (own render-side state, fed one-way from ship state), and the drawn battleship hull silhouette
# rotated to `ship_heading`. Hardpoint/turret art will render ON this hull in a later chunk (D1.5).

const SEA := Color(0.039, 0.118, 0.157)      # #0A1E28
const FOAM := Color(0.894, 0.941, 0.949)     # #E4F0F2
const HULL := Color(0.235, 0.310, 0.341)     # #3C4F57
const DECK := Color(0.353, 0.439, 0.478)     # #5A707A
const STEEL := Color(0.576, 0.655, 0.682)    # #93A7AE

var _world: GameWorld
var _field_cfg: FieldConfig
var _move_cfg: MovementConfig                 # read-only: speed normalization for cosmetics
var _flecks: Array = []
var _wake: Array = []                         # {pos: Vector2, t: float, w: float} — render-side only
var _last_emit: float = -1.0
var _hull_outline: PackedVector2Array

func bind(world: GameWorld, field_cfg: FieldConfig, move_cfg: MovementConfig) -> void:
	_world = world
	_field_cfg = field_cfg
	_move_cfg = move_cfg
	_build_flecks()
	_hull_outline = _build_hull_outline()

# foam flecks — cosmetic-only randomness: OWN generator, never world.rng (D1.4)
func _build_flecks() -> void:
	var srng := RandomNumberGenerator.new()
	srng.seed = _world.world_seed ^ 0x51ED2317
	_flecks.clear()
	for i in range(_field_cfg.fleck_count):
		_flecks.append({
			"x": srng.randf() * _field_cfg.field_tile,
			"y": srng.randf() * _field_cfg.field_tile,
			"len": _field_cfg.fleck_min_len + srng.randf() * (_field_cfg.fleck_max_len - _field_cfg.fleck_min_len),
			"ph": srng.randf() * TAU,
		})

# hull silhouette outline — sampled once from the mockup's exact bezier path (bow = −y, local space)
static func _build_hull_outline() -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(Vector2(0, -50))                                       # bow tip
	_quad(pts, Vector2(0, -50), Vector2(8, -38), Vector2(9.5, -24), 8)   # starboard bow flare
	pts.append(Vector2(10, 20))
	_quad(pts, Vector2(10, 20), Vector2(10, 32), Vector2(6, 35), 6)      # stern taper
	_quad(pts, Vector2(6, 35), Vector2(0, 38), Vector2(-6, 35), 6)
	_quad(pts, Vector2(-6, 35), Vector2(-10, 32), Vector2(-10, 20), 6)
	pts.append(Vector2(-9.5, -24))
	_quad(pts, Vector2(-9.5, -24), Vector2(-8, -38), Vector2(0, -50), 8)
	return pts

static func _quad(pts: PackedVector2Array, p0: Vector2, c: Vector2, p1: Vector2, n: int) -> void:
	for i in range(1, n + 1):
		var t := float(i) / float(n)
		pts.append(p0.lerp(c, t).lerp(c.lerp(p1, t), t))

func _process(_delta: float) -> void:
	if _world == null:
		return
	# wake emission keyed to sim time (one puff per sim tick's worth of elapsed) — cosmetic state
	if _world.elapsed - _last_emit >= 1.0 / 60.0:
		_last_emit = _world.elapsed
		_emit_wake()
	while _wake.size() > 0 and _world.elapsed - _wake[0]["t"] >= _field_cfg.wake_life:
		_wake.pop_front()

func _emit_wake() -> void:
	var speed: float = _world.ship_vel.length()
	var along: float = Movement.keel_speeds(_world).x
	var braking: bool = _world.input.thrust < 0.0 and along > 5.0
	if speed < 6.0 and not braking:
		return
	var fwd := Vector2(sin(_world.ship_heading), -cos(_world.ship_heading))
	_wake.append({
		"pos": _world.ship_pos - fwd * 42.0,
		"t": _world.elapsed,
		"w": minf(1.0, speed / _move_cfg.max_speed_ahead) + (0.7 if braking else 0.0),
	})
	if _wake.size() > _field_cfg.wake_max_points:
		_wake.pop_front()

func _draw() -> void:
	if _world == null:
		return
	_draw_grid()
	_draw_flecks()
	_draw_wake()
	_draw_hull()

func _view_rect() -> Rect2:
	# renderer MAY read view size (the sim never does) — visible world rect at the camera's zoom
	var cam := get_viewport().get_camera_2d()
	var size: Vector2 = get_viewport_rect().size / (cam.zoom if cam != null else Vector2.ONE)
	return Rect2(_world.ship_pos - size * 0.5, size)

func _draw_grid() -> void:
	var view := _view_rect()
	for layer in [[_field_cfg.grid_minor, 0.035], [_field_cfg.grid_major, 0.07]]:
		var step: float = layer[0]
		var col := Color(FOAM.r, FOAM.g, FOAM.b, layer[1])
		var gx: float = floorf(view.position.x / step) * step
		while gx <= view.end.x:
			draw_line(Vector2(gx, view.position.y), Vector2(gx, view.end.y), col, 1.0)
			gx += step
		var gy: float = floorf(view.position.y / step) * step
		while gy <= view.end.y:
			draw_line(Vector2(view.position.x, gy), Vector2(view.end.x, gy), col, 1.0)
			gy += step

func _draw_flecks() -> void:
	var tile: float = _field_cfg.field_tile
	var cam_pos: Vector2 = _world.ship_pos
	var now: float = Time.get_ticks_msec() * 0.001   # cosmetic bob only — never sim time math
	var col := Color(FOAM.r, FOAM.g, FOAM.b, 0.16)
	for f in _flecks:
		var wx: float = fposmod(f["x"] - cam_pos.x + tile * 0.5, tile) - tile * 0.5 + cam_pos.x
		var wy: float = fposmod(f["y"] - cam_pos.y + tile * 0.5, tile) - tile * 0.5 + cam_pos.y
		var bob: float = sin(now * 0.6 + f["ph"]) * 1.5
		draw_line(Vector2(wx - f["len"] * 0.5, wy + bob), Vector2(wx + f["len"] * 0.5, wy + bob), col, 1.0)

func _draw_wake() -> void:
	for p in _wake:
		var age: float = (_world.elapsed - p["t"]) / _field_cfg.wake_life
		if age >= 1.0:
			continue
		var r: float = (2.0 + p["w"] * 7.0) * (0.5 + age * 1.6)
		draw_circle(p["pos"], r, Color(FOAM.r, FOAM.g, FOAM.b, 0.30 * p["w"] * (1.0 - age)))

func _draw_hull() -> void:
	draw_set_transform(_world.ship_pos, _world.ship_heading, Vector2.ONE)
	draw_colored_polygon(_hull_outline, HULL)
	var speed: float = _world.ship_vel.length()
	var edge := Color(FOAM.r, FOAM.g, FOAM.b, minf(0.55, 0.12 + speed / _move_cfg.max_speed_ahead * 0.5))
	var closed := PackedVector2Array(_hull_outline)
	closed.append(_hull_outline[0])
	draw_polyline(closed, edge, 1.2, true)
	# deck hints — superstructure, bridge, turret barbettes fore/aft, stern helipad ring
	draw_rect(Rect2(-5.5, -13, 11, 17), DECK)
	draw_rect(Rect2(-3.5, -18, 7, 5), DECK)
	draw_circle(Vector2(0, -27), 5.0, DECK)
	draw_circle(Vector2(0, 13), 5.0, DECK)
	draw_rect(Rect2(-1.2, -36, 2.4, 9), STEEL)   # fore barrels (hint)
	draw_rect(Rect2(-1.2, 18, 2.4, 8), STEEL)    # aft barrels (hint)
	draw_arc(Vector2(0, 27), 6.0, 0.0, TAU, 24, STEEL, 1.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
