class_name GaugePanel
extends RefCounted
# The bottom-left gauge plate — hull pips + grace flicker, engine order, way bar, helm/rudder bar,
# batteries + racks + heading line. Static draw funcs called by HelmGauges._draw; all state lives on
# the host (the C9 render-domain split pattern — reaches into `g._world`, `g.draw_string(...)`,
# `HelmGauges.BRASS`). `_order_label` stays on the orchestrator (gauge + wave both use it).

static func draw(g: HelmGauges) -> void:
	var origin := Vector2(HelmGauges.PAD, g.size.y - HelmGauges.PAD - HelmGauges.PLATE_H)
	g._draw_plate(origin, Vector2(HelmGauges.PLATE_W, HelmGauges.PLATE_H))
	var x := origin.x + HelmGauges.INNER
	var right := origin.x + HelmGauges.PLATE_W - HelmGauges.INNER
	var y := origin.y + HelmGauges.INNER

	var keel := Movement.keel_speeds(g._world)
	var speed := g._world.ship_vel.length()
	var pct := keel.x / g._cfgs.movement.max_speed_ahead

	# ── hull integrity (C3) ──
	y += 8.0
	g._label(x, y, "HULL INTEGRITY")
	y += 6.0
	var pips: int = g._cfgs.waves.hull_pips
	var graced: bool = g._world.elapsed < g._world.grace_until and not g._world.run_over
	var flick: bool = graced and (Time.get_ticks_msec() / 120) % 2 == 0
	var pw := (right - x - float(pips - 1) * 4.0) / float(pips)
	for i in range(pips):
		var r := Rect2(x + i * (pw + 4.0), y, pw, 12.0)
		if i < g._world.hull:
			g.draw_rect(r, HelmGauges.RED if flick else HelmGauges.STEEL)
		g.draw_rect(r, HelmGauges.BRASS_DIM, false, 1.0)
	y += 18.0

	# ── engine order ──
	y += 14.0
	g._label(x, y, "ENGINE ORDER")
	y += 19.0
	g.draw_string(g._mono, Vector2(x, y), GaugePanel._order_text(g, keel.x, speed), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, HelmGauges.RED)

	# ── way on ship ──
	y += 20.0
	g._label(x, y, "WAY ON SHIP")
	y += 25.0
	g.draw_string(g._mono, Vector2(x, y), "%.1f" % absf(keel.x), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, HelmGauges.FOAM)
	var big_w := g._mono.get_string_size("%.1f" % absf(keel.x), HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	g._label(x + big_w + 8.0, y - 2.0, "U/S KEEL")
	var pct_txt := "%d%% FULL AHEAD%s" % [roundi(absf(pct) * 100.0), " ASTERN" if keel.x < -0.5 else ""]
	g.draw_string(g._mono, Vector2(right - g._mono.get_string_size(pct_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x, y - 2.0),
		pct_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, HelmGauges.BRASS)
	y += 9.0
	GaugePanel._draw_way_bar(g, Rect2(x, y, right - x, 12.0), pct)
	y += 14.0
	g.draw_string(g._mono, Vector2(x, y + 8.0), "ASTERN 35%", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, HelmGauges.BRASS_DIM)
	g.draw_string(g._mono, Vector2(right - g._mono.get_string_size("AHEAD 100%", HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x, y + 8.0),
		"AHEAD 100%", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, HelmGauges.BRASS_DIM)

	# ── helm ──
	y += 22.0
	g._label(x, y, "HELM")
	y += 16.0
	var rud := g._world.input.rudder
	var rud_txt := "RUDDER AMIDSHIPS" if rud == 0.0 else ("RUDDER TO STARBOARD" if rud > 0.0 else "RUDDER TO PORT")
	g.draw_string(g._mono, Vector2(x, y), rud_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, HelmGauges.BRASS)
	var authority := maxf(g._cfgs.movement.turn_speed_floor, minf(1.0, speed / g._cfgs.movement.max_speed_ahead))
	var auth_txt := "AUTHORITY %d%%" % roundi(authority * 100.0)
	g.draw_string(g._mono, Vector2(right - g._mono.get_string_size(auth_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x, y),
		auth_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, HelmGauges.BRASS)
	y += 8.0
	GaugePanel._draw_rudder_bar(g, Rect2(x, y, right - x, 12.0), rud)
	y += 14.0
	g.draw_string(g._mono, Vector2(x, y + 8.0), "PORT", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, HelmGauges.BRASS_DIM)
	g.draw_string(g._mono, Vector2(right - g._mono.get_string_size("STBD", HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x, y + 8.0),
		"STBD", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, HelmGauges.BRASS_DIM)

	# ── batteries + racks + heading ──
	y += 24.0
	var ol := g._order_label()
	g.draw_string(g._mono, Vector2(x, y), "BATTERIES: " + (ol + " ON POINT" if ol != "" else "AUTO"),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, HelmGauges.BRASS)
	var hdg_txt := "HDG %03d°" % roundi(fposmod(g._world.ship_heading * 180.0 / PI, 360.0))
	g.draw_string(g._mono, Vector2(right - g._mono.get_string_size(hdg_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x, y),
		hdg_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, HelmGauges.BRASS)
	# C12 rack state, relocated at the play-test (the on-scope dial read as a contact):
	# center of the same instrument line — both states same width, the plate never reflows
	var armed: bool = g._world.dc_cool <= 0.0
	var rack_txt := "RACKS ARMED" if armed else "RACKS · · ·"
	var rack_w := g._mono.get_string_size(rack_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	g.draw_string(g._mono, Vector2(x + (right - x - rack_w) * 0.56, y), rack_txt,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, HelmGauges.FOAM if armed else HelmGauges.BRASS_DIM)

static func _order_text(g: HelmGauges, along: float, speed: float) -> String:
	var t := g._world.input.thrust
	if t > 0.0:
		return "AHEAD — COMING ABOUT" if along < -1.0 else "ALL AHEAD FULL"
	if t < 0.0:
		return "EMERGENCY BACK — BRAKING" if along > 1.0 else "ALL ASTERN"
	return "ALL STOP" if speed < 2.0 else "ADRIFT — COASTING"

static func _draw_way_bar(g: HelmGauges, rect: Rect2, pct: float) -> void:
	g.draw_rect(rect, Color(HelmGauges.FOAM.r, HelmGauges.FOAM.g, HelmGauges.FOAM.b, 0.04))
	g.draw_rect(rect, HelmGauges.BRASS_DIM, false, 1.0)
	var span := g._cfgs.movement.astern_frac + 1.0
	var zero_x := rect.position.x + rect.size.x * (g._cfgs.movement.astern_frac / span)
	var val_x := rect.position.x + rect.size.x * ((g._cfgs.movement.astern_frac + clampf(pct, -g._cfgs.movement.astern_frac, 1.0)) / span)
	if val_x != zero_x:
		g.draw_rect(Rect2(minf(zero_x, val_x), rect.position.y, absf(val_x - zero_x), rect.size.y), HelmGauges.STEEL)
	g.draw_line(Vector2(zero_x, rect.position.y - 3.0), Vector2(zero_x, rect.end.y + 3.0), HelmGauges.BRASS, 1.0)

static func _draw_rudder_bar(g: HelmGauges, rect: Rect2, rudder: float) -> void:
	g.draw_rect(rect, Color(HelmGauges.FOAM.r, HelmGauges.FOAM.g, HelmGauges.FOAM.b, 0.04))
	g.draw_rect(rect, HelmGauges.BRASS_DIM, false, 1.0)
	var mid_x := rect.position.x + rect.size.x * 0.5
	g.draw_line(Vector2(mid_x, rect.position.y - 3.0), Vector2(mid_x, rect.end.y + 3.0), HelmGauges.BRASS, 1.0)
	var nx := rect.position.x + rect.size.x * (0.5 + rudder * 0.46)
	g.draw_line(Vector2(nx, rect.position.y - 3.0), Vector2(nx, rect.end.y + 3.0), HelmGauges.RED, 2.0)
