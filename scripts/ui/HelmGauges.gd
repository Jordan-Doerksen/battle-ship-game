class_name HelmGauges
extends Control
# The gauge bank + sortie HUD — 1:1 with the owner-approved mockups (C2 LOOK-LOCK carried into C3):
# hull pips + grace flicker, engine order, way bar, helm, batteries line; the wave plate (top-left);
# the radar scope with fire-control bearing (bottom-right, C3 gate revisions 1–2); the force-fire
# reticle; and the SHIP LOST card. C12 readability/flow: torpedo wake-dash blips, the DC arm ring +
# rack dial, the PAUSED plate, the advisory plate, and the lost-card misclick guard. Reads the world
# one-way each frame; writes nothing back (Main sets `paused`/`hint`/`lost_report`). Layout
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
var _shot_flashes: Array = []   # C11 fall-of-shot: own main-battery bursts flash on the scope
const FLASH_LIFE := 1.2         # seconds a burst flash lives on the scope

# C12 flow: Main sets both per frame (one-way, same channel as everything else here)
var paused: bool = false        # true while the sim holds — the PAUSED plate shows
var hint: String = ""           # the active advisory line ("" = none) — the drip-onboarding plate
var _lost_shown_ms: int = -1    # C12 misclick guard: first frame the lost card drew this run
const LOST_GUARD_MS := 1500     # the card holds this long before the restart prompt reveals

func bind(world: GameWorld, cfgs: Configs) -> void:
	_world = world
	_cfgs = cfgs
	_shot_flashes.clear()
	_lost_shown_ms = -1
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["DejaVu Sans Mono", "Cascadia Mono", "Menlo", "Consolas", "monospace"])
	_mono = mono
	_sans = ThemeDB.fallback_font

# C11: Main hands the sim's effect batch here too (same one-way channel as FieldRenderer) —
# the scope keeps only what it paints: friendly main-battery bursts, as fall-of-shot flashes.
func consume_effects(events: Array) -> void:
	var now: int = Time.get_ticks_msec()
	for e in events:
		if e["type"] == "splash" and not e.get("hostile", false) and e.get("r", 0.0) >= 28.0:
			_shot_flashes.append({ "pos": e["pos"], "t0": now })
	while _shot_flashes.size() > 24:
		_shot_flashes.pop_front()

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

var _boss_seen_ms: int = -1   # render-side: when the current machine first appeared (plate flash)

func _draw() -> void:
	if _world == null:
		return
	_draw_gauge_plate()
	_draw_wave_plate()
	_draw_boss_plate()
	_draw_radar()
	if _world.run_over:
		_draw_lost_card()
	else:
		_lost_shown_ms = -1   # self-heals across restarts even if bind() isn't re-run
		_draw_reticle()
		if hint != "":
			_draw_hint_plate()
		if paused:
			_draw_pause_plate()

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

	# ── batteries + racks + heading ──
	y += 24.0
	var ol := _order_label()
	draw_string(_mono, Vector2(x, y), "BATTERIES: " + (ol + " ON POINT" if ol != "" else "AUTO"),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, BRASS)
	var hdg_txt := "HDG %03d°" % roundi(fposmod(_world.ship_heading * 180.0 / PI, 360.0))
	draw_string(_mono, Vector2(right - _mono.get_string_size(hdg_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x, y),
		hdg_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, BRASS)
	# C12 rack state, relocated at the play-test (the on-scope dial read as a contact):
	# center of the same instrument line — both states same width, the plate never reflows
	var armed: bool = _world.dc_cool <= 0.0
	var rack_txt := "RACKS ARMED" if armed else "RACKS · · ·"
	var rack_w := _mono.get_string_size(rack_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string(_mono, Vector2(x + (right - x - rack_w) * 0.56, y), rack_txt,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, FOAM if armed else BRASS_DIM)

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
		# C7 naming pass: the plate reads like a newsreel — reporting names, tallied
		var tally := {}
		for e in _world.enemies:
			if e.active:
				var def: EnemyDef = _cfgs.enemies.by_id(e.type_id)
				var nm: String = def.rep if (def != null and def.rep != "") else e.type_id
				tally[nm] = int(tally.get(nm, 0)) + 1
		var bits: Array[String] = []
		if _world.boss != null:
			bits.append("☠ " + Bosses.def_of(_world, _cfgs).display_name)
		for nm in tally:
			bits.append("%s ×%d" % [nm, tally[nm]])
		line = "WAVE %d · %s" % [_world.wave, " · ".join(bits)] if not bits.is_empty() \
			else "WAVE %d · CONTACTS: 0" % _world.wave
	elif _world.wave == 0:
		line = "CONTACTS INBOUND — %d" % maxi(0, ceili(_world.lull_until - _world.elapsed))
	else:
		line = "WAVE %d CLEARED — NEXT IN 0:%02d" % [_world.wave, maxi(0, ceili(_world.lull_until - _world.elapsed))]
	draw_string(_mono, Vector2(x, origin.y + 50.0), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, FOAM)
	draw_string(_mono, Vector2(x, origin.y + 72.0), "DRONES DESTROYED: %d" % _world.kills,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, BRASS)
	draw_string(_mono, Vector2(x, origin.y + 90.0), "XP +%d" % _world.xp_run,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, BRASS)

# ── PRIORITY TARGET plate (C7): top center — THE-name, core bar, part pips that strike through ──
func _draw_boss_plate() -> void:
	if _world.boss == null:
		_boss_seen_ms = -1
		return
	if _boss_seen_ms < 0:
		_boss_seen_ms = Time.get_ticks_msec()
	var def: BossDef = Bosses.def_of(_world, _cfgs)
	var b: Boss = _world.boss
	var pw := 440.0
	var ph := 76.0
	var origin := Vector2((size.x - pw) * 0.5, 12.0)
	var pts := PackedVector2Array([
		origin + Vector2(12, 0), origin + Vector2(pw, 0), origin + Vector2(pw, ph - 12),
		origin + Vector2(pw - 12, ph), origin + Vector2(0, ph), origin + Vector2(0, 12),
	])
	draw_colored_polygon(pts, Color(0.078, 0.039, 0.031, 0.88))
	var closed := PackedVector2Array(pts); closed.append(pts[0])
	draw_polyline(closed, RED, 1.2, true)
	var cx := origin.x + pw * 0.5
	_centered_spaced(cx, origin.y + 14.0, "PRIORITY TARGET", 8, Color(RED.r, RED.g, RED.b, 0.9), 3.5)
	# the name flashes for its first beats in theater (the klaxon moment)
	var fresh: bool = Time.get_ticks_msec() - _boss_seen_ms < 2400
	var flick: bool = fresh and (Time.get_ticks_msec() / 250) % 2 == 0
	var nm: String = def.display_name + ("  ·  LAP %d" % b.lap if b.lap > 1 else "")
	draw_string(_mono, Vector2(cx - _mono.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x * 0.5, origin.y + 34.0),
		nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, RED if flick else FOAM)
	var bar := Rect2(origin.x + 18.0, origin.y + 42.0, pw - 36.0, 8.0)
	draw_rect(bar, Color(FOAM.r, FOAM.g, FOAM.b, 0.06))
	draw_rect(bar, Color(RED.r, RED.g, RED.b, 0.6), false, 1.0)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(b.core / b.core_max, 0.0, 1.0), bar.size.y)), RED)
	# part pips
	var total_w := 0.0
	var widths: Array[float] = []
	for pd in def.parts:
		var w: float = _sans.get_string_size(pd["pn"], HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 14.0
		widths.append(w)
		total_w += w + 6.0
	var px := cx - (total_w - 6.0) * 0.5
	for i in range(def.parts.size()):
		var dead: bool = b.parts[i]["dead"]
		var r := Rect2(px, origin.y + 56.0, widths[i], 13.0)
		draw_rect(r, Color(BRASS_DIM.r, BRASS_DIM.g, BRASS_DIM.b, 0.3 if dead else 0.5), false, 1.0)
		var col := Color(BRASS_DIM.r, BRASS_DIM.g, BRASS_DIM.b, 0.55) if dead else BRASS
		draw_string(_sans, Vector2(r.position.x + 7.0, r.position.y + 10.0), def.parts[i]["pn"],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)
		if dead:   # struck through
			draw_line(Vector2(r.position.x + 4.0, r.get_center().y), Vector2(r.end.x - 4.0, r.get_center().y),
				Color(RED.r, RED.g, RED.b, 0.7), 1.0)
		px += widths[i] + 6.0

# ── radar scope (bottom-right; C3 gate revisions 1–2 + C5 sonar). Air/surface contacts are free;
#    sub blips are sonar-gated diamonds (D1.10) inside the soft sonar ring — your only ears. ──
func _draw_radar() -> void:
	var c := Vector2(size.x - RADAR_R - 26.0, size.y - RADAR_R - 26.0)
	var rng_u: float = _cfgs.waves.radar_range
	var k: float = RADAR_R / rng_u
	draw_circle(c, RADAR_R, Color(0.051, 0.125, 0.157, 0.9))
	draw_arc(c, RADAR_R, 0.0, TAU, 64, PLATE_EDGE, 1.0, true)
	# play-test tune: 500u rings made the center ring soup — 1000u marks only, fainter
	var d := 1000.0
	while d < rng_u:
		draw_arc(c, d * k, 0.0, TAU, 48, Color(BRASS.r, BRASS.g, BRASS.b, 0.12), 1.0, true)
		d += 1000.0
	var mb := _cfgs.weapons.by_id("mb16")
	if mb != null:   # main-battery reach, dashed + named (play-test: nothing was named)
		_dashed_arc(c, mb.range_u * k, Color(BRASS.r, BRASS.g, BRASS.b, 0.35))
		_micro_label(Vector2(c.x, c.y - mb.range_u * k - 3.0), "16-IN", 0)
	# C5: the sonar radius — a soft filled ring, the only part of the scope that hears the deep
	draw_circle(c, _cfgs.sonar.radius * k, Color(FOAM.r, FOAM.g, FOAM.b, 0.045))
	draw_arc(c, _cfgs.sonar.radius * k, 0.0, TAU, 48, Color(FOAM.r, FOAM.g, FOAM.b, 0.28), 1.0, true)
	_micro_label(Vector2(c.x + _cfgs.sonar.radius * k + 4.0, c.y + 3.0), "SONAR", 1)
	# C12: the depth-charge arm range — DASHED foam, unmistakably a weapon ring, not ears
	_dashed_arc(c, _cfgs.sonar.dc_range * k, Color(FOAM.r, FOAM.g, FOAM.b, 0.6))
	_micro_label(Vector2(c.x - _cfgs.sonar.dc_range * k - 4.0, c.y + 3.0), "DC", -1)
	# viewport extent
	var view: Vector2 = get_viewport_rect().size
	var cam := get_viewport().get_camera_2d()
	var zoom: float = cam.zoom.x if cam != null else 1.0
	var vw: float = view.x * 0.5 / zoom * k
	var vh: float = view.y * 0.5 / zoom * k
	draw_rect(Rect2(c.x - vw, c.y - vh, vw * 2.0, vh * 2.0), Color(FOAM.r, FOAM.g, FOAM.b, 0.14), false, 1.0)
	_micro_label(Vector2(c.x - vw + 3.0, c.y - vh - 2.0), "VIEW", 1)
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
		if e.layer == "sub":   # detected subs only, as a foam diamond (D1.10 radar gating)
			if not Sonar.detected(_world, e):
				continue
			draw_colored_polygon(PackedVector2Array([
				b + Vector2(0, -4), b + Vector2(4, 0), b + Vector2(0, 4), b + Vector2(-4, 0),
			]), Color(FOAM.r, FOAM.g, FOAM.b, 0.95))
		elif e.type_id == "gunboat":
			draw_rect(Rect2(b.x - 2.8, b.y - 2.8, 5.6, 5.6), RED)
		else:
			draw_circle(b, 3.6 if e.type_id == "bomber" else 2.4, RED if e.type_id == "bomber" else ORANGE)
	for i in range(_world.projectiles.items.size()):
		var p: Projectile = _world.projectiles.items[i]
		if not p.active:
			continue
		var off: Vector2 = (p.pos - _world.ship_pos) * k
		if off.length() > RADAR_R:
			continue
		if p.hostile:
			if p.wid == "torpedo":
				# C12: the C5-promised tell, finally paid — a bright foam dash laid along the run
				# plus two wake sparks fading astern (mockup panel 1). Jitter is cosmetic-clock only.
				var tb := c + off
				var dv: Vector2 = p.vel.normalized() if p.vel.length_squared() > 0.001 else Vector2.UP
				var perp := Vector2(-dv.y, dv.x)
				draw_line(tb - dv * 3.5, tb + dv * 3.5, Color(FOAM.r, FOAM.g, FOAM.b, 0.95), 2.0)
				var jbase: int = Time.get_ticks_msec() / 66 + i * 31
				for si in range(2):
					var j: float = (float((jbase + si * 17) % 7) / 3.0 - 1.0) * 1.2
					var sp: Vector2 = tb - dv * (5.0 + 4.5 * float(si + 1)) + perp * j
					draw_rect(Rect2(sp.x - 0.7, sp.y - 0.7, 1.4, 1.4),
						Color(FOAM.r, FOAM.g, FOAM.b, 0.65 if si == 0 else 0.4))
			else:
				draw_rect(Rect2(c.x + off.x - 0.8, c.y + off.y - 0.8, 1.6, 1.6), Color(ORANGE.r, ORANGE.g, ORANGE.b, 0.8))
		elif p.wid == "mb16":   # C11 fall-of-shot: your own salvo exists on the scope
			draw_rect(Rect2(c.x + off.x - 0.8, c.y + off.y - 0.8, 1.6, 1.6), Color(FOAM.r, FOAM.g, FOAM.b, 0.85))
	# C11: burst flashes — each main-battery splash blooms briefly where it landed
	var fnow: int = Time.get_ticks_msec()
	var fi: int = _shot_flashes.size() - 1
	while fi >= 0:
		var fl: Dictionary = _shot_flashes[fi]
		var age: float = (fnow - fl["t0"]) / 1000.0
		if age >= FLASH_LIFE:
			_shot_flashes.remove_at(fi)
			fi -= 1
			continue
		var foff: Vector2 = (Vector2(fl["pos"]) - _world.ship_pos) * k
		if foff.length() <= RADAR_R:
			var fk: float = age / FLASH_LIFE
			draw_arc(c + foff, 1.5 + 5.0 * fk, 0.0, TAU, 16,
				Color(FOAM.r, FOAM.g, FOAM.b, 0.9 * (1.0 - fk)), 1.2, true)
		fi -= 1
	# C7: the machine on the scope — oversized blip, sonar-gated while it stalks under
	if _world.boss != null:
		var boff: Vector2 = (_world.boss.pos - _world.ship_pos) * k
		if boff.length() <= RADAR_R:
			var bb := c + boff
			var under: bool = Bosses.domain_of(_world, _cfgs) == "sub"
			if not under:
				draw_rect(Rect2(bb.x - 5, bb.y - 5, 10, 10), RED, false, 2.0)
				draw_rect(Rect2(bb.x - 2.5, bb.y - 2.5, 5, 5), Color(RED.r, RED.g, RED.b, 0.5))
			elif _world.elapsed < _world.boss.detected_until:
				var dia := PackedVector2Array([
					bb + Vector2(0, -7), bb + Vector2(7, 0), bb + Vector2(0, 7), bb + Vector2(-7, 0), bb + Vector2(0, -7),
				])
				draw_polyline(dia, Color(FOAM.r, FOAM.g, FOAM.b, 0.95), 1.6, true)
	# C6: the bird on the scope — a friendly cross + its dip ring while airborne
	if _cfgs.tech.helo and _world.helo_state != "pad":
		var hoff: Vector2 = (_world.helo_pos - _world.ship_pos) * k
		if hoff.length() <= RADAR_R:
			var hb := c + hoff
			draw_arc(hb, _cfgs.airwing.dip_radius * k, 0.0, TAU, 24, Color(FOAM.r, FOAM.g, FOAM.b, 0.20), 1.0, true)
			draw_line(hb + Vector2(-3, 0), hb + Vector2(3, 0), Color(FOAM.r, FOAM.g, FOAM.b, 0.9), 1.2)
			draw_line(hb + Vector2(0, -3), hb + Vector2(0, 3), Color(FOAM.r, FOAM.g, FOAM.b, 0.9), 1.2)
	# own ship + heading tick
	var f := Vector2(sin(_world.ship_heading), -cos(_world.ship_heading))
	draw_line(c - f * 4.0, c + f * 7.0, FOAM, 1.6)
	draw_circle(c, 2.0, FOAM)
	# (play-test tune: the C12 rack dial looked like a contact floating in the water —
	#  the rack state moved to the gauge plate's batteries line, where instruments live)
	_label(c.x - 26.0, c.y - RADAR_R - 8.0, "RADAR")

# tiny on-scope ring name (play-test tune: nothing on the scope was named).
# align: -1 = text ends at pos, 0 = centered on pos, 1 = text starts at pos.
func _micro_label(pos: Vector2, text: String, align: int) -> void:
	var w: float = _mono.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var x: float = pos.x - (w if align < 0 else (w * 0.5 if align == 0 else 0.0))
	draw_string(_mono, Vector2(x, pos.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8,
		Color(BRASS_DIM.r, BRASS_DIM.g, BRASS_DIM.b, 0.75))

func _dashed_arc(c: Vector2, r: float, col: Color) -> void:
	var segs := 36
	for i in range(segs):
		if i % 2 == 0:
			draw_arc(c, r, TAU * i / segs, TAU * (i + 1) / segs, 4, col, 1.0, true)

# ── SHIP LOST card (C3 + C4 XP report; C12 misclick guard — the card holds 1.5 s, a quiet
#    "…" where the prompt goes, then the key-only restart line reveals. Main ignores clicks;
#    this side only paints the hold.) ──
func _draw_lost_card() -> void:
	if _lost_shown_ms < 0:
		_lost_shown_ms = Time.get_ticks_msec()
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
	if Time.get_ticks_msec() - _lost_shown_ms < LOST_GUARD_MS:
		_centered_spaced(cxr, origin.y + 150.0, "…", 11, Color(BRASS.r, BRASS.g, BRASS.b, 0.55), 3.0)
	else:
		_centered_spaced(cxr, origin.y + 150.0, "R — NEW SORTIE · T — THE TREE", 11, BRASS, 3.0)

func _centered_spaced(cx: float, y: float, text: String, px: int, col: Color, tracking: float) -> void:
	var total := 0.0
	for ch in text:
		total += _sans.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + tracking
	var x := cx - total * 0.5
	for ch in text:
		draw_string(_sans, Vector2(x, y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)
		x += _sans.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + tracking

# ── C12 PAUSED plate — the sim holds; the sea keeps drifting on the render clock by design ──
func _draw_pause_plate() -> void:
	var pw := 340.0
	var ph := 96.0
	var origin := Vector2((size.x - pw) * 0.5, (size.y - ph) * 0.5)
	_draw_plate(origin, Vector2(pw, ph))
	var cx := origin.x + pw * 0.5
	_centered_spaced(cx, origin.y + 40.0, "PAUSED", 22, FOAM, 7.0)
	var sub := "The war waits. The sea doesn't."
	draw_string(_mono, Vector2(cx - _mono.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x * 0.5, origin.y + 62.0),
		sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, BRASS)
	_centered_spaced(cx, origin.y + 82.0, "P — RESUME", 8, BRASS_DIM, 2.5)

# ── C12 advisory plate — the contextual-drip onboarding line. Main decides WHAT and WHEN
#    (once per profile); this side only paints. FIXED 560×54 whatever the text — the UI never
#    reflows (house rule). Deadpan; no border flash. Sits below the boss-plate zone (ends y 88). ──
func _draw_hint_plate() -> void:
	var pw := 560.0
	var ph := 54.0
	var origin := Vector2((size.x - pw) * 0.5, 96.0)
	_draw_plate(origin, Vector2(pw, ph))
	var cx := origin.x + pw * 0.5
	_centered_spaced(cx, origin.y + 20.0, "ADVISORY", 9, BRASS_DIM, 2.5)
	draw_string(_mono, Vector2(cx - _mono.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x * 0.5, origin.y + 40.0),
		hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, FOAM)

# ── force-fire reticle (+ C11: flight time, the MAX RANGE telltale, the RANGEKEEPER ghost) ──
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
	# C11: while the MAIN battery is ordered, the reticle reads the shot — flight time to the
	# burst point, or the mode telltale when the cursor is past reach (the C3 bearing shot).
	if _world.input.force_all or _world.input.force_large:
		var mb: WeaponDef = _cfgs.weapons.by_id("mb16")
		if mb != null:
			var origin: Vector2 = _nearest_l_mount(_world.input.aim_world)
			var dist: float = origin.distance_to(_world.input.aim_world)
			var line: String = "%.1f s · %d u" % [dist / mb.speed, int(dist)] if dist <= mb.range_u \
				else "MAX RANGE · BEARING"
			draw_string(_mono, mp + Vector2(-34, 28), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
				Color(FOAM.r, FOAM.g, FOAM.b, 0.85))
			_draw_rangekeeper(mb, origin)

# C11 ord7 — the plotting room advises: a ghost diamond at the computed intercept for the surface
# contact nearest the cursor (within the snap radius). Advisory only: shells obey the cursor.
# HUD-side one-way read; enemy velocity derived exactly as Turrets leads (heading × def speed).
func _draw_rangekeeper(mb: WeaponDef, origin: Vector2) -> void:
	if not _cfgs.tech.rangekeeper:
		return
	var best: Enemy = null
	var bd: float = _cfgs.tech.rangekeeper_snap
	for e in _world.enemies:
		if not e.active or e.layer != "surf":
			continue
		var d: float = e.pos.distance_to(_world.input.aim_world)
		if d <= bd:
			bd = d
			best = e
	if best == null:
		return
	var tdef: EnemyDef = _cfgs.enemies.by_id(best.type_id)
	var tvel := Vector2(sin(best.heading), -cos(best.heading)) * (tdef.speed if tdef != null else 0.0)
	var cap: float = mb.range_u / mb.speed
	var t: float = minf(origin.distance_to(best.pos) / mb.speed, cap)
	var ghost: Vector2 = best.pos + tvel * t
	t = minf(origin.distance_to(ghost) / mb.speed, cap)
	ghost = best.pos + tvel * t
	var cam := get_viewport().get_camera_2d()
	var zoom: float = cam.zoom.x if cam != null else 1.0
	var half: Vector2 = get_viewport_rect().size * 0.5
	var gs: Vector2 = (ghost - _world.ship_pos) * zoom + half
	var ts: Vector2 = (best.pos - _world.ship_pos) * zoom + half
	draw_line(ts, gs, Color(STEEL.r, STEEL.g, STEEL.b, 0.5), 1.0)
	var dia := PackedVector2Array([
		gs + Vector2(0, -6), gs + Vector2(6, 0), gs + Vector2(0, 6), gs + Vector2(-6, 0), gs + Vector2(0, -6),
	])
	draw_polyline(dia, Color(STEEL.r, STEEL.g, STEEL.b, 0.9), 1.4, true)
	draw_string(_mono, gs + Vector2(9, -6), "RK", HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
		Color(STEEL.r, STEEL.g, STEEL.b, 0.8))

func _nearest_l_mount(pt: Vector2) -> Vector2:
	var hp: HardpointConfig = _cfgs.hardpoints
	var best: Vector2 = _world.ship_pos
	var bd: float = INF
	for i in range(hp.mount_pos.size()):
		if hp.mount_size[i] != "L":
			continue
		var mpos: Vector2 = Turrets.mount_world(_world, hp.mount_pos[i])
		var d: float = mpos.distance_to(pt)
		if d < bd:
			bd = d
			best = mpos
	return best

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
