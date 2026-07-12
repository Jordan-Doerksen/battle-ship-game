class_name StatusPlates
extends RefCounted
# The wave plate (top-left; sortie tally + XP) and the PRIORITY TARGET boss plate (top center;
# THE-name, core bar, part pips that strike through). Static draw funcs called by HelmGauges._draw;
# all state lives on the host (the C9 render-domain split pattern). draw_boss writes g._boss_seen_ms.

# ── wave plate (top-left; C3 + C4 XP tally) ──
static func draw_wave(g: HelmGauges) -> void:
	var origin := Vector2(HelmGauges.PAD, HelmGauges.PAD)
	g._draw_plate(origin, Vector2(HelmGauges.PLATE_W, 104.0))
	var x := origin.x + HelmGauges.INNER
	g._label(x, origin.y + 24.0, "★ THE STRAIT OF HORMUZ · STRAIT PICKET")
	var line := ""
	if g._world.run_over:
		line = "WAVE %d — SHIP LOST" % g._world.wave
	elif g._world.wave_state == "fighting":
		# C7 naming pass + C16 echelon phase: the plate reads like a newsreel — the drill phase
		# (which echelon is on the water) then the reporting-name tally
		var tally := {}
		for e in g._world.enemies:
			if e.active:
				var def: EnemyDef = g._cfgs.enemies.by_id(e.type_id)
				var nm: String = def.rep if (def != null and def.rep != "") else e.type_id
				tally[nm] = int(tally.get(nm, 0)) + 1
		var bits: Array[String] = []
		if g._world.boss != null:
			bits.append("☠ " + Bosses.def_of(g._world, g._cfgs).display_name)
		for nm in tally:
			bits.append("%s ×%d" % [nm, tally[nm]])
		# C16: name the latest echelon that has both landed and carries formations
		var since: float = g._world.elapsed - g._world.wave_started
		var phase := ""
		for ech in ["vanguard", "main", "sting"]:
			if not Array(g._world.wave_lines.get(ech, [])).is_empty() \
					and since >= float(g._world.wave_ech_rel.get(ech, 1e12)):
				phase = { "vanguard": "VANGUARD", "main": "MAIN BODY", "sting": "STING" }[ech]
		var head := "WAVE %d" % g._world.wave + (" · " + phase if phase != "" else "")
		if g._world.wx_state != "clear":   # C17: the front reads on the plate, newsreel-terse
			head += " · " + { "rain": "RAIN", "squall": "SQUALL", "thunder": "THUNDERHEAD" }[g._world.wx_state]
		line = "%s · %s" % [head, " · ".join(bits)] if not bits.is_empty() \
			else "%s · CONTACTS: 0" % head
	elif g._world.wave == 0:
		line = "CONTACTS INBOUND — %d" % maxi(0, ceili(g._world.lull_until - g._world.elapsed))
	else:
		line = "WAVE %d CLEARED — NEXT IN 0:%02d" % [g._world.wave, maxi(0, ceili(g._world.lull_until - g._world.elapsed))]
	g.draw_string(g._mono, Vector2(x, origin.y + 50.0), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, HelmGauges.FOAM)
	g.draw_string(g._mono, Vector2(x, origin.y + 72.0), "DRONES DESTROYED: %d" % g._world.kills,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, HelmGauges.BRASS)
	g.draw_string(g._mono, Vector2(x, origin.y + 90.0), "XP +%d" % g._world.xp_run,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, HelmGauges.BRASS)

# ── PRIORITY TARGET plate (C7): top center — THE-name, core bar, part pips that strike through ──
static func draw_boss(g: HelmGauges) -> void:
	if g._world.boss == null:
		g._boss_seen_ms = -1
		return
	if g._boss_seen_ms < 0:
		g._boss_seen_ms = Time.get_ticks_msec()
	var def: BossDef = Bosses.def_of(g._world, g._cfgs)
	var b: Boss = g._world.boss
	var pw := 440.0
	var ph := 76.0
	var origin := Vector2((g.size.x - pw) * 0.5, 12.0)
	var pts := PackedVector2Array([
		origin + Vector2(12, 0), origin + Vector2(pw, 0), origin + Vector2(pw, ph - 12),
		origin + Vector2(pw - 12, ph), origin + Vector2(0, ph), origin + Vector2(0, 12),
	])
	g.draw_colored_polygon(pts, Color(0.078, 0.039, 0.031, 0.88))
	var closed := PackedVector2Array(pts); closed.append(pts[0])
	g.draw_polyline(closed, HelmGauges.RED, 1.2, true)
	var cx := origin.x + pw * 0.5
	g._centered_spaced(cx, origin.y + 14.0, "PRIORITY TARGET", 8, Color(HelmGauges.RED.r, HelmGauges.RED.g, HelmGauges.RED.b, 0.9), 3.5)
	# the name flashes for its first beats in theater (the klaxon moment)
	var fresh: bool = Time.get_ticks_msec() - g._boss_seen_ms < 2400
	var flick: bool = fresh and (Time.get_ticks_msec() / 250) % 2 == 0
	var nm: String = def.display_name + ("  ·  LAP %d" % b.lap if b.lap > 1 else "")
	g.draw_string(g._mono, Vector2(cx - g._mono.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x * 0.5, origin.y + 34.0),
		nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, HelmGauges.RED if flick else HelmGauges.FOAM)
	var bar := Rect2(origin.x + 18.0, origin.y + 42.0, pw - 36.0, 8.0)
	g.draw_rect(bar, Color(HelmGauges.FOAM.r, HelmGauges.FOAM.g, HelmGauges.FOAM.b, 0.06))
	g.draw_rect(bar, Color(HelmGauges.RED.r, HelmGauges.RED.g, HelmGauges.RED.b, 0.6), false, 1.0)
	g.draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(b.core / b.core_max, 0.0, 1.0), bar.size.y)), HelmGauges.RED)
	# part pips
	var total_w := 0.0
	var widths: Array[float] = []
	for pd in def.parts:
		var w: float = g._sans.get_string_size(pd["pn"], HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 14.0
		widths.append(w)
		total_w += w + 6.0
	var px := cx - (total_w - 6.0) * 0.5
	for i in range(def.parts.size()):
		var dead: bool = b.parts[i]["dead"]
		var r := Rect2(px, origin.y + 56.0, widths[i], 13.0)
		g.draw_rect(r, Color(HelmGauges.BRASS_DIM.r, HelmGauges.BRASS_DIM.g, HelmGauges.BRASS_DIM.b, 0.3 if dead else 0.5), false, 1.0)
		var col := Color(HelmGauges.BRASS_DIM.r, HelmGauges.BRASS_DIM.g, HelmGauges.BRASS_DIM.b, 0.55) if dead else HelmGauges.BRASS
		g.draw_string(g._sans, Vector2(r.position.x + 7.0, r.position.y + 10.0), def.parts[i]["pn"],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)
		if dead:   # struck through
			g.draw_line(Vector2(r.position.x + 4.0, r.get_center().y), Vector2(r.end.x - 4.0, r.get_center().y),
				Color(HelmGauges.RED.r, HelmGauges.RED.g, HelmGauges.RED.b, 0.7), 1.0)
		px += widths[i] + 6.0
