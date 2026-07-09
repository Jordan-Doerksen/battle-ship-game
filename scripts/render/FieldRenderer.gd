class_name FieldRenderer
extends Node2D
# Draws the world in WORLD coordinates; the Camera2D centers on `world.ship_pos` (Main sets this each
# frame). Reads the world, writes nothing back (one-way sim → render). C2 look is LOOK-LOCKED
# (battleship hull ×2.4, class-distinct turret art ON the hull per D1.5, recoil); C3 adds the war
# per the approved design/wave-director.html: red enemy silhouettes, hostile shells, ship-hit and
# grace feedback, and the B-movie death blast. Effects arrive via consume_effects() — Main plumbs
# the sim's event batch here after stepping; this node never touches world.effects itself.

const SEA := Color(0.039, 0.118, 0.157)      # #0A1E28
const FOAM := Color(0.894, 0.941, 0.949)     # #E4F0F2
const HULL := Color(0.235, 0.310, 0.341)     # #3C4F57
const DECK := Color(0.353, 0.439, 0.478)     # #5A707A
const STEEL := Color(0.576, 0.655, 0.682)    # #93A7AE
const HOUSE := Color(0.392, 0.471, 0.522)    # #647885 — turret houses
const HOUSE_FORCED := Color(0.431, 0.353, 0.314)  # #6E5A50 — force-fired tint
const FLASH := Color(0.910, 0.706, 0.431)    # muzzle
const RED := Color(0.851, 0.310, 0.169)      # #D94F2B
const HULL_SCALE := 2.4
const FLASH_LEN := { "L": 35.0, "M": 22.0, "S": 13.0 }

var _world: GameWorld
var _field_cfg: FieldConfig
var _cfgs: Configs
var _flecks: Array = []
var _wake: Array = []
var _fx: Array = []                          # render-side animated effects
var _recoil: Array = []                      # per-mount barrel kick, fed by muzzle effects
var _last_emit: float = -1.0
var _hull_outline: PackedVector2Array
var _death_ms: int = -1                      # when the shipdeath effect landed (wreck fade timer)
var show_ship: bool = true                   # Main clears it behind the title/tree screens (C4)

func bind(world: GameWorld, field_cfg: FieldConfig, cfgs: Configs) -> void:
	_world = world
	_field_cfg = field_cfg
	_cfgs = cfgs
	_build_flecks()
	_hull_outline = _build_hull_outline()
	_recoil.resize(cfgs.hardpoints.mount_pos.size())
	_recoil.fill(0.0)
	_fx.clear()
	_wake.clear()
	_last_emit = -1.0
	_death_ms = -1

# Main hands over the sim's effect batch each frame (one-way; see GameWorld.effects)
func consume_effects(events: Array) -> void:
	var now: int = Time.get_ticks_msec()
	for e in events:
		if e["type"] == "muzzle" and e["idx"] < _recoil.size():
			_recoil[e["idx"]] = 1.0
		if e["type"] == "shipdeath":
			_death_ms = now
		var fxe: Dictionary = e.duplicate()
		fxe["t0"] = now
		_fx.append(fxe)

func _build_flecks() -> void:
	var srng := RandomNumberGenerator.new()   # cosmetic-only randomness — never world.rng (D1.4)
	srng.seed = _world.world_seed ^ 0x51ED2317
	_flecks.clear()
	for i in range(_field_cfg.fleck_count):
		_flecks.append({
			"x": srng.randf() * _field_cfg.field_tile,
			"y": srng.randf() * _field_cfg.field_tile,
			"len": _field_cfg.fleck_min_len + srng.randf() * (_field_cfg.fleck_max_len - _field_cfg.fleck_min_len),
			"ph": srng.randf() * TAU,
		})

# C1 silhouette proportions at battleship scale (spec gate revisions 1+3)
static func _build_hull_outline() -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(Vector2(0, -50))
	_quad(pts, Vector2(0, -50), Vector2(8, -38), Vector2(9.5, -24), 8)
	pts.append(Vector2(10, 20))
	_quad(pts, Vector2(10, 20), Vector2(10, 32), Vector2(6, 35), 6)
	_quad(pts, Vector2(6, 35), Vector2(0, 38), Vector2(-6, 35), 6)
	_quad(pts, Vector2(-6, 35), Vector2(-10, 32), Vector2(-10, 20), 6)
	pts.append(Vector2(-9.5, -24))
	_quad(pts, Vector2(-9.5, -24), Vector2(-8, -38), Vector2(0, -50), 8)
	for i in range(pts.size()):
		pts[i] *= HULL_SCALE
	return pts

static func _quad(pts: PackedVector2Array, p0: Vector2, c: Vector2, p1: Vector2, n: int) -> void:
	for i in range(1, n + 1):
		var t := float(i) / float(n)
		pts.append(p0.lerp(c, t).lerp(c.lerp(p1, t), t))

func _process(_delta: float) -> void:
	if _world == null:
		return
	if _world.elapsed - _last_emit >= 1.0 / 60.0:
		_last_emit = _world.elapsed
		_emit_wake()
	while _wake.size() > 0 and _world.elapsed - _wake[0]["t"] >= _field_cfg.wake_life:
		_wake.pop_front()

func _emit_wake() -> void:
	if _world.run_over:
		return
	var speed: float = _world.ship_vel.length()
	var along: float = Movement.keel_speeds(_world).x
	var braking: bool = _world.input.thrust < 0.0 and along > 5.0
	if speed < 6.0 and not braking:
		return
	var fwd := Vector2(sin(_world.ship_heading), -cos(_world.ship_heading))
	_wake.append({
		"pos": _world.ship_pos - fwd * 100.0,
		"t": _world.elapsed,
		"w": minf(1.0, speed / _cfgs.movement.max_speed_ahead) + (0.7 if braking else 0.0),
	})
	if _wake.size() > _field_cfg.wake_max_points:
		_wake.pop_front()

func _draw() -> void:
	if _world == null:
		return
	_draw_grid()
	_draw_flecks()
	_draw_wake()
	_draw_enemies()
	_draw_projectiles()
	_draw_hull()
	_draw_mounts()
	_draw_helo()
	_draw_fx()

func _view_rect() -> Rect2:
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
	var now: float = Time.get_ticks_msec() * 0.001
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

# enemy identity (approved mockup): hostile = signal-red family. Swarmer = small darting delta,
# gunboat = low dark hull with red edge + deck gun, bomber = broad heavy delta with engine dots.
# Subs (C5): DETECTED = dark ellipse silhouette + conning dot + pulsing foam ring; UNDETECTED near
# the ship = a barely-there ripple tell (D1.10 — render-only read of sonar state); else nothing.
func _draw_enemies() -> void:
	var now: float = Time.get_ticks_msec() * 1.0
	for e in _world.enemies:
		if not e.active:
			continue
		if e.layer == "sub":
			_draw_sub(e, now)
			continue
		draw_set_transform(e.pos, e.heading, Vector2.ONE)
		if e.type_id == "swarmer":
			draw_colored_polygon(PackedVector2Array([Vector2(0, -8), Vector2(6, 6), Vector2(0, 3), Vector2(-6, 6)]),
				Color(0.851, 0.310, 0.169, 0.95))
			draw_circle(Vector2(0, -1), 1.4, FOAM)
		elif e.type_id == "gunboat":
			var boat := PackedVector2Array([Vector2(0, -16), Vector2(8, -6), Vector2(8, 12), Vector2(-8, 12), Vector2(-8, -6)])
			draw_colored_polygon(boat, Color(0.118, 0.180, 0.212))
			var bc := PackedVector2Array(boat); bc.append(boat[0])
			draw_polyline(bc, Color(0.851, 0.310, 0.169, 0.8), 1.2, true)
			draw_rect(Rect2(-1.5, -10, 3, 8), RED)
		else:   # bomber
			var wing := PackedVector2Array([Vector2(0, -14), Vector2(16, 10), Vector2(0, 4), Vector2(-16, 10)])
			draw_colored_polygon(wing, Color(0.588, 0.176, 0.098, 0.95))
			var wc := PackedVector2Array(wing); wc.append(wing[0])
			draw_polyline(wc, Color(0.851, 0.310, 0.169, 0.9), 1.2, true)
			draw_circle(Vector2(-6, 6), 1.6, FLASH)
			draw_circle(Vector2(6, 6), 1.6, FLASH)
		if e.burn_left > 0:   # INCENDIARY (C4): flame flicker on burning drones
			var nowf: float = Time.get_ticks_msec() * 1.0
			draw_circle(Vector2.ZERO, 4.0 + sin(nowf * 0.05) * 1.5,
				Color(FLASH.r, FLASH.g, FLASH.b, 0.6 + 0.4 * sin(nowf * 0.03)))
		draw_set_transform(e.pos, 0.0, Vector2.ONE)
		if e.hp < e.hp_max and e.hp_max > 2:   # hp pips under damaged toughs
			for i in range(e.hp):
				draw_rect(Rect2(-10 + i * 4, 16, 2.6, 2.2), Color(FOAM.r, FOAM.g, FOAM.b, 0.7))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_sub(e: Enemy, now: float) -> void:
	if Sonar.detected(_world, e):
		# silhouette: dark 7×20 ellipse under red-tinted water, conning-tower dot
		draw_set_transform(e.pos, e.heading, Vector2(0.35, 1.0))
		draw_circle(Vector2.ZERO, 20.0, Color(0.094, 0.165, 0.212, 0.85))
		draw_set_transform(e.pos, e.heading, Vector2.ONE)
		_draw_ellipse_outline(7.0, 20.0, Color(RED.r, RED.g, RED.b, 0.55), 1.2)
		draw_circle(Vector2(0, -4), 2.4, Color(FOAM.r, FOAM.g, FOAM.b, 0.5))
		draw_set_transform(e.pos, 0.0, Vector2.ONE)
		draw_arc(Vector2.ZERO, 24.0 + sin(now * 0.004) * 2.0, 0.0, TAU, 32,
			Color(FOAM.r, FOAM.g, FOAM.b, 0.25), 1.0, true)   # foam ring over the contact
	elif e.pos.distance_to(_world.ship_pos) <= _cfgs.sonar.ripple_range:
		# the water moves wrong: two faint counter-wobbling rings, no shape underneath
		var wob: float = sin(now * 0.003 + e.pos.x) * 3.0
		draw_set_transform(e.pos, 0.0, Vector2.ONE)
		draw_arc(Vector2.ZERO, 14.0 + wob, 0.0, TAU, 28, Color(FOAM.r, FOAM.g, FOAM.b, 0.07), 1.5, true)
		draw_arc(Vector2.ZERO, 24.0 - wob, 0.0, TAU, 32, Color(FOAM.r, FOAM.g, FOAM.b, 0.045), 1.5, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_ellipse_outline(rx: float, ry: float, col: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for i in range(33):
		var a: float = TAU * i / 32.0
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	draw_polyline(pts, col, width, true)

func _draw_projectiles() -> void:
	for i in range(_world.projectiles.items.size()):
		var p: Projectile = _world.projectiles.items[i]
		if not p.active:
			continue
		var tail: Vector2 = p.pos - p.vel * (0.05 if p.hostile else 0.03)
		if p.wid == "torpedo":   # C5: dark runner drawing a foam wake line astern of itself
			var u: Vector2 = p.vel.normalized()
			for wk in range(1, 10):
				draw_circle(p.pos - u * (wk * 14.0), 1.6 + wk * 0.35,
					Color(FOAM.r, FOAM.g, FOAM.b, 0.5 - wk * 0.05))
			draw_circle(p.pos, 3.0, Color(0.094, 0.165, 0.212, 0.95))
			draw_arc(p.pos, 3.0, 0.0, TAU, 16, Color(0.914, 0.404, 0.259, 0.8), 1.0, true)
		elif p.wid == "dc":      # C5: charge shrinking + spreading ring as it sinks on its fuse
			var sink: float = 1.0 - p.life / maxf(_cfgs.sonar.dc_fuse, 0.001)
			draw_circle(p.pos, 3.5 - sink * 2.0, Color(FOAM.r, FOAM.g, FOAM.b, 0.7 - sink * 0.5))
			draw_arc(p.pos, 5.0 + sink * 6.0, 0.0, TAU, 20,
				Color(FOAM.r, FOAM.g, FOAM.b, 0.3 - sink * 0.2), 1.0, true)
		elif p.wid == "doorgun":   # C6: door-gun tracer — thin, hot, wild
			draw_line(tail, p.pos, Color(FLASH.r, FLASH.g, FLASH.b, 0.75), 1.0)
		elif p.hostile:
			draw_line(tail, p.pos, Color(0.914, 0.404, 0.259, 0.95), 2.0)
			draw_circle(p.pos, 2.4, Color(0.914, 0.404, 0.259, 0.95))
		elif p.splash > 0.0:
			draw_circle(p.pos, 2.6, Color(FOAM.r, FOAM.g, FOAM.b, 0.95))
			draw_line(tail, p.pos, Color(FOAM.r, FOAM.g, FOAM.b, 0.35), 2.0)
		elif p.wid == "aa20":
			draw_line(tail, p.pos, Color(0.804, 0.729, 0.557, 0.9), 1.2)
		else:
			draw_line(tail, p.pos, Color(FOAM.r, FOAM.g, FOAM.b, 0.85), 1.2)

func _wreck_alpha() -> float:
	if not _world.run_over or _death_ms < 0:
		return 1.0
	return clampf(1.0 - (Time.get_ticks_msec() - _death_ms) / 1400.0, 0.0, 1.0)   # the wreck slips under

func _wreck_fade(c: Color, fade: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * fade)

func _draw_hull() -> void:
	var fade: float = _wreck_alpha()
	if fade <= 0.0 or not show_ship:
		return
	draw_set_transform(_world.ship_pos, _world.ship_heading, Vector2.ONE)
	draw_colored_polygon(_hull_outline, _wreck_fade(HULL, fade))
	var speed: float = _world.ship_vel.length()
	var graced: bool = _world.elapsed < _world.grace_until and not _world.run_over
	var flick: bool = graced and (Time.get_ticks_msec() / 60) % 2 == 0
	var edge := Color(RED.r, RED.g, RED.b, 0.9) if flick \
		else Color(FOAM.r, FOAM.g, FOAM.b, minf(0.55, 0.12 + speed / _cfgs.movement.max_speed_ahead * 0.5))
	var closed := PackedVector2Array(_hull_outline)
	closed.append(_hull_outline[0])
	draw_polyline(closed, _wreck_fade(edge, fade), 2.0 if flick else 1.2, true)
	# deck furniture (mockup rev 3): superstructure, bridge, funnel, helipad, bow jack line
	draw_rect(Rect2(-13, -31, 26, 41), _wreck_fade(DECK, fade))
	draw_rect(Rect2(-8, -43, 16, 12), _wreck_fade(DECK, fade))
	draw_rect(Rect2(-4, -18, 8, 8), _wreck_fade(Color(0.290, 0.373, 0.408), fade))
	draw_arc(Vector2(0, 65), 14.0, 0.0, TAU, 32, _wreck_fade(STEEL, fade), 1.0, true)
	draw_line(Vector2(-8, 65), Vector2(8, 65), _wreck_fade(STEEL, fade), 1.0)
	draw_line(Vector2(0, -120), Vector2(0, -90), _wreck_fade(STEEL, fade), 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# Class-distinct turret art (LOOK-LOCK): L twin-barrel armored turret, M single-gun angular house,
# S open AA ring. Houses + barrels rotate to the WORLD barrel angle; barbettes stay hull-fixed.
func _draw_mounts() -> void:
	var fade: float = _wreck_alpha()
	if fade <= 0.0 or not show_ship:
		return
	var hp_cfg: HardpointConfig = _cfgs.hardpoints
	for i in range(mini(_world.mounts.size(), hp_cfg.mount_pos.size())):
		var m: Mount = _world.mounts[i]
		var size: String = hp_cfg.mount_size[i]
		var mpos: Vector2 = Turrets.mount_world(_world, hp_cfg.mount_pos[i])
		_recoil[i] *= 0.9
		var rec: float = _recoil[i]
		var forced: bool = m.mode == "forced"
		var house: Color = _wreck_fade(HOUSE_FORCED if forced else HOUSE, fade)
		# barbette rings — hull-fixed under the rotating turret
		draw_set_transform(mpos, 0.0, Vector2.ONE)
		if size == "L":
			draw_arc(Vector2.ZERO, 11.5, 0.0, TAU, 32, Color(FOAM.r, FOAM.g, FOAM.b, 0.25 * fade), 1.5, true)
		elif size == "M":
			draw_arc(Vector2.ZERO, 7.5, 0.0, TAU, 24, Color(FOAM.r, FOAM.g, FOAM.b, 0.25 * fade), 1.0, true)
		# house + barrels at the world barrel angle
		draw_set_transform(mpos, m.ang, Vector2.ONE)
		if size == "L":
			for bx in [-3.2, 3.2]:
				draw_rect(Rect2(bx - 1.3, -9.0 - 26.0 + rec * 4.0, 2.6, 26.0), _wreck_fade(STEEL, fade))
				draw_rect(Rect2(bx - 1.9, -9.0 - 26.0 + rec * 4.0, 3.8, 3.0), _wreck_fade(STEEL, fade))   # muzzle brakes
			var lh := PackedVector2Array()
			lh.append(Vector2(-8, 12)); lh.append(Vector2(-8, -4))
			_quad(lh, Vector2(-8, -4), Vector2(-8, -10), Vector2(0, -10), 5)
			_quad(lh, Vector2(0, -10), Vector2(8, -10), Vector2(8, -4), 5)
			lh.append(Vector2(8, 12))
			draw_colored_polygon(lh, house)
			var lhc := PackedVector2Array(lh); lhc.append(lh[0])
			draw_polyline(lhc, Color(0.039, 0.118, 0.157, 0.55), 1.0, true)
			draw_rect(Rect2(-10, 3, 3, 2.4), _wreck_fade(STEEL, fade))     # rangefinder ears
			draw_rect(Rect2(7, 3, 3, 2.4), _wreck_fade(STEEL, fade))
		elif size == "M":
			draw_rect(Rect2(-1.1, -6.0 - 16.0 + rec * 3.0, 2.2, 16.0), _wreck_fade(STEEL, fade))
			draw_rect(Rect2(-1.7, -6.0 - 7.0 + rec * 3.0, 3.4, 7.0), _wreck_fade(STEEL, fade))             # recoil sleeve
			var mh := PackedVector2Array([
				Vector2(-5.5, 8), Vector2(-5.5, -2), Vector2(-3, -6.5),
				Vector2(3, -6.5), Vector2(5.5, -2), Vector2(5.5, 8),
			])
			draw_colored_polygon(mh, house)
			var mhc := PackedVector2Array(mh); mhc.append(mh[0])
			draw_polyline(mhc, Color(0.039, 0.118, 0.157, 0.55), 1.0, true)
		else:
			var ring := _wreck_fade(Color(0.690, 0.537, 0.408) if forced else Color(0.494, 0.576, 0.612), fade)
			draw_arc(Vector2.ZERO, 5.5, 0.0, TAU, 20, ring, 1.2, true)                  # open ring mount
			for bx in [-1.5, 1.5]:
				draw_rect(Rect2(bx - 0.55, -2.0 - 11.0 + rec * 2.0, 1.1, 11.0), _wreck_fade(STEEL, fade))
			draw_circle(Vector2(0, 2.2), 2.6, house)                                    # pedestal + tub
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# C6: the AIR WING bird — shadow + dip ring while airborne, fuselage/boom/rotor at the helo
# heading, idle rotor + rearm arc on the pad. Reads sim state one-way; rotor spin is cosmetic.
func _draw_helo() -> void:
	if _cfgs == null or not _cfgs.tech.helo or not show_ship:
		return
	var hp: Vector2 = _world.helo_pos
	var airborne: bool = _world.helo_state != "pad"
	var now: float = Time.get_ticks_msec() * 1.0
	if airborne:
		# the shadow slips off the airframe — the bird reads as ABOVE the water
		draw_set_transform(hp + Vector2(9, 12), 0.0, Vector2(1.0, 0.57))
		draw_circle(Vector2.ZERO, 7.0, Color(0.016, 0.047, 0.063, 0.35))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# dip ring pulse: the ears in the water
		var k: float = fmod(now * 0.0006, 1.0)
		draw_arc(hp, maxf(0.5, _cfgs.airwing.dip_radius * k), 0.0, TAU, 48,
			Color(FOAM.r, FOAM.g, FOAM.b, 0.18 * (1.0 - k)), 1.2, true)
		draw_arc(hp, _cfgs.airwing.dip_radius, 0.0, TAU, 48, Color(FOAM.r, FOAM.g, FOAM.b, 0.10), 1.0, true)
	draw_set_transform(hp, _world.helo_heading, Vector2.ONE)
	var body: Color = Color(0.353, 0.439, 0.478) if airborne else Color(0.278, 0.345, 0.373)
	draw_set_transform(hp, _world.helo_heading, Vector2(0.52, 1.0))
	draw_circle(Vector2(0, 1), 6.5, body)                       # fuselage (ellipse via scale)
	draw_set_transform(hp, _world.helo_heading, Vector2.ONE)
	draw_rect(Rect2(-1.1, 4, 2.2, 9), body)                     # tail boom
	draw_rect(Rect2(-2.6, 12, 5.2, 1.6), STEEL)                 # tail rotor bar
	draw_circle(Vector2(0, -2.2), 1.5, Color(FOAM.r, FOAM.g, FOAM.b, 0.75))   # canopy glint
	var spin: float = now * (0.045 if airborne else 0.006)      # idle turn on the pad
	draw_arc(Vector2.ZERO, 11.0, 0.0, TAU, 24, Color(FOAM.r, FOAM.g, FOAM.b, 0.14), 1.0, true)
	draw_line(Vector2(cos(spin), sin(spin)) * 11.0, Vector2(-cos(spin), -sin(spin)) * 11.0,
		Color(FOAM.r, FOAM.g, FOAM.b, 0.55), 1.4)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if not airborne and _world.helo_rearm > 0.0:                # rearm progress arc over the pad
		var kk: float = 1.0 - _world.helo_rearm / maxf(_cfgs.airwing.turnaround_secs, 0.001)
		draw_arc(hp, 16.0, -PI / 2.0, -PI / 2.0 + TAU * kk, 24,
			Color(0.804, 0.729, 0.557, 0.7), 2.0, true)

const FX_LIFE := {
	"muzzle": 0.12, "gunflash": 0.12, "hit": 0.12, "ignite": 0.3, "shiphit": 0.4,
	"airburst": 0.45, "death": 0.5, "splash": 0.7, "crashturn": 0.8, "shipdeath": 2.2,
	"dcvolley": 0.3, "dcblast": 0.9, "contact": 1.2,
	"helodrop": 0.35, "helodown": 0.5, "gunsplash": 0.25,
	"waveclear": 0.0,
}

func _draw_fx() -> void:
	var now: int = Time.get_ticks_msec()
	var i: int = _fx.size() - 1
	while i >= 0:
		var e: Dictionary = _fx[i]
		var life: float = FX_LIFE.get(e["type"], 0.12)
		var age: float = (now - e["t0"]) / 1000.0
		if age >= life:
			_fx.remove_at(i)
			i -= 1
			continue
		var k: float = age / life
		match e["type"]:
			"muzzle":
				var dirv := Vector2(sin(e["ang"]), -cos(e["ang"]))
				var flen: float = FLASH_LEN[e["size"]]
				var fr: float = (6.5 if e["size"] == "L" else (3.2 if e["size"] == "M" else 2.2)) * (1.0 + k)
				draw_circle(e["pos"] + dirv * flen, fr, Color(FLASH.r, FLASH.g, FLASH.b, 0.9 * (1.0 - k)))
			"gunflash":
				var gd := Vector2(sin(e["ang"]), -cos(e["ang"]))
				draw_circle(e["pos"] + gd * 14.0, 3.0 * (1.0 + k), Color(0.914, 0.404, 0.259, 0.9 * (1.0 - k)))
			"splash":
				draw_arc(e["pos"], maxf(0.5, e["r"] * k), 0.0, TAU, 40, Color(FOAM.r, FOAM.g, FOAM.b, 0.7 * (1.0 - k)), 2.0, true)
			"airburst":   # PROXIMITY BURST (C4): amber flak cloud
				draw_arc(e["pos"], e["r"] * (0.4 + k * 0.6), 0.0, TAU, 24, Color(FLASH.r, FLASH.g, FLASH.b, 0.85 * (1.0 - k)), 1.6, true)
				draw_circle(e["pos"], 3.0 * (1.0 - k), Color(FLASH.r, FLASH.g, FLASH.b, 0.5 * (1.0 - k)))
			"ignite":     # INCENDIARY (C4): catch-fire pop
				draw_circle(e["pos"], 5.0 * (1.0 + k), Color(FLASH.r, FLASH.g, FLASH.b, 0.9 * (1.0 - k)))
			"crashturn":  # CRASH TURN (C4): amber wash off the hull
				draw_arc(_world.ship_pos, 40.0 + 160.0 * k, 0.0, TAU, 48, Color(FLASH.r, FLASH.g, FLASH.b, 0.7 * (1.0 - k)), 3.0, true)
			"dcblast":    # C5: underwater bulge — pale dome swelling, dark ring chasing it
				draw_circle(e["pos"], e["r"] * (0.3 + k * 0.7), Color(FOAM.r, FOAM.g, FOAM.b, 0.35 * (1.0 - k)))
				draw_arc(e["pos"], maxf(0.5, e["r"] * k), 0.0, TAU, 40, Color(0.094, 0.165, 0.212, 0.8 * (1.0 - k)), 3.0, true)
			"dcvolley":   # C5: the racks roll — a foam pulse off the stern
				draw_arc(e["pos"], 12.0 + 30.0 * k, 0.0, TAU, 32, Color(FOAM.r, FOAM.g, FOAM.b, 0.6 * (1.0 - k)), 1.5, true)
			"helodrop":   # C6: the light rack lets go
				draw_arc(e["pos"], 8.0 + 22.0 * k, 0.0, TAU, 24, Color(FOAM.r, FOAM.g, FOAM.b, 0.55 * (1.0 - k)), 1.4, true)
			"helodown":   # C6: flare + touchdown puff on the pad
				draw_arc(e["pos"], 10.0 + 14.0 * k, 0.0, TAU, 24, Color(0.804, 0.729, 0.557, 0.5 * (1.0 - k)), 1.2, true)
			"gunsplash":  # C6: a door-gun round stitches the water
				draw_circle(e["pos"], 1.5 + 3.0 * k, Color(FOAM.r, FOAM.g, FOAM.b, 0.5 * (1.0 - k)))
			"contact":    # C5: sonar acquisition ping — expanding diamond over the water
				var cr: float = 10.0 + 30.0 * k
				var dia := PackedVector2Array([
					e["pos"] + Vector2(0, -cr), e["pos"] + Vector2(cr, 0),
					e["pos"] + Vector2(0, cr), e["pos"] + Vector2(-cr, 0), e["pos"] + Vector2(0, -cr),
				])
				draw_polyline(dia, Color(FOAM.r, FOAM.g, FOAM.b, 0.8 * (1.0 - k)), 1.5, true)
			"death":
				draw_arc(e["pos"], 4.0 + 26.0 * k, 0.0, TAU, 32, Color(RED.r, RED.g, RED.b, 0.85 * (1.0 - k)), 2.0, true)
			"shiphit":
				draw_arc(e["pos"], 10.0 + 40.0 * k, 0.0, TAU, 32, Color(RED.r, RED.g, RED.b, 0.9 * (1.0 - k)), 3.0, true)
			"shipdeath":
				for ring in range(3):
					var rk: float = maxf(0.0, k - ring * 0.12)
					draw_arc(e["pos"], 10.0 + 220.0 * rk, 0.0, TAU, 48,
						Color(0.914, 0.404, 0.259, 0.9 * (1.0 - rk)), 4.0 - ring, true)
			"hit":
				draw_circle(e["pos"], 3.0, Color(FOAM.r, FOAM.g, FOAM.b, 0.8 * (1.0 - k)))
		i -= 1
