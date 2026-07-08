class_name HelmGauges
extends Control
# The helm gauge bank — first piece of the future gauge-bank HUD (C1 spec: "speed/throttle readout").
# 1:1 port of the owner-approved mockup's bottom-left plate: engine order, way-on-ship digits + bar,
# helm rudder/authority, slip and heading. Reads the world one-way each frame; writes nothing back.
# Layout constants are cosmetic plate geometry, not tunables — handling numbers live in movement.tres.

const PLATE_BG := Color(0.051, 0.125, 0.157, 0.88)
const PLATE_EDGE := Color(0.804, 0.729, 0.557, 0.5)
const BRASS := Color(0.804, 0.729, 0.557)
const BRASS_DIM := Color(0.557, 0.506, 0.373)
const FOAM := Color(0.894, 0.941, 0.949)
const RED := Color(0.851, 0.310, 0.169)
const STEEL := Color(0.576, 0.655, 0.682, 0.85)

const PAD := 18.0            # plate inset from screen edge
const PLATE_W := 330.0
const PLATE_H := 208.0
const INNER := 16.0          # plate content inset

var _world: GameWorld
var _move_cfg: MovementConfig
var _mono: Font
var _sans: Font

func bind(world: GameWorld, move_cfg: MovementConfig) -> void:
	_world = world
	_move_cfg = move_cfg
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["DejaVu Sans Mono", "Cascadia Mono", "Menlo", "Consolas", "monospace"])
	_mono = mono
	_sans = ThemeDB.fallback_font

func _draw() -> void:
	if _world == null:
		return
	var origin := Vector2(PAD, size.y - PAD - PLATE_H)
	_draw_plate(origin, Vector2(PLATE_W, PLATE_H))
	var x := origin.x + INNER
	var right := origin.x + PLATE_W - INNER
	var y := origin.y + INNER

	var keel := Movement.keel_speeds(_world)   # x = along, y = lateral (starboard +)
	var speed := _world.ship_vel.length()
	var pct := keel.x / _move_cfg.max_speed_ahead

	# ── engine order ──
	y += 8.0
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
	var authority := maxf(_move_cfg.turn_speed_floor, minf(1.0, speed / _move_cfg.max_speed_ahead))
	var auth_txt := "AUTHORITY %d%%" % roundi(authority * 100.0)
	draw_string(_mono, Vector2(right - _mono.get_string_size(auth_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x, y),
		auth_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, BRASS)
	y += 8.0
	_draw_rudder_bar(Rect2(x, y, right - x, 12.0), rud)
	y += 14.0
	draw_string(_mono, Vector2(x, y + 8.0), "PORT", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, BRASS_DIM)
	draw_string(_mono, Vector2(right - _mono.get_string_size("STBD", HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x, y + 8.0),
		"STBD", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, BRASS_DIM)

	# ── slip + heading ──
	y += 24.0
	var slip_dir := "  → STBD" if keel.y > 0.5 else ("  ← PORT" if keel.y < -0.5 else "")
	draw_string(_mono, Vector2(x, y), "SLIP %.1f U/S%s" % [absf(keel.y), slip_dir], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, BRASS)
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

# steel plate with clipped corners — the mockup's clip-path polygon
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

# small-caps letterspaced label — the mockup's .g-label treatment
func _label(x: float, y: float, text: String) -> void:
	var cx := x
	for ch in text:
		draw_string(_sans, Vector2(cx, y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, BRASS_DIM)
		cx += _sans.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 2.5

# way bar: spans [−astern_frac .. +1] of full ahead, zero notch, steel fill from zero
func _draw_way_bar(rect: Rect2, pct: float) -> void:
	draw_rect(rect, Color(FOAM.r, FOAM.g, FOAM.b, 0.04))
	draw_rect(rect, BRASS_DIM, false, 1.0)
	var span := _move_cfg.astern_frac + 1.0
	var zero_x := rect.position.x + rect.size.x * (_move_cfg.astern_frac / span)
	var val_x := rect.position.x + rect.size.x * ((_move_cfg.astern_frac + clampf(pct, -_move_cfg.astern_frac, 1.0)) / span)
	if val_x != zero_x:
		var fill := Rect2(minf(zero_x, val_x), rect.position.y, absf(val_x - zero_x), rect.size.y)
		draw_rect(fill, STEEL)
	draw_line(Vector2(zero_x, rect.position.y - 3.0), Vector2(zero_x, rect.end.y + 3.0), BRASS, 1.0)

# rudder bar: centered zero, red needle at the ordered rudder position
func _draw_rudder_bar(rect: Rect2, rudder: float) -> void:
	draw_rect(rect, Color(FOAM.r, FOAM.g, FOAM.b, 0.04))
	draw_rect(rect, BRASS_DIM, false, 1.0)
	var mid_x := rect.position.x + rect.size.x * 0.5
	draw_line(Vector2(mid_x, rect.position.y - 3.0), Vector2(mid_x, rect.end.y + 3.0), BRASS, 1.0)
	var nx := rect.position.x + rect.size.x * (0.5 + rudder * 0.46)
	draw_line(Vector2(nx, rect.position.y - 3.0), Vector2(nx, rect.end.y + 3.0), RED, 2.0)
