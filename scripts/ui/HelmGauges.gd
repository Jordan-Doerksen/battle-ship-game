class_name HelmGauges
extends Control
# The gauge bank + sortie HUD — 1:1 with the owner-approved mockups (C2 LOOK-LOCK carried into C3):
# hull pips + grace flicker, engine order, way bar, helm, batteries line; the wave plate (top-left);
# the radar scope with fire-control bearing (bottom-right, C3 gate revisions 1–2); the force-fire
# reticle; and the SHIP LOST card. Reads the world one-way each frame; writes nothing back. Layout
# constants are cosmetic plate geometry, not tunables.

const PLATE_BG := Color(0.051, 0.125, 0.157, 0.88)
const PLATE_EDGE := Color(0.804, 0.729, 0.557, 0.5)
const BRASS := Color(0.804, 0.729, 0.557)
const BRASS_DIM := Color(0.557, 0.506, 0.373)
const FOAM := Color(0.894, 0.941, 0.949)
const RED := Color(0.851, 0.310, 0.169)
const ORANGE := Color(0.914, 0.404, 0.259)
const STEEL := Color(0.576, 0.655, 0.682, 0.85)

const PAD := 18.0
const PLATE_W := 330.0
const PLATE_H := 252.0
const INNER := 16.0
const RADAR_R := 105.0

var _world: GameWorld
var _cfgs: Configs
var _mono: Font
var _sans: Font

func bind(world: GameWorld, cfgs: Configs) -> void:
	_world = world
	_cfgs = cfgs
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["DejaVu Sans Mono", "Cascadia Mono", "Menlo", "Consolas", "monospace"])
	_mono = mono
	_sans = ThemeDB.fallback_font

func _order_label() -> String:
	if _world.input.force_all:
		return "ALL GUNS"
	if _world.input.force_large and _world.input.force_medium:
		return "MAIN + SECONDARY"
	if _world.input.force_large:
		return "MAIN BATTERY"
	if _world.input.force_medium:
		return "SECONDARIES"
	return ""

func _draw() -> void:
	if _world == null:
		return
	_draw_gauge_plate()
	_draw_wave_plate()
	_draw_radar()
	if _world.run_over:
		_draw_lost_card()
	else:
		_draw_reticle()

func _draw_gauge_plate() -> void:
	var origin := Vector2(PAD, size.y - PAD - PLATE_H)
	_draw_plate(origin, Vector2(PLATE_W, PLATE_H))
	var x := origin.x + INNER
	var right := origin.x + PLATE_W - INNER
	var y := origin.y + INNER

	var keel := Movement.keel_speeds(_world)
	var speed := _world.ship_vel.length()
	var pct := keel.x / _cfgs.movement.max_speed_ahead

	# ── hull integrity (C3) ──
	y += 8.0
	_label(x, y, "HULL INTEGRITY")
	y += 6.0
	var pips: int = _cfgs.waves.hull_pips
	var graced: bool = _world.elapsed < _world.grace_until and not _world.run_over
	var flick: bool = graced and (Time.get_ticks_msec() / 120) % 2 == 0
	var pw := (right - x - float(pips - 1) * 4.0) / float(pips)
	for i in range(pips):
		var r := Rect2(x + i * (pw + 4.0), y, pw, 12.0)
		if i < _world.hull:
			draw_rect(r, RED if flick else STEEL)
		draw_rect(r, BRASS_DIM, false, 1.0)
	y += 18.0

	# ── engine order ──
	y += 14.0
	_label(x, y, "ENGINE ORDER")
	y += 19.0
	draw_string(_mono, Vector2(x, y), _order_text(keel.x, speed), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, RED)

	# ── way on ship ──
	y += 20.0
	_label(x, y, "WAY ON SHIP")
	y += 25.0
	draw_string(_mono, Vector2(x, y), "%.1f" % absf(keel.x), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, FOAM)
	var big_w := _mono.get_string_size("%.1f" % absf(keel.x), HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	_label(x + big_w + 8.0, y - 2.0, "U/S KEEL")
	var pct_txt := "%d%% FULL AHEAD%s" % [roundi(absf(pct) * 100.0), " ASTERN" if keel.x < -0.5 else ""]
	draw_string(_mono, Vector2(right - _mono.get_string_size(pct_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x, y - 2.0),
		pct_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, BRASS)
	y += 9.0
	_draw_way_bar(Rect2(x, y, right - x, 12.0), pct)
	y += 14.0
	draw_string(_mono, Vector2(x, y + 8.0), "ASTERN 35%", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, BRASS_DIM)
	draw_string(_mono, Vector2(right - _mono.get_string_size("AHEAD 100%", HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x, y + 8.0),
		"AHEAD 100%", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, BRASS_DIM)

	# ── helm ──
	y += 22.0
	_label(x, y, "HELM")
	y += 16.0
	var rud := _world.input.rudder
	var rud_txt := "RUDDER AMIDSHIPS" if rud == 0.0 else ("RUDDER TO STARBOARD" if rud > 0.0 else "RUDDER TO PORT")
	draw_string(_mono, Vector2(x, y), rud_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, BRASS)
	var authority := maxf(_cfgs.movement.turn_speed_floor, minf(1.0, speed / _cfgs.movement.max_speed_ahead))
	var auth_txt := "AUTHORITY %d%%" % roundi(authority * 100.0)
	draw_string(_mono, Vector2(right - _mono.get_string_size(auth_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x, y),
		auth_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, BRASS)
	y += 8.0
	_draw_rudder_bar(Rect2(x, y, right - x, 12.0), rud)
	y += 14.0
	draw_string(_mono, Vector2(x, y + 8.0), "PORT", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, BRASS_DIM)
	draw_string(_mono, Vector2(right - _mono.get_string_size("STBD", HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x, y + 8.0),
		"STBD", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, BRASS_DIM)

	# ── batteries + heading ──
	y += 24.0
	var ol := _order_label()
	draw_string(_mono, Vector2(x, y), "BATTERIES: " + (ol + " ON POINT" if ol != "" else "AUTO"),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, BRASS)
	var hdg_txt := "HDG %03d°" % roundi(fposmod(_world.ship_heading * 180.0 / PI, 360.0))
	draw_string(_mono, Vector2(right - _mono.get_string_size(hdg_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x, y),
		hdg_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, BRASS)

func _order_text(along: float, speed: float) -> String:
	var t := _world.input.thrust
	if t > 0.0:
		return "AHEAD — COMING ABOUT" if along < -1.0 else "ALL AHEAD FULL"
	if t < 0.0:
		return "EMERGENCY BACK — BRAKING" if along > 1.0 else "ALL ASTERN"
	return "ALL STOP" if speed < 2.0 else "ADRIFT — COASTING"

var lost_report: Dictionary = {}   # Main fills at run end: { xp: int, leveled_to: int (0 = none) }

# ── wave plate (top-left; C3 + C4 XP tally) ──
func _draw_wave_plate() -> void:
	var origin := Vector2(PAD, PAD)
	_draw_plate(origin, Vector2(PLATE_W, 104.0))
	var x := origin.x + INNER
	_label(x, origin.y + 24.0, "★ EARTH DEFENSE FORCE · SORTIE COMMAND")
	var line := ""
	if _world.run_over:
		line = "WAVE %d — SHIP LOST" % _world.wave
	elif _world.wave_state == "fighting":
		var contacts := 0
		for e in _world.enemies:
			if e.active:
				contacts += 1
		line = "WAVE %d · CONTACTS: %d" % [_world.wave, contacts]
	elif _world.wave == 0:
		line = "CONTACTS INBOUND — %d" % maxi(0, ceili(_world.lull_until - _world.elapsed))
	else:
		line = "WAVE %d CLEARED — NEXT IN 0:%02d" % [_world.wave, maxi(0, ceili(_world.lull_until - _world.elapsed))]
	draw_string(_mono, Vector2(x, origin.y + 50.0), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, FOAM)
	draw_string(_mono, Vector2(x, origin.y + 72.0), "DRONES DESTROYED: %d" % _world.kills,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, BRASS)
	draw_string(_mono, Vector2(x, origin.y + 90.0), "XP +%d" % _world.xp_run,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, BRASS)

# ── radar scope (bottom-right; C3 gate revisions 1–2). Sub blips get sonar-gated in a later chunk
#    (D1.10); air/surface contacts are free. ──
func _draw_radar() -> void:
	var c := Vector2(size.x - RADAR_R - 26.0, size.y - RADAR_R - 26.0)
	var rng_u: float = _cfgs.waves.radar_range
	var k: float = RADAR_R / rng_u
	draw_circle(c, RADAR_R, Color(0.051, 0.125, 0.157, 0.9))
	draw_arc(c, RADAR_R, 0.0, TAU, 64, PLATE_EDGE, 1.0, true)
	var d := 500.0
	while d < rng_u:
		draw_arc(c, d * k, 0.0, TAU, 48, Color(BRASS.r, BRASS.g, BRASS.b, 0.16), 1.0, true)
		d += 500.0
	var mb := _cfgs.weapons.by_id("mb16")
	if mb != null:   # main-battery reach, dashed
		_dashed_arc(c, mb.range_u * k, Color(BRASS.r, BRASS.g, BRASS.b, 0.35))
	# viewport extent
	var view: Vector2 = get_viewport_rect().size
	var cam := get_viewport().get_camera_2d()
	var zoom: float = cam.zoom.x if cam != null else 1.0
	var vw: float = view.x * 0.5 / zoom * k
	var vh: float = view.y * 0.5 / zoom * k
	draw_rect(Rect2(c.x - vw, c.y - vh, vw * 2.0, vh * 2.0), Color(FOAM.r, FOAM.g, FOAM.b, 0.14), false, 1.0)
	# sweep (cosmetic)
	var sw: float = fmod(Time.get_ticks_msec() * 0.0016, TAU)
	draw_line(c, c + Vector2(sin(sw), -cos(sw)) * RADAR_R, Color(BRASS.r, BRASS.g, BRASS.b, 0.3), 1.0)
	# fire-control bearing while an order is held (gate rev 2)
	if _order_label() != "" and not _world.run_over:
		var ba: float = atan2(_world.input.aim_world.x - _world.ship_pos.x, -(_world.input.aim_world.y - _world.ship_pos.y))
		var bd := Vector2(sin(ba), -cos(ba))
		var mb_r: float = (mb.range_u if mb != null else 900.0) * k
		draw_line(c, c + bd * mb_r, Color(RED.r, RED.g, RED.b, 0.7), 1.4)
		draw_line(c + bd * mb_r, c + bd * RADAR_R, Color(RED.r, RED.g, RED.b, 0.3), 1.4)
		draw_arc(c + bd * mb_r, 2.6, 0.0, TAU, 12, Color(RED.r, RED.g, RED.b, 0.9), 1.0, true)
	# blips (clipped by range check)
	for e in _world.enemies:
		if not e.active:
			continue
		var off: Vector2 = (e.pos - _world.ship_pos) * k
		if off.length() > RADAR_R:
			continue
		var b := c + off
		if e.type_id == "gunboat":
			draw_rect(Rect2(b.x - 2.8, b.y - 2.8, 5.6, 5.6), RED)
		else:
			draw_circle(b, 3.6 if e.type_id == "bomber" else 2.4, RED if e.type_id == "bomber" else ORANGE)
	for i in range(_world.projectiles.items.size()):
		var p: Projectile = _world.projectiles.items[i]
		if not p.active or not p.hostile:
			continue
		var off: Vector2 = (p.pos - _world.ship_pos) * k
		if off.length() <= RADAR_R:
			draw_rect(Rect2(c.x + off.x - 0.8, c.y + off.y - 0.8, 1.6, 1.6), Color(ORANGE.r, ORANGE.g, ORANGE.b, 0.8))
	# own ship + heading tick
	var f := Vector2(sin(_world.ship_heading), -cos(_world.ship_heading))
	draw_line(c - f * 4.0, c + f * 7.0, FOAM, 1.6)
	draw_circle(c, 2.0, FOAM)
	_label(c.x - 26.0, c.y - RADAR_R - 8.0, "RADAR")

func _dashed_arc(c: Vector2, r: float, col: Color) -> void:
	var segs := 36
	for i in range(segs):
		if i % 2 == 0:
			draw_arc(c, r, TAU * i / segs, TAU * (i + 1) / segs, 4, col, 1.0, true)

# ── SHIP LOST card (C3 + C4 XP report) ──
func _draw_lost_card() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.024, 0.016, 0.55))
	var cw := 460.0
	var chh := 176.0
	var origin := Vector2((size.x - cw) * 0.5, (size.y - chh) * 0.5)
	var pts := PackedVector2Array([
		origin + Vector2(14, 0), origin + Vector2(cw, 0), origin + Vector2(cw, chh - 14),
		origin + Vector2(cw - 14, chh), origin + Vector2(0, chh), origin + Vector2(0, 14),
	])
	draw_colored_polygon(pts, PLATE_BG)
	var closed := PackedVector2Array(pts)
	closed.append(pts[0])
	draw_polyline(closed, RED, 1.2, true)
	var cxr := origin.x + cw * 0.5
	_centered_spaced(cxr, origin.y + 52.0, "SHIP LOST", 30, RED, 8.0)
	var stats := "WAVE %d · %d DRONES DESTROYED" % [_world.wave, _world.kills]
	draw_string(_mono, Vector2(cxr - _mono.get_string_size(stats, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x * 0.5, origin.y + 90.0),
		stats, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, FOAM)
	var xp_line := "+%d XP" % int(lost_report.get("xp", _world.xp_run))
	if int(lost_report.get("leveled_to", 0)) > 0:
		xp_line += " · LEVEL UP → %d" % int(lost_report["leveled_to"])
	draw_string(_mono, Vector2(cxr - _mono.get_string_size(xp_line, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x * 0.5, origin.y + 116.0),
		xp_line, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, BRASS)
	_centered_spaced(cxr, origin.y + 150.0, "[ R ]  NEW SORTIE      [ T ]  TECH TREE", 11, BRASS, 3.0)

func _centered_spaced(cx: float, y: float, text: String, px: int, col: Color, tracking: float) -> void:
	var total := 0.0
	for ch in text:
		total += _sans.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + tracking
	var x := cx - total * 0.5
	for ch in text:
		draw_string(_sans, Vector2(x, y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)
		x += _sans.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + tracking

# ── force-fire reticle ──
func _draw_reticle() -> void:
	var mp := get_viewport().get_mouse_position()
	var label := _order_label()
	var col := Color(RED.r, RED.g, RED.b, 0.95) if label != "" else Color(FOAM.r, FOAM.g, FOAM.b, 0.35)
	var r: float = 14.0 if label != "" else 9.0
	draw_arc(mp, r, 0.0, TAU, 32, col, 1.4, true)
	for dv in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		draw_line(mp + dv * (r - 4.0), mp + dv * (r + 5.0), col, 1.4)
	if label != "":
		draw_string(_sans, mp + Vector2(18, -12), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col)

# ── shared plate/label helpers ──
func _draw_plate(pos: Vector2, sz: Vector2) -> void:
	var c := 10.0
	var pts := PackedVector2Array([
		pos + Vector2(c, 0), pos + Vector2(sz.x, 0), pos + Vector2(sz.x, sz.y - c),
		pos + Vector2(sz.x - c, sz.y), pos + Vector2(0, sz.y), pos + Vector2(0, c),
	])
	draw_colored_polygon(pts, PLATE_BG)
	var closed := PackedVector2Array(pts)
	closed.append(pts[0])
	draw_polyline(closed, PLATE_EDGE, 1.0, true)

func _label(x: float, y: float, text: String) -> void:
	var cx := x
	for ch in text:
		draw_string(_sans, Vector2(cx, y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, BRASS_DIM)
		cx += _sans.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 2.5

func _draw_way_bar(rect: Rect2, pct: float) -> void:
	draw_rect(rect, Color(FOAM.r, FOAM.g, FOAM.b, 0.04))
	draw_rect(rect, BRASS_DIM, false, 1.0)
	var span := _cfgs.movement.astern_frac + 1.0
	var zero_x := rect.position.x + rect.size.x * (_cfgs.movement.astern_frac / span)
	var val_x := rect.position.x + rect.size.x * ((_cfgs.movement.astern_frac + clampf(pct, -_cfgs.movement.astern_frac, 1.0)) / span)
	if val_x != zero_x:
		draw_rect(Rect2(minf(zero_x, val_x), rect.position.y, absf(val_x - zero_x), rect.size.y), STEEL)
	draw_line(Vector2(zero_x, rect.position.y - 3.0), Vector2(zero_x, rect.end.y + 3.0), BRASS, 1.0)

func _draw_rudder_bar(rect: Rect2, rudder: float) -> void:
	draw_rect(rect, Color(FOAM.r, FOAM.g, FOAM.b, 0.04))
	draw_rect(rect, BRASS_DIM, false, 1.0)
	var mid_x := rect.position.x + rect.size.x * 0.5
	draw_line(Vector2(mid_x, rect.position.y - 3.0), Vector2(mid_x, rect.end.y + 3.0), BRASS, 1.0)
	var nx := rect.position.x + rect.size.x * (0.5 + rudder * 0.46)
	draw_line(Vector2(nx, rect.position.y - 3.0), Vector2(nx, rect.end.y + 3.0), RED, 2.0)
