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
	for i in range(r._world.enemies.size()):
		var e: Enemy = r._world.enemies[i]
		if not e.active:
			continue
		if e.layer == "sub":
			draw_sub(r, e, now)
			continue
		var draw_pos: Vector2 = e.pos
		var rock: float = 0.0
		# C10 minimum-apparent-size floor: the smallest hostiles stay targetable at the zoom floor
		var boost: float = r.size_floor(14.0 if e.type_id == "swarmer" else (12.0 if e.type_id == "wasp" else (28.0 if e.type_id == "gunboat" else 30.0)))
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
		# C12 wounded tells: toughs below half hp read as wounded (render-only, hp/hp_max one-way)
		var wounded: bool = e.hp_max > 2 and e.hp * 2 <= e.hp_max
		if wounded and e.layer != "air":
			# a wounded LIST — a constant ~7° heel on top of the rock; side picked deterministically
			# per roster slot (array order is stable within a wave) — never the sim's rng
			rock += (1.0 if i % 2 == 0 else -1.0) * deg_to_rad(7.0)
		r.draw_set_transform(draw_pos, e.heading + rock, Vector2.ONE * boost)
		if e.type_id == "swarmer":   # AIR THREAT: GNAT — a suicide drone, a slim delta with a live seeker
			r.draw_colored_polygon(PackedVector2Array([Vector2(0, -8), Vector2(5.5, 6), Vector2(0, 2.5), Vector2(-5.5, 6)]),
				Color(0.851, 0.310, 0.169, 0.95))
			# a hot seeker core in the belly — pulses on the render clock, holds still under reduced motion
			var glow: float = 1.9 if cfg.reduced_motion else 1.6 + 0.5 * sin(now * 0.012)
			r.draw_circle(Vector2(0, -1), glow, Color(FieldRenderer.FLASH.r, FieldRenderer.FLASH.g, FieldRenderer.FLASH.b, 0.5))
			r.draw_circle(Vector2(0, -1), 1.0, FieldRenderer.FOAM)   # sensor dot
		elif e.type_id == "wasp":   # AIR THREAT: WASP — the rocket plane, a slim dart on swept wings
			r.draw_colored_polygon(PackedVector2Array([Vector2(0, -11), Vector2(2.2, 2), Vector2(5.5, 7), Vector2(0, 4.5), Vector2(-5.5, 7), Vector2(-2.2, 2)]),
				Color(0.851, 0.310, 0.169, 0.95))
			for wx in [-5.0, 5.0]:   # underwing rocket rails, each slung with a red warhead
				r.draw_rect(Rect2(wx - 0.8, -1.0, 1.6, 6.0), FieldRenderer.STEEL)
				r.draw_circle(Vector2(wx, -1.5), 1.1, Color(FieldRenderer.RED.r, FieldRenderer.RED.g, FieldRenderer.RED.b, 0.9))
			r.draw_circle(Vector2(0, -3), 1.2, FieldRenderer.FOAM)   # canopy glint
		elif e.type_id == "gunboat":   # SURFACE THREAT: JACKAL — an improvised fast-attack craft
			# a hard-chine planing hull — fine pointed bow, full midships, a transom stern
			var boat := PackedVector2Array([
				Vector2(0, -16), Vector2(3.5, -11), Vector2(7, -3), Vector2(8, 4),
				Vector2(6.5, 11), Vector2(6, 12), Vector2(-6, 12), Vector2(-6.5, 11),
				Vector2(-8, 4), Vector2(-7, -3), Vector2(-3.5, -11),
			])
			var hull_col := Color(0.118, 0.180, 0.212)
			var sup_col := Color(0.176, 0.247, 0.286)   # low wheelhouse — reads lighter than the hull
			if wounded:
				hull_col = hull_col.darkened(0.25)   # wounded hull chars toward black (C12)
				sup_col = sup_col.darkened(0.25)
			# bow spray — it runs fast and low, throwing a foam mustache off the stem (drawn under the
			# hull so the stem overlaps its root, same language as the ship's bow wave)
			r.draw_colored_polygon(PackedVector2Array([Vector2(1.5, -13.5), Vector2(7.5, -6.5), Vector2(2.5, -10.0)]),
				Color(FieldRenderer.FOAM.r, FieldRenderer.FOAM.g, FieldRenderer.FOAM.b, 0.4))
			r.draw_colored_polygon(PackedVector2Array([Vector2(-1.5, -13.5), Vector2(-7.5, -6.5), Vector2(-2.5, -10.0)]),
				Color(FieldRenderer.FOAM.r, FieldRenderer.FOAM.g, FieldRenderer.FOAM.b, 0.4))
			r.draw_colored_polygon(boat, hull_col)
			var bc := PackedVector2Array(boat); bc.append(boat[0])
			r.draw_polyline(bc, Color(0.851, 0.310, 0.169, 0.8), r.lw(1.2), true)   # signal-red edge accent
			# jury-rigged rocket rail welded to the starboard rail — asymmetric on purpose
			r.draw_rect(Rect2(5.2, 0.5, 2.4, 7.0), Color(0.129, 0.184, 0.216))
			r.draw_circle(Vector2(6.4, 1.6), 0.9, FieldRenderer.RED)   # rocket tips
			r.draw_circle(Vector2(6.4, 4.2), 0.9, FieldRenderer.RED)
			# low wheelhouse / superstructure aft of amidships, with a lit windscreen strip
			r.draw_rect(Rect2(-3.5, 1.5, 7.0, 6.5), sup_col)
			r.draw_rect(Rect2(-3.5, 1.5, 7.0, 1.6), Color(FieldRenderer.STEEL.r, FieldRenderer.STEEL.g, FieldRenderer.STEEL.b, 0.4))
			# the deck gun — a real little turret + barrel trained forward on the foredeck
			r.draw_circle(Vector2(0, -3.5), 2.6, Color(0.098, 0.149, 0.180))
			r.draw_arc(Vector2(0, -3.5), 2.6, 0.0, TAU, 16, Color(FieldRenderer.RED.r, FieldRenderer.RED.g, FieldRenderer.RED.b, 0.75), r.lw(1.0), true)
			r.draw_rect(Rect2(-0.8, -13.0, 1.6, 9.5), FieldRenderer.STEEL)   # barrel
		else:   # AIR THREAT: VULTURE — the torpedo bomber, a heavy twin-boom airframe with engine glow
			var wing := PackedVector2Array([Vector2(0, -14), Vector2(16, 8), Vector2(9, 12), Vector2(-9, 12), Vector2(-16, 8)])
			var wing_col := Color(0.588, 0.176, 0.098, 0.95)
			var boom_col := Color(0.318, 0.106, 0.063)
			var body_col := Color(0.427, 0.137, 0.078)
			if wounded:
				wing_col = wing_col.darkened(0.15)   # air craft only darken slightly — no list, it flies (C12)
				boom_col = boom_col.darkened(0.15)
				body_col = body_col.darkened(0.15)
			r.draw_colored_polygon(wing, wing_col)
			var wc := PackedVector2Array(wing); wc.append(wing[0])
			r.draw_polyline(wc, Color(0.851, 0.310, 0.169, 0.9), r.lw(1.2), true)
			for bx in [-7.0, 7.0]:   # twin engine booms running fore-aft
				r.draw_rect(Rect2(bx - 1.3, -6.0, 2.6, 16.0), boom_col)
			r.draw_line(Vector2(-8, 11), Vector2(8, 11), boom_col, r.lw(1.6))   # tailplane joining the booms
			r.draw_rect(Rect2(-2.2, -10.0, 4.4, 20.0), body_col)   # central fuselage
			r.draw_rect(Rect2(-1.4, 4.0, 2.8, 9.0), FieldRenderer.STEEL)   # the slung torpedo
			for ex in [-7.0, 7.0]:   # engine glow at the nacelle fronts
				var eg: float = 0.6 if cfg.reduced_motion else 0.55 + 0.35 * sin(now * 0.01 + ex)
				r.draw_circle(Vector2(ex, -5.0), 1.7, Color(FieldRenderer.FLASH.r, FieldRenderer.FLASH.g, FieldRenderer.FLASH.b, eg))
		if e.burn_left > 0:   # INCENDIARY (C4): flame flicker on burning drones
			r.draw_circle(Vector2.ZERO, 4.0 + sin(now * 0.05) * 1.5,
				Color(FieldRenderer.FLASH.r, FieldRenderer.FLASH.g, FieldRenderer.FLASH.b, 0.6 + 0.4 * sin(now * 0.03)))
		if wounded and e.hp == 1:
			# last pip: a small flame at the hull center (C12) — deliberately smaller than the
			# INCENDIARY burn flicker above so the two never read as the same effect; both may coexist
			var fr: float = 2.6 if cfg.reduced_motion else 2.6 + sin(r.sea_t * 30.0) * 0.8
			r.draw_circle(Vector2.ZERO, fr,
				Color(FieldRenderer.FLASH.r, FieldRenderer.FLASH.g, FieldRenderer.FLASH.b,
					0.7 if cfg.reduced_motion else 0.6 + 0.35 * sin(r.sea_t * 18.0)))
		r.draw_set_transform(e.pos, 0.0, Vector2.ONE)
		if wounded:
			# drifting smoke wisps (C12) — same language as the boss part-death smoke in draw_boss,
			# world-aligned so they rise screen-up off the hull; frozen mid-drift under reduced motion
			for k in range(2):
				var sm: float = (0.25 + float(k) * 0.3) if cfg.reduced_motion \
					else fmod(r.sea_t * 0.55 + float(i) * 0.37 + float(k) * 0.5, 1.0)
				r.draw_circle(Vector2(sm * 6.0, -8.0 - sm * 14.0 - float(k) * 2.0), 2.0 + sm * 3.0,
					Color(0.157, 0.196, 0.22, 0.5 * (1.0 - sm)))
		if e.hp < e.hp_max and e.hp_max > 2:   # hp pips under damaged toughs
			for pip in range(e.hp):
				r.draw_rect(Rect2(-10 + pip * 4, 16, 2.6, 2.2),
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
