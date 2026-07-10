class_name RadarScope
extends RefCounted
# The bottom-right radar scope — range rings, land masses, weapon/sonar rings, view box, sweep,
# fire-control bearing, and every blip (air/surface/sonar-gated subs, own salvo, torpedo runs, the
# boss, the helo). Static draw funcs called by HelmGauges._draw; all state lives on the host (the
# C9 render-domain split pattern). draw reads/prunes g._shot_flashes; _micro_label/_dashed_arc are
# radar-only helpers.

# ── radar scope (bottom-right; C3 gate revisions 1–2 + C5 sonar). Air/surface contacts are free;
#    sub blips are sonar-gated diamonds (D1.10) inside the soft sonar ring — your only ears. ──
static func draw(g: HelmGauges) -> void:
	var c := Vector2(g.size.x - HelmGauges.RADAR_R - 26.0, g.size.y - HelmGauges.RADAR_R - 26.0)
	var rng_u: float = g._cfgs.waves.radar_range
	var k: float = HelmGauges.RADAR_R / rng_u
	g.draw_circle(c, HelmGauges.RADAR_R, Color(0.051, 0.125, 0.157, 0.9))
	g.draw_arc(c, HelmGauges.RADAR_R, 0.0, TAU, 64, HelmGauges.PLATE_EDGE, 1.0, true)
	# play-test tune: 500u rings made the center ring soup — 1000u marks only, fainter
	var d := 1000.0
	while d < rng_u:
		g.draw_arc(c, d * k, 0.0, TAU, 48, Color(HelmGauges.BRASS.r, HelmGauges.BRASS.g, HelmGauges.BRASS.b, 0.12), 1.0, true)
		d += 1000.0
	# C15 — the land on the scope: dim solid brass-gray masses UNDER all blips, unmistakably
	# not contacts (blips are red, shot is foam). Bodies only, no shoal. Control._draw has no
	# shape clip, so the clip is cheap: features fully past the rim are skipped, and crossing
	# coastlines have each point clamped to the scope radius (land flattens against the rim).
	# Tiny reefs get a 1.5 px dot floor so a reef line still charts. Coast shapes come from
	# TerrainRender.verts_local — the chart and the world agree on every coastline.
	var terr: Variant = g._world.get("terrain")   # .get() guard: no-ops on worlds predating world.terrain
	if terr is Array:
		var land := Color(0.588, 0.541, 0.416, 0.4)
		for ti in range(terr.size()):
			var tf: Dictionary = terr[ti]
			var t_off: Vector2 = (tf["pos"] - g._world.ship_pos) * k
			var tr_px: float = tf["r"] * k
			if t_off.length() - tr_px > HelmGauges.RADAR_R:
				continue
			if tr_px < 2.0:   # the dot floor
				g.draw_circle(c + t_off.limit_length(HelmGauges.RADAR_R), maxf(tr_px, 1.5), land)
			else:
				var traw: PackedVector2Array = TerrainRender.verts_local(g._world.world_seed, ti, tf["r"])
				var tpts := PackedVector2Array()
				for tp in traw:
					tpts.append(c + (t_off + tp * k).limit_length(HelmGauges.RADAR_R))
				g.draw_colored_polygon(tpts, land)
	var mb := g._cfgs.weapons.by_id("mb16")
	if mb != null:   # main-battery reach, dashed + named (play-test: nothing was named)
		RadarScope._dashed_arc(g, c, mb.range_u * k, Color(HelmGauges.BRASS.r, HelmGauges.BRASS.g, HelmGauges.BRASS.b, 0.35))
		RadarScope._micro_label(g, Vector2(c.x, c.y - mb.range_u * k - 3.0), "16-IN", 0)
	# C5: the sonar radius — a soft filled ring, the only part of the scope that hears the deep
	g.draw_circle(c, g._cfgs.sonar.radius * k, Color(HelmGauges.FOAM.r, HelmGauges.FOAM.g, HelmGauges.FOAM.b, 0.045))
	g.draw_arc(c, g._cfgs.sonar.radius * k, 0.0, TAU, 48, Color(HelmGauges.FOAM.r, HelmGauges.FOAM.g, HelmGauges.FOAM.b, 0.28), 1.0, true)
	RadarScope._micro_label(g, Vector2(c.x + g._cfgs.sonar.radius * k + 4.0, c.y + 3.0), "SONAR", 1)
	# C12: the depth-charge arm range — DASHED foam, unmistakably a weapon ring, not ears
	RadarScope._dashed_arc(g, c, g._cfgs.sonar.dc_range * k, Color(HelmGauges.FOAM.r, HelmGauges.FOAM.g, HelmGauges.FOAM.b, 0.6))
	RadarScope._micro_label(g, Vector2(c.x - g._cfgs.sonar.dc_range * k - 4.0, c.y + 3.0), "DC", -1)
	# viewport extent
	var view: Vector2 = g.get_viewport_rect().size
	var cam := g.get_viewport().get_camera_2d()
	var zoom: float = cam.zoom.x if cam != null else 1.0
	var vw: float = view.x * 0.5 / zoom * k
	var vh: float = view.y * 0.5 / zoom * k
	g.draw_rect(Rect2(c.x - vw, c.y - vh, vw * 2.0, vh * 2.0), Color(HelmGauges.FOAM.r, HelmGauges.FOAM.g, HelmGauges.FOAM.b, 0.14), false, 1.0)
	RadarScope._micro_label(g, Vector2(c.x - vw + 3.0, c.y - vh - 2.0), "VIEW", 1)
	# sweep (cosmetic)
	var sw: float = fmod(Time.get_ticks_msec() * 0.0016, TAU)
	g.draw_line(c, c + Vector2(sin(sw), -cos(sw)) * HelmGauges.RADAR_R, Color(HelmGauges.BRASS.r, HelmGauges.BRASS.g, HelmGauges.BRASS.b, 0.3), 1.0)
	# fire-control bearing while an order is held (gate rev 2)
	if g._order_label() != "" and not g._world.run_over:
		var ba: float = atan2(g._world.input.aim_world.x - g._world.ship_pos.x, -(g._world.input.aim_world.y - g._world.ship_pos.y))
		var bd := Vector2(sin(ba), -cos(ba))
		var mb_r: float = (mb.range_u if mb != null else 900.0) * k
		g.draw_line(c, c + bd * mb_r, Color(HelmGauges.RED.r, HelmGauges.RED.g, HelmGauges.RED.b, 0.7), 1.4)
		g.draw_line(c + bd * mb_r, c + bd * HelmGauges.RADAR_R, Color(HelmGauges.RED.r, HelmGauges.RED.g, HelmGauges.RED.b, 0.3), 1.4)
		g.draw_arc(c + bd * mb_r, 2.6, 0.0, TAU, 12, Color(HelmGauges.RED.r, HelmGauges.RED.g, HelmGauges.RED.b, 0.9), 1.0, true)
	# blips (clipped by range check)
	for e in g._world.enemies:
		if not e.active:
			continue
		var off: Vector2 = (e.pos - g._world.ship_pos) * k
		if off.length() > HelmGauges.RADAR_R:
			continue
		var b := c + off
		if e.layer == "sub":   # detected subs only, as a foam diamond (D1.10 radar gating)
			if not Sonar.detected(g._world, e):
				continue
			g.draw_colored_polygon(PackedVector2Array([
				b + Vector2(0, -4), b + Vector2(4, 0), b + Vector2(0, 4), b + Vector2(-4, 0),
			]), Color(HelmGauges.FOAM.r, HelmGauges.FOAM.g, HelmGauges.FOAM.b, 0.95))
		elif e.type_id == "gunboat":
			g.draw_rect(Rect2(b.x - 2.8, b.y - 2.8, 5.6, 5.6), HelmGauges.RED)
		else:
			g.draw_circle(b, 3.6 if e.type_id == "bomber" else 2.4, HelmGauges.RED if e.type_id == "bomber" else HelmGauges.ORANGE)
	for i in range(g._world.projectiles.items.size()):
		var p: Projectile = g._world.projectiles.items[i]
		if not p.active:
			continue
		var off: Vector2 = (p.pos - g._world.ship_pos) * k
		if off.length() > HelmGauges.RADAR_R:
			continue
		if p.hostile:
			if p.wid == "torpedo":
				# C12: the C5-promised tell, finally paid — a bright foam dash laid along the run
				# plus two wake sparks fading astern (mockup panel 1). Jitter is cosmetic-clock only.
				var tb := c + off
				var dv: Vector2 = p.vel.normalized() if p.vel.length_squared() > 0.001 else Vector2.UP
				var perp := Vector2(-dv.y, dv.x)
				g.draw_line(tb - dv * 3.5, tb + dv * 3.5, Color(HelmGauges.FOAM.r, HelmGauges.FOAM.g, HelmGauges.FOAM.b, 0.95), 2.0)
				var jbase: int = Time.get_ticks_msec() / 66 + i * 31
				for si in range(2):
					var j: float = (float((jbase + si * 17) % 7) / 3.0 - 1.0) * 1.2
					var sp: Vector2 = tb - dv * (5.0 + 4.5 * float(si + 1)) + perp * j
					g.draw_rect(Rect2(sp.x - 0.7, sp.y - 0.7, 1.4, 1.4),
						Color(HelmGauges.FOAM.r, HelmGauges.FOAM.g, HelmGauges.FOAM.b, 0.65 if si == 0 else 0.4))
			else:
				g.draw_rect(Rect2(c.x + off.x - 0.8, c.y + off.y - 0.8, 1.6, 1.6), Color(HelmGauges.ORANGE.r, HelmGauges.ORANGE.g, HelmGauges.ORANGE.b, 0.8))
		elif p.wid == "mb16":   # C11 fall-of-shot: your own salvo exists on the scope
			g.draw_rect(Rect2(c.x + off.x - 0.8, c.y + off.y - 0.8, 1.6, 1.6), Color(HelmGauges.FOAM.r, HelmGauges.FOAM.g, HelmGauges.FOAM.b, 0.85))
	# C11: burst flashes — each main-battery splash blooms briefly where it landed
	var fnow: int = Time.get_ticks_msec()
	var fi: int = g._shot_flashes.size() - 1
	while fi >= 0:
		var fl: Dictionary = g._shot_flashes[fi]
		var age: float = (fnow - fl["t0"]) / 1000.0
		if age >= HelmGauges.FLASH_LIFE:
			g._shot_flashes.remove_at(fi)
			fi -= 1
			continue
		var foff: Vector2 = (Vector2(fl["pos"]) - g._world.ship_pos) * k
		if foff.length() <= HelmGauges.RADAR_R:
			var fk: float = age / HelmGauges.FLASH_LIFE
			g.draw_arc(c + foff, 1.5 + 5.0 * fk, 0.0, TAU, 16,
				Color(HelmGauges.FOAM.r, HelmGauges.FOAM.g, HelmGauges.FOAM.b, 0.9 * (1.0 - fk)), 1.2, true)
		fi -= 1
	# C7: the machine on the scope — oversized blip, sonar-gated while it stalks under
	if g._world.boss != null:
		var boff: Vector2 = (g._world.boss.pos - g._world.ship_pos) * k
		if boff.length() <= HelmGauges.RADAR_R:
			var bb := c + boff
			var under: bool = Bosses.domain_of(g._world, g._cfgs) == "sub"
			if not under:
				g.draw_rect(Rect2(bb.x - 5, bb.y - 5, 10, 10), HelmGauges.RED, false, 2.0)
				g.draw_rect(Rect2(bb.x - 2.5, bb.y - 2.5, 5, 5), Color(HelmGauges.RED.r, HelmGauges.RED.g, HelmGauges.RED.b, 0.5))
			elif g._world.elapsed < g._world.boss.detected_until:
				var dia := PackedVector2Array([
					bb + Vector2(0, -7), bb + Vector2(7, 0), bb + Vector2(0, 7), bb + Vector2(-7, 0), bb + Vector2(0, -7),
				])
				g.draw_polyline(dia, Color(HelmGauges.FOAM.r, HelmGauges.FOAM.g, HelmGauges.FOAM.b, 0.95), 1.6, true)
	# C6: the bird on the scope — a friendly cross + its dip ring while airborne
	if g._cfgs.tech.helo and g._world.helo_state != "pad":
		var hoff: Vector2 = (g._world.helo_pos - g._world.ship_pos) * k
		if hoff.length() <= HelmGauges.RADAR_R:
			var hb := c + hoff
			g.draw_arc(hb, g._cfgs.airwing.dip_radius * k, 0.0, TAU, 24, Color(HelmGauges.FOAM.r, HelmGauges.FOAM.g, HelmGauges.FOAM.b, 0.20), 1.0, true)
			g.draw_line(hb + Vector2(-3, 0), hb + Vector2(3, 0), Color(HelmGauges.FOAM.r, HelmGauges.FOAM.g, HelmGauges.FOAM.b, 0.9), 1.2)
			g.draw_line(hb + Vector2(0, -3), hb + Vector2(0, 3), Color(HelmGauges.FOAM.r, HelmGauges.FOAM.g, HelmGauges.FOAM.b, 0.9), 1.2)
	# own ship + heading tick
	var f := Vector2(sin(g._world.ship_heading), -cos(g._world.ship_heading))
	g.draw_line(c - f * 4.0, c + f * 7.0, HelmGauges.FOAM, 1.6)
	g.draw_circle(c, 2.0, HelmGauges.FOAM)
	# (play-test tune: the C12 rack dial looked like a contact floating in the water —
	#  the rack state moved to the gauge plate's batteries line, where instruments live)
	g._label(c.x - 26.0, c.y - HelmGauges.RADAR_R - 8.0, "RADAR")

# tiny on-scope ring name (play-test tune: nothing on the scope was named).
# align: -1 = text ends at pos, 0 = centered on pos, 1 = text starts at pos.
static func _micro_label(g: HelmGauges, pos: Vector2, text: String, align: int) -> void:
	var w: float = g._mono.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var x: float = pos.x - (w if align < 0 else (w * 0.5 if align == 0 else 0.0))
	g.draw_string(g._mono, Vector2(x, pos.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8,
		Color(HelmGauges.BRASS_DIM.r, HelmGauges.BRASS_DIM.g, HelmGauges.BRASS_DIM.b, 0.75))

static func _dashed_arc(g: HelmGauges, c: Vector2, r: float, col: Color) -> void:
	var segs := 36
	for i in range(segs):
		if i % 2 == 0:
			g.draw_arc(c, r, TAU * i / segs, TAU * (i + 1) / segs, 4, col, 1.0, true)
