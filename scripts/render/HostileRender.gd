class_name HostileRender
extends RefCounted
# Hostile art — enemy roster, sub tells, war machines. C3/C5/C7 language verbatim, plus the C9
# depth cues in the shipped shadow language (the canopy/helo slide-off shadow): AIR enemies cast
# small offset shadows, surface gunboats bob and rock on the same analytic swell as the ship.
# Render-only; sonar-gated sub visibility reads sim state one-way (D1.10).

const SHADOW_COL := Color(0.016, 0.047, 0.063, 0.35)

static func draw_enemies(r: FieldRenderer) -> void:
	var now: float = Time.get_ticks_msec() * 1.0
	var cfg: FieldConfig = r._field_cfg
	for e in r._world.enemies:
		if not e.active:
			continue
		if e.layer == "sub":
			draw_sub(r, e, now)
			continue
		var draw_pos: Vector2 = e.pos
		var rock: float = 0.0
		# C10 minimum-apparent-size floor: the smallest hostiles stay targetable at the zoom floor
		var boost: float = r.size_floor(14.0 if e.type_id == "swarmer" else (28.0 if e.type_id == "gunboat" else 30.0))
		if e.layer == "air":
			# the shadow slips off the airframe — same language as the canopy/bird (C9)
			var soff := Vector2(6, 8) if e.type_id == "swarmer" else Vector2(9, 12)
			var srad: float = 5.0 if e.type_id == "swarmer" else 9.0
			r.draw_set_transform(e.pos + soff, 0.0, Vector2(1.0, 0.55))
			r.draw_circle(Vector2.ZERO, srad, SHADOW_COL)
		elif not cfg.reduced_motion:
			# surface craft ride the same swell as the ship, scaled down (C9)
			var bob: float = SeaRender.swell_h(cfg, e.pos.x, e.pos.y, r.sea_t) * cfg.heave_px * 0.8
			draw_pos = e.pos + FieldRenderer.SUN_DIR * bob
			rock = sin(r.sea_t * 0.9 + e.pos.x * 0.01) * 0.05 * cfg.roll_deg
		r.draw_set_transform(draw_pos, e.heading + rock, Vector2.ONE * boost)
		if e.type_id == "swarmer":
			r.draw_colored_polygon(PackedVector2Array([Vector2(0, -8), Vector2(6, 6), Vector2(0, 3), Vector2(-6, 6)]),
				Color(0.851, 0.310, 0.169, 0.95))
			r.draw_circle(Vector2(0, -1), 1.4, FieldRenderer.FOAM)
		elif e.type_id == "gunboat":
			var boat := PackedVector2Array([Vector2(0, -16), Vector2(8, -6), Vector2(8, 12), Vector2(-8, 12), Vector2(-8, -6)])
			r.draw_colored_polygon(boat, Color(0.118, 0.180, 0.212))
			var bc := PackedVector2Array(boat); bc.append(boat[0])
			r.draw_polyline(bc, Color(0.851, 0.310, 0.169, 0.8), r.lw(1.2), true)
			r.draw_rect(Rect2(-1.5, -10, 3, 8), FieldRenderer.RED)
		else:   # bomber
			var wing := PackedVector2Array([Vector2(0, -14), Vector2(16, 10), Vector2(0, 4), Vector2(-16, 10)])
			r.draw_colored_polygon(wing, Color(0.588, 0.176, 0.098, 0.95))
			var wc := PackedVector2Array(wing); wc.append(wing[0])
			r.draw_polyline(wc, Color(0.851, 0.310, 0.169, 0.9), r.lw(1.2), true)
			r.draw_circle(Vector2(-6, 6), 1.6, FieldRenderer.FLASH)
			r.draw_circle(Vector2(6, 6), 1.6, FieldRenderer.FLASH)
		if e.burn_left > 0:   # INCENDIARY (C4): flame flicker on burning drones
			r.draw_circle(Vector2.ZERO, 4.0 + sin(now * 0.05) * 1.5,
				Color(FieldRenderer.FLASH.r, FieldRenderer.FLASH.g, FieldRenderer.FLASH.b, 0.6 + 0.4 * sin(now * 0.03)))
		r.draw_set_transform(e.pos, 0.0, Vector2.ONE)
		if e.hp < e.hp_max and e.hp_max > 2:   # hp pips under damaged toughs
			for i in range(e.hp):
				r.draw_rect(Rect2(-10 + i * 4, 16, 2.6, 2.2),
					Color(FieldRenderer.FOAM.r, FieldRenderer.FOAM.g, FieldRenderer.FOAM.b, 0.7))
		r.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func draw_sub(r: FieldRenderer, e: Enemy, now: float) -> void:
	if Sonar.detected(r._world, e):
		# silhouette: dark 7×20 ellipse under red-tinted water, conning-tower dot
		r.draw_set_transform(e.pos, e.heading, Vector2(0.35, 1.0))
		r.draw_circle(Vector2.ZERO, 20.0, Color(0.094, 0.165, 0.212, 0.85))
		r.draw_set_transform(e.pos, e.heading, Vector2.ONE)
		draw_ellipse_outline(r, 7.0, 20.0, Color(FieldRenderer.RED.r, FieldRenderer.RED.g, FieldRenderer.RED.b, 0.55), r.lw(1.2))
		r.draw_circle(Vector2(0, -4), 2.4, Color(FieldRenderer.FOAM.r, FieldRenderer.FOAM.g, FieldRenderer.FOAM.b, 0.5))
		r.draw_set_transform(e.pos, 0.0, Vector2.ONE)
		r.draw_arc(Vector2.ZERO, 24.0 + sin(now * 0.004) * 2.0, 0.0, TAU, 32,
			Color(FieldRenderer.FOAM.r, FieldRenderer.FOAM.g, FieldRenderer.FOAM.b, 0.25), r.lw(1.0), true)   # foam ring over the contact
	elif e.pos.distance_to(r._world.ship_pos) <= r._cfgs.sonar.ripple_range:
		# the water moves wrong: two faint counter-wobbling rings, no shape underneath
		var wob: float = sin(now * 0.003 + e.pos.x) * 3.0
		r.draw_set_transform(e.pos, 0.0, Vector2.ONE)
		r.draw_arc(Vector2.ZERO, 14.0 + wob, 0.0, TAU, 28,
			Color(FieldRenderer.FOAM.r, FieldRenderer.FOAM.g, FieldRenderer.FOAM.b, 0.07), r.lw(1.5), true)
		r.draw_arc(Vector2.ZERO, 24.0 - wob, 0.0, TAU, 32,
			Color(FieldRenderer.FOAM.r, FieldRenderer.FOAM.g, FieldRenderer.FOAM.b, 0.045), r.lw(1.5), true)
	r.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func draw_ellipse_outline(r: FieldRenderer, rx: float, ry: float, col: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for i in range(33):
		var a: float = TAU * i / 32.0
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	r.draw_polyline(pts, col, width, true)

# C7: the war machines — three multi-part silhouettes per the approved mockup. Parts render at
# hull-relative offsets and char out when dead; the MAW shows only a monstrous ripple field while
# submerged (silhouette sonar-gated, D1.10), then a venting hull while breached.
static func draw_boss(r: FieldRenderer) -> void:
	var b: Boss = r._world.boss
	if b == null:
		return
	var def: BossDef = r._cfgs.bosses.defs[b.rung]
	var now: float = Time.get_ticks_msec() * 1.0
	if def.id == "maw" and b.submerged:
		var wob: float = sin(now * 0.002) * 6.0
		r.draw_arc(b.pos, 40.0 + wob, 0.0, TAU, 40, Color(FieldRenderer.FOAM.r, FieldRenderer.FOAM.g, FieldRenderer.FOAM.b, 0.10), 2.0, true)
		r.draw_arc(b.pos, 62.0 - wob, 0.0, TAU, 48, Color(FieldRenderer.FOAM.r, FieldRenderer.FOAM.g, FieldRenderer.FOAM.b, 0.06), 2.0, true)
		r.draw_arc(b.pos, 84.0 + wob * 0.6, 0.0, TAU, 48, Color(FieldRenderer.FOAM.r, FieldRenderer.FOAM.g, FieldRenderer.FOAM.b, 0.06), 2.0, true)
		if r._world.elapsed < b.detected_until:
			r.draw_set_transform(b.pos, b.heading, Vector2(0.42, 1.0))
			r.draw_circle(Vector2.ZERO, 52.0, Color(0.071, 0.125, 0.165, 0.8))
			r.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	if def.id == "canopy":   # airborne: the shadow slides off the airframe
		r.draw_set_transform(b.pos + Vector2(16, 22), 0.0, Vector2(1.0, 0.53))
		r.draw_circle(Vector2.ZERO, 34.0, SHADOW_COL)
		r.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	r.draw_set_transform(b.pos, b.heading, Vector2.ONE)
	if def.id == "juggernaut":
		var hull := PackedVector2Array([
			Vector2(0, -56), Vector2(16, -34), Vector2(18, 30), Vector2(10, 52),
			Vector2(-10, 52), Vector2(-18, 30), Vector2(-16, -34),
		])
		r.draw_colored_polygon(hull, Color(0.075, 0.122, 0.153))
		var hc := PackedVector2Array(hull); hc.append(hull[0])
		r.draw_polyline(hc, Color(FieldRenderer.RED.r, FieldRenderer.RED.g, FieldRenderer.RED.b, 0.85), 1.6, true)
		r.draw_rect(Rect2(-10, -18, 20, 34), Color(0.133, 0.2, 0.243))   # citadel block
	elif def.id == "canopy":
		var wing := PackedVector2Array([
			Vector2(0, -44), Vector2(40, 6), Vector2(26, 30), Vector2(-26, 30), Vector2(-40, 6),
		])
		r.draw_colored_polygon(wing, Color(0.471, 0.125, 0.071, 0.92))
		var wc := PackedVector2Array(wing); wc.append(wing[0])
		r.draw_polyline(wc, Color(FieldRenderer.RED.r, FieldRenderer.RED.g, FieldRenderer.RED.b, 0.9), 1.8, true)
		for ex in [-18.0, 0.0, 18.0]:
			r.draw_circle(Vector2(ex, 24), 2.6,
				Color(FieldRenderer.FLASH.r, FieldRenderer.FLASH.g, FieldRenderer.FLASH.b, 0.5 + 0.4 * sin(now * 0.01 + ex)))
	else:   # the MAW, breached: a monster venting on the surface
		r.draw_set_transform(b.pos, b.heading, Vector2(0.464, 1.0))
		r.draw_circle(Vector2.ZERO, 56.0, Color(0.086, 0.149, 0.184))
		r.draw_set_transform(b.pos, b.heading, Vector2.ONE)
		draw_ellipse_outline(r, 26.0, 56.0, Color(FieldRenderer.RED.r, FieldRenderer.RED.g, FieldRenderer.RED.b, 0.9), 2.0)
		for fy in [-38.0, -10.0, 20.0]:   # dorsal ridge fins
			r.draw_colored_polygon(PackedVector2Array([Vector2(-4, fy), Vector2(0, fy - 8), Vector2(4, fy)]),
				Color(FieldRenderer.RED.r, FieldRenderer.RED.g, FieldRenderer.RED.b, 0.5))
		r.draw_set_transform(b.pos, 0.0, Vector2.ONE)
		r.draw_arc(Vector2.ZERO, 66.0 + sin(now * 0.004) * 4.0, 0.0, TAU, 48,
			Color(FieldRenderer.FOAM.r, FieldRenderer.FOAM.g, FieldRenderer.FOAM.b, 0.25), 1.5, true)   # world-aligned churn ring
		r.draw_set_transform(b.pos, b.heading, Vector2.ONE)
	# parts
	for i in range(def.parts.size()):
		var pd: Dictionary = def.parts[i]
		var part: Dictionary = b.parts[i]
		var off := Vector2(pd["ox"], pd["oy"])
		if part["dead"]:
			r.draw_circle(off, pd["r"] * 0.85, Color(0.039, 0.063, 0.078, 0.9))
			r.draw_line(off + Vector2(-pd["r"] * 0.6, -pd["r"] * 0.6), off + Vector2(pd["r"] * 0.6, pd["r"] * 0.6),
				Color(0.557, 0.506, 0.373, 0.4), 1.0)
			r.draw_line(off + Vector2(pd["r"] * 0.6, -pd["r"] * 0.6), off + Vector2(-pd["r"] * 0.6, pd["r"] * 0.6),
				Color(0.557, 0.506, 0.373, 0.4), 1.0)
			var sm: float = fmod(now * 0.001 + i, 1.0)   # smoke wisp
			r.draw_circle(off + Vector2(sm * 6.0, -sm * 14.0), 3.0 + sm * 5.0, Color(0.157, 0.196, 0.22, 0.5 * (1.0 - sm)))
		else:
			var hurt: float = part["hp"] / part["max"]
			r.draw_circle(off, pd["r"], Color(0.588, 0.176, 0.098, 0.95) if def.id == "canopy" else Color(0.173, 0.251, 0.282))
			r.draw_arc(off, pd["r"], 0.0, TAU, 20,
				Color(FieldRenderer.RED.r, FieldRenderer.RED.g, FieldRenderer.RED.b, 0.4 + 0.5 * (1.0 - hurt)), 1.5, true)
			match String(pd["role"]):
				"gun":
					r.draw_rect(Rect2(off.x - 1.6, off.y - pd["r"] - 10.0, 3.2, 12.0), FieldRenderer.STEEL)
				"director":
					r.draw_rect(Rect2(off.x - 1.0, off.y - 6.0, 2.0, 12.0), FieldRenderer.STEEL)
					r.draw_rect(Rect2(off.x - 6.0, off.y - 1.0, 12.0, 2.0), FieldRenderer.STEEL)
				"hive":
					r.draw_circle(off, pd["r"] * 0.45,
						Color(FieldRenderer.FLASH.r, FieldRenderer.FLASH.g, FieldRenderer.FLASH.b, 0.4 + 0.3 * sin(now * 0.008)))
				"vent":
					r.draw_circle(off, pd["r"] * 0.4 + sin(now * 0.006 + i) * 1.2,
						Color(FieldRenderer.FOAM.r, FieldRenderer.FOAM.g, FieldRenderer.FOAM.b, 0.35))
	r.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
