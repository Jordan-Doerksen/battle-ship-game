class_name ShipRender
extends RefCounted
# Own-ship art — the C2 LOOK-LOCKED hull, turret classes, and the C6 bird, plus the C9 ride:
# heave (world-unit lift toward the light as the swell passes under the keel), roll (a whisper of
# rotation from the swell differential across the beam), a hull shadow that breathes with the
# heave, and the bow wave. All ride math is render-only (D1.2): the sim's ship_pos/heading are
# never touched — only where we DRAW them.

const SHADOW_COL := Color(0.008, 0.039, 0.055, 0.38)

# C1 silhouette proportions at battleship scale (spec gate revisions 1+3)
static func build_hull_outline() -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(Vector2(0, -50))
	quad(pts, Vector2(0, -50), Vector2(8, -38), Vector2(9.5, -24), 8)
	pts.append(Vector2(10, 20))
	quad(pts, Vector2(10, 20), Vector2(10, 32), Vector2(6, 35), 6)
	quad(pts, Vector2(6, 35), Vector2(0, 38), Vector2(-6, 35), 6)
	quad(pts, Vector2(-6, 35), Vector2(-10, 32), Vector2(-10, 20), 6)
	pts.append(Vector2(-9.5, -24))
	quad(pts, Vector2(-9.5, -24), Vector2(-8, -38), Vector2(0, -50), 8)
	for i in range(pts.size()):
		pts[i] *= FieldRenderer.HULL_SCALE
	return pts

static func quad(pts: PackedVector2Array, p0: Vector2, c: Vector2, p1: Vector2, n: int) -> void:
	for i in range(1, n + 1):
		var t := float(i) / float(n)
		pts.append(p0.lerp(c, t).lerp(c.lerp(p1, t), t))

# The C9 ride, sampled once per frame: heave in world units, roll in radians.
static func ride(r: FieldRenderer) -> Dictionary:
	var cfg: FieldConfig = r._field_cfg
	if cfg.reduced_motion:
		return { "heave": 0.0, "roll": 0.0, "h01": 0.0 }
	var w: GameWorld = r._world
	var fwd := Vector2(sin(w.ship_heading), -cos(w.ship_heading))
	var rgt := Vector2(-fwd.y, fwd.x)
	var h01: float = SeaRender.swell_h(cfg, w.ship_pos.x, w.ship_pos.y, r.sea_t)
	var beam: Vector2 = rgt * 30.0
	var dif: float = (SeaRender.swell_h(cfg, w.ship_pos.x + beam.x, w.ship_pos.y + beam.y, r.sea_t)
		- SeaRender.swell_h(cfg, w.ship_pos.x - beam.x, w.ship_pos.y - beam.y, r.sea_t)) * 0.5
	return { "heave": h01 * cfg.heave_px, "roll": dif * deg_to_rad(cfg.roll_deg) * 2.0, "h01": h01 }

static func draw_hull(r: FieldRenderer, rd: Dictionary) -> void:
	var fade: float = r.wreck_alpha()
	if fade <= 0.0 or not r.show_ship:
		return
	var w: GameWorld = r._world
	var cfg: FieldConfig = r._field_cfg
	# hull shadow first — sun-opposite, offset breathes with the heave (C9 depth cue)
	var off: float = cfg.shadow_px * (1.0 + 0.35 * rd["h01"])
	if off > 0.2:
		r.draw_set_transform(w.ship_pos + FieldRenderer.SHADOW_DIR * off, w.ship_heading + rd["roll"], Vector2.ONE)
		r.draw_colored_polygon(r._hull_outline, Color(SHADOW_COL.r, SHADOW_COL.g, SHADOW_COL.b, SHADOW_COL.a * fade))
	var draw_pos: Vector2 = w.ship_pos + FieldRenderer.SUN_DIR * rd["heave"]   # lift toward the light
	r.draw_set_transform(draw_pos, w.ship_heading + rd["roll"], Vector2.ONE)
	draw_bow_wave(r)
	r.draw_colored_polygon(r._hull_outline, r.wreck_fade(FieldRenderer.HULL, fade))
	var speed: float = w.ship_vel.length()
	var graced: bool = w.elapsed < w.grace_until and not w.run_over
	var flick: bool = graced and (Time.get_ticks_msec() / 60) % 2 == 0
	var edge := Color(FieldRenderer.RED.r, FieldRenderer.RED.g, FieldRenderer.RED.b, 0.9) if flick \
		else Color(FieldRenderer.FOAM.r, FieldRenderer.FOAM.g, FieldRenderer.FOAM.b,
			minf(0.55, 0.12 + speed / r._cfgs.movement.max_speed_ahead * 0.5))
	var closed := PackedVector2Array(r._hull_outline)
	closed.append(r._hull_outline[0])
	r.draw_polyline(closed, r.wreck_fade(edge, fade), r.lw(2.0 if flick else 1.2), true)
	# deck furniture (mockup rev 3): superstructure, bridge, funnel, helipad, bow jack line
	r.draw_rect(Rect2(-13, -31, 26, 41), r.wreck_fade(FieldRenderer.DECK, fade))
	r.draw_rect(Rect2(-8, -43, 16, 12), r.wreck_fade(FieldRenderer.DECK, fade))
	r.draw_rect(Rect2(-4, -18, 8, 8), r.wreck_fade(Color(0.290, 0.373, 0.408), fade))
	# a radio/radar dish sweeping on the bridge — cosmetic, rides the render clock (holds still under
	# reduced motion like the sea). A pedestal + a rotating antenna arm with a perpendicular dish face.
	var dish_hub := Vector2(0, -37)
	var dish_ang: float = 0.0 if r._field_cfg.reduced_motion else r.sea_t * 1.6
	var dd := Vector2(sin(dish_ang), -cos(dish_ang))
	var dp := Vector2(-dd.y, dd.x)
	var dish_tip := dish_hub + dd * 6.0
	r.draw_circle(dish_hub, 2.0, r.wreck_fade(FieldRenderer.STEEL, fade))
	r.draw_line(dish_hub - dd * 1.5, dish_tip, r.wreck_fade(FieldRenderer.STEEL, fade), r.lw(1.4))
	r.draw_line(dish_tip - dp * 3.0, dish_tip + dp * 3.0, r.wreck_fade(FieldRenderer.FOAM, fade), r.lw(1.4))
	r.draw_arc(Vector2(0, 65), 14.0, 0.0, TAU, 32, r.wreck_fade(FieldRenderer.STEEL, fade), r.lw(1.0), true)
	r.draw_line(Vector2(-8, 65), Vector2(8, 65), r.wreck_fade(FieldRenderer.STEEL, fade), r.lw(1.0))
	r.draw_line(Vector2(0, -137.5), Vector2(0, -103.0), r.wreck_fade(FieldRenderer.STEEL, fade), r.lw(1.0))   # bow jack rides the C14 stem
	r.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# Bow wave (C9) — two speed-scaled strokes at the stem, drawn inside the hull transform BEFORE
# the hull fill so the hull overlaps their roots.
static func draw_bow_wave(r: FieldRenderer) -> void:
	var spd01: float = clampf(r._world.ship_vel.length() / r._cfgs.movement.max_speed_ahead, 0.0, 1.0)
	if spd01 < 0.05 or r._world.run_over:
		return
	var col := Color(FieldRenderer.FOAM.r, FieldRenderer.FOAM.g, FieldRenderer.FOAM.b, 0.12 + 0.5 * spd01)
	for s in [-1.0, 1.0]:
		var pts := PackedVector2Array()
		pts.append(Vector2(s * 3.4, -135.2))
		quad(pts, Vector2(s * 3.4, -135.2), Vector2(s * 13.8, -128.3), Vector2(s * (16.0 + spd01 * 5.7), -107.7), 6)
		r.draw_polyline(pts, col, r.lw(2.0), true)

# Class-distinct turret art (LOOK-LOCK): L twin-barrel armored turret, M single-gun angular house,
# S open AA ring. Houses + barrels rotate to the WORLD barrel angle; barbettes stay hull-fixed.
# C9: mounts ride the heave/roll with the deck (positions rotate around the ship with the roll).
static func draw_mounts(r: FieldRenderer, rd: Dictionary) -> void:
	var fade: float = r.wreck_alpha()
	if fade <= 0.0 or not r.show_ship:
		return
	var w: GameWorld = r._world
	var hp_cfg: HardpointConfig = r._cfgs.hardpoints
	var lift: Vector2 = FieldRenderer.SUN_DIR * rd["heave"]
	for i in range(mini(w.mounts.size(), hp_cfg.mount_pos.size())):
		var m: Mount = w.mounts[i]
		var size: String = hp_cfg.mount_size[i]
		var mpos: Vector2 = Turrets.mount_world(w, hp_cfg.mount_pos[i])
		mpos = w.ship_pos + (mpos - w.ship_pos).rotated(rd["roll"]) + lift   # ride with the deck
		r._recoil[i] *= 0.9
		var rec: float = r._recoil[i]
		var forced: bool = m.mode == "forced"
		var house: Color = r.wreck_fade(FieldRenderer.HOUSE_FORCED if forced else FieldRenderer.HOUSE, fade)
		# barbette rings — hull-fixed under the rotating turret
		r.draw_set_transform(mpos, 0.0, Vector2.ONE)
		if size == "L":
			r.draw_arc(Vector2.ZERO, 11.5, 0.0, TAU, 32, Color(FieldRenderer.FOAM.r, FieldRenderer.FOAM.g, FieldRenderer.FOAM.b, 0.25 * fade), r.lw(1.5), true)
		elif size == "M":
			r.draw_arc(Vector2.ZERO, 7.5, 0.0, TAU, 24, Color(FieldRenderer.FOAM.r, FieldRenderer.FOAM.g, FieldRenderer.FOAM.b, 0.25 * fade), r.lw(1.0), true)
		# house + barrels at the world barrel angle (leaning with the roll)
		r.draw_set_transform(mpos, m.ang + rd["roll"], Vector2.ONE)
		if size == "L":
			for bx in [-3.2, 3.2]:
				r.draw_rect(Rect2(bx - 1.3, -9.0 - 26.0 + rec * 4.0, 2.6, 26.0), r.wreck_fade(FieldRenderer.STEEL, fade))
				r.draw_rect(Rect2(bx - 1.9, -9.0 - 26.0 + rec * 4.0, 3.8, 3.0), r.wreck_fade(FieldRenderer.STEEL, fade))   # muzzle brakes
			var lh := PackedVector2Array()
			lh.append(Vector2(-8, 12)); lh.append(Vector2(-8, -4))
			quad(lh, Vector2(-8, -4), Vector2(-8, -10), Vector2(0, -10), 5)
			quad(lh, Vector2(0, -10), Vector2(8, -10), Vector2(8, -4), 5)
			lh.append(Vector2(8, 12))
			r.draw_colored_polygon(lh, house)
			var lhc := PackedVector2Array(lh); lhc.append(lh[0])
			r.draw_polyline(lhc, Color(0.039, 0.118, 0.157, 0.55), r.lw(1.0), true)
			r.draw_rect(Rect2(-10, 3, 3, 2.4), r.wreck_fade(FieldRenderer.STEEL, fade))     # rangefinder ears
			r.draw_rect(Rect2(7, 3, 3, 2.4), r.wreck_fade(FieldRenderer.STEEL, fade))
		elif size == "M":
			r.draw_rect(Rect2(-1.1, -6.0 - 16.0 + rec * 3.0, 2.2, 16.0), r.wreck_fade(FieldRenderer.STEEL, fade))
			r.draw_rect(Rect2(-1.7, -6.0 - 7.0 + rec * 3.0, 3.4, 7.0), r.wreck_fade(FieldRenderer.STEEL, fade))             # recoil sleeve
			var mh := PackedVector2Array([
				Vector2(-5.5, 8), Vector2(-5.5, -2), Vector2(-3, -6.5),
				Vector2(3, -6.5), Vector2(5.5, -2), Vector2(5.5, 8),
			])
			r.draw_colored_polygon(mh, house)
			var mhc := PackedVector2Array(mh); mhc.append(mh[0])
			r.draw_polyline(mhc, Color(0.039, 0.118, 0.157, 0.55), r.lw(1.0), true)
		else:
			var ring := r.wreck_fade(Color(0.690, 0.537, 0.408) if forced else Color(0.494, 0.576, 0.612), fade)
			r.draw_arc(Vector2.ZERO, 5.5, 0.0, TAU, 20, ring, r.lw(1.2), true)             # open ring mount
			for bx in [-1.5, 1.5]:
				r.draw_rect(Rect2(bx - 0.55, -2.0 - 11.0 + rec * 2.0, 1.1, 11.0), r.wreck_fade(FieldRenderer.STEEL, fade))
			r.draw_circle(Vector2(0, 2.2), 2.6, house)                                    # pedestal + tub
		r.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# C6: the AIR WING bird — shadow + dip ring while airborne, fuselage/boom/rotor at the helo
# heading, idle rotor + rearm arc on the pad. Reads sim state one-way; rotor spin is cosmetic.
static func draw_helo(r: FieldRenderer) -> void:
	if r._cfgs == null or not r._cfgs.tech.helo or not r.show_ship:
		return
	var w: GameWorld = r._world
	var hp: Vector2 = w.helo_pos
	var airborne: bool = w.helo_state != "pad"
	var now: float = Time.get_ticks_msec() * 1.0
	if airborne:
		# the shadow slips off the airframe — the bird reads as ABOVE the water
		r.draw_set_transform(hp + Vector2(9, 12), 0.0, Vector2(1.0, 0.57))
		r.draw_circle(Vector2.ZERO, 7.0, Color(0.016, 0.047, 0.063, 0.35))
		r.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# dip ring pulse: the ears in the water
		var k: float = fmod(now * 0.0006, 1.0)
		r.draw_arc(hp, maxf(0.5, r._cfgs.airwing.dip_radius * k), 0.0, TAU, 48,
			Color(FieldRenderer.FOAM.r, FieldRenderer.FOAM.g, FieldRenderer.FOAM.b, 0.18 * (1.0 - k)), r.lw(1.2), true)
		r.draw_arc(hp, r._cfgs.airwing.dip_radius, 0.0, TAU, 48,
			Color(FieldRenderer.FOAM.r, FieldRenderer.FOAM.g, FieldRenderer.FOAM.b, 0.10), r.lw(1.0), true)
	var body: Color = Color(0.353, 0.439, 0.478) if airborne else Color(0.278, 0.345, 0.373)
	r.draw_set_transform(hp, w.helo_heading, Vector2(0.52, 1.0))
	r.draw_circle(Vector2(0, 1), 6.5, body)                       # fuselage (ellipse via scale)
	r.draw_set_transform(hp, w.helo_heading, Vector2.ONE)
	r.draw_rect(Rect2(-1.1, 4, 2.2, 9), body)                     # tail boom
	r.draw_rect(Rect2(-2.6, 12, 5.2, 1.6), FieldRenderer.STEEL)   # tail rotor bar
	r.draw_circle(Vector2(0, -2.2), 1.5, Color(FieldRenderer.FOAM.r, FieldRenderer.FOAM.g, FieldRenderer.FOAM.b, 0.75))   # canopy glint
	var spin: float = now * (0.045 if airborne else 0.006)        # idle turn on the pad
	r.draw_arc(Vector2.ZERO, 11.0, 0.0, TAU, 24, Color(FieldRenderer.FOAM.r, FieldRenderer.FOAM.g, FieldRenderer.FOAM.b, 0.14), r.lw(1.0), true)
	r.draw_line(Vector2(cos(spin), sin(spin)) * 11.0, Vector2(-cos(spin), -sin(spin)) * 11.0,
		Color(FieldRenderer.FOAM.r, FieldRenderer.FOAM.g, FieldRenderer.FOAM.b, 0.55), r.lw(1.4))
	r.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if not airborne and w.helo_rearm > 0.0:                       # rearm progress arc over the pad
		var kk: float = 1.0 - w.helo_rearm / maxf(r._cfgs.airwing.turnaround_secs, 0.001)
		r.draw_arc(hp, 16.0, -PI / 2.0, -PI / 2.0 + TAU * kk, 24,
			Color(0.804, 0.729, 0.557, 0.7), 2.0, true)
