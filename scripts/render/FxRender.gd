class_name FxRender
extends RefCounted
# Projectiles + one-shot effects + the C9 SPLASH COLUMNS (the owner's ask). A shell hitting the
# sea reads as a VERTICAL water column from above via five cues (approved mockup): (1) occluding
# white plume drawn ABOVE ship art, (2) a sun-opposite shadow whose offset tracks column height,
# (3) scale-pop with overshoot, (4) droplets flying outward then stopping, (5) a pale foam disc
# lingering seconds. Splash events route here from FieldRenderer.consume_effects; droplet spread
# uses the renderer's seeded cosmetic RNG — never world.rng (D1.4). Under reduced motion only the
# discs draw (they carry gameplay information).

# per-class column parameters — radii come from the sim event's blast radius
const KIND := {
	"mb16": { "rise": 0.26, "hang": 0.16, "fall": 0.42, "drops": 14, "foam_mul": 1.0, "min_px": 12.0 },
	"dp5":  { "rise": 0.20, "hang": 0.10, "fall": 0.34, "drops": 8,  "foam_mul": 0.8, "min_px": 7.0 },
	"gun":  { "rise": 0.15, "hang": 0.05, "fall": 0.22, "drops": 4,  "foam_mul": 0.5, "min_px": 4.0 },
}
const DYE := {   # per-battery splash rim tint (WWII spotting practice) — friendly shells only
	"mb16": Color(0.804, 0.729, 0.557, 0.55),   # brass
	"dp5":  Color(0.576, 0.655, 0.682, 0.6),    # steel
}

# Called by FieldRenderer.consume_effects for splash/gunsplash events.
static func spawn_splash(r: FieldRenderer, e: Dictionary, now: int) -> void:
	var radius: float = e.get("r", 6.0)
	var kind: String = "gun" if e["type"] == "gunsplash" else ("mb16" if radius >= 28.0 else "dp5")
	var drops: Array = []
	for i in range(KIND[kind]["drops"]):
		var a: float = r._srng.randf() * TAU
		drops.append({ "dir": Vector2(sin(a), -cos(a)), "dist": radius * (1.2 + r._srng.randf()) })
	r._splashes.append({
		"pos": e["pos"], "r": maxf(radius, 6.0), "kind": kind,
		"hostile": e.get("hostile", false), "t0": now, "drops": drops,
	})
	if r._splashes.size() > 80:
		r._splashes.pop_front()

# Column height 0…1+ over its life: overshoot pop, hang, quadratic fall.
static func col_h(k: Dictionary, age: float) -> float:
	if age < k["rise"]:
		var t: float = age / k["rise"] - 1.0
		return 1.0 + 2.70158 * t * t * t + 1.70158 * t * t   # easeOutBack
	if age < k["rise"] + k["hang"]:
		return 1.0
	var f: float = (age - k["rise"] - k["hang"]) / k["fall"]
	return 0.0 if f >= 1.0 else 1.0 - f * f

# (2)+(5) foam discs, column shadows, sinking-charge language — WATER level, under ship art.
static func draw_splash_water(r: FieldRenderer) -> void:
	var cfg: FieldConfig = r._field_cfg
	var now: int = Time.get_ticks_msec()
	var zoom: float = r.zoom()
	var i: int = r._splashes.size() - 1
	while i >= 0:
		var sp: Dictionary = r._splashes[i]
		var k: Dictionary = KIND[sp["kind"]]
		var age: float = (now - sp["t0"]) / 1000.0
		var foam_life: float = cfg.splash_foam_life * k["foam_mul"]
		if age >= foam_life:
			r._splashes.remove_at(i)
			i -= 1
			continue
		var rf: float = maxf(sp["r"] * cfg.splash_scale, k["min_px"] / zoom)
		# (5) the lingering foam disc — kept even under reduced motion; it carries gameplay info
		var grow: float = 1.0 if cfg.reduced_motion else 0.75 + 0.35 * minf(age / 0.6, 1.0)
		var fa: float = 0.34 * pow(1.0 - age / foam_life, 1.3)
		r.draw_circle(sp["pos"], rf * grow, Color(FieldRenderer.FOAM.r, FieldRenderer.FOAM.g, FieldRenderer.FOAM.b, fa * 0.8))
		r.draw_arc(sp["pos"], rf * grow, 0.0, TAU, 40, Color(FieldRenderer.FOAM.r, FieldRenderer.FOAM.g, FieldRenderer.FOAM.b, fa), 1.4, true)
		if cfg.splash_dye and not sp["hostile"] and DYE.has(sp["kind"]) and age < foam_life * 0.4:
			var dye: Color = DYE[sp["kind"]]
			r.draw_arc(sp["pos"], rf * grow * 0.82, 0.0, TAU, 40,
				Color(dye.r, dye.g, dye.b, dye.a * (1.0 - age / (foam_life * 0.4))), 2.0, true)
		if not cfg.reduced_motion:
			# (2) sun-opposite shadow, offset tracking column height
			var h: float = col_h(k, age)
			if h > 0.02:
				var off: float = 2.0 + h * sp["r"] * cfg.splash_scale * 0.5
				r.draw_set_transform(sp["pos"] + FieldRenderer.SHADOW_DIR * off, 0.0, Vector2(1.0, 0.55))
				r.draw_circle(Vector2.ZERO, rf * 0.7 * h, Color(0.008, 0.039, 0.055, 0.30 * minf(1.0, h)))
				r.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		i -= 1

# (1)+(3)+(4) plume + pop + droplets — ABOVE ship art (the column occludes what it lands on).
static func draw_splash_plumes(r: FieldRenderer) -> void:
	var cfg: FieldConfig = r._field_cfg
	if cfg.reduced_motion:
		return
	var now: int = Time.get_ticks_msec()
	var zoom: float = r.zoom()
	for sp in r._splashes:
		var k: Dictionary = KIND[sp["kind"]]
		var age: float = (now - sp["t0"]) / 1000.0
		var h: float = col_h(k, age)
		if h > 0.02:
			var rf: float = maxf(sp["r"] * cfg.splash_scale, k["min_px"] / zoom) * (0.5 + 0.5 * minf(h, 1.15))
			var a: float = 0.92 * minf(1.0, h)
			var col := Color(FieldRenderer.FOAM.r, FieldRenderer.FOAM.g, FieldRenderer.FOAM.b, a)
			r.draw_circle(sp["pos"], rf * 0.6 * h, col)                                            # base cap
			r.draw_circle(sp["pos"] + FieldRenderer.SUN_DIR * rf * 0.15, rf * 0.42 * h, col)
			r.draw_circle(sp["pos"] + FieldRenderer.SUN_DIR * rf * 0.30 + Vector2(0, -rf * 0.12 * h), rf * 0.26 * h, col)
			if cfg.splash_dye and not sp["hostile"] and DYE.has(sp["kind"]):
				r.draw_arc(sp["pos"], rf * 0.72 * h, 0.0, TAU, 32, DYE[sp["kind"]], 2.0, true)
		if age < 0.9:                    # (4) droplets: fly out, stop, fade
			var kk: float = minf(age / 0.5, 1.0)
			var eased: float = 1.0 - (1.0 - kk) * (1.0 - kk)
			var da: float = 0.9 if age < 0.5 else maxf(0.0, 0.9 * (1.0 - (age - 0.5) / 0.4))
			var dcol := Color(FieldRenderer.FOAM.r, FieldRenderer.FOAM.g, FieldRenderer.FOAM.b, da)
			for d in sp["drops"]:
				var p: Vector2 = sp["pos"] + d["dir"] * d["dist"] * eased * cfg.splash_scale
				r.draw_rect(Rect2(p.x - 0.8, p.y - 0.8, 1.6, 1.6), dcol)

static func draw_projectiles(r: FieldRenderer) -> void:
	for i in range(r._world.projectiles.items.size()):
		var p: Projectile = r._world.projectiles.items[i]
		if not p.active:
			continue
		var tail: Vector2 = p.pos - p.vel * (0.05 if p.hostile else 0.03)
		if p.wid == "torpedo":   # C5: dark runner drawing a foam wake line astern of itself
			var u: Vector2 = p.vel.normalized()
			for wk in range(1, 10):
				r.draw_circle(p.pos - u * (wk * 14.0), 1.6 + wk * 0.35,
					Color(FieldRenderer.FOAM.r, FieldRenderer.FOAM.g, FieldRenderer.FOAM.b, 0.5 - wk * 0.05))
			r.draw_circle(p.pos, 3.0, Color(0.094, 0.165, 0.212, 0.95))
			r.draw_arc(p.pos, 3.0, 0.0, TAU, 16, Color(0.914, 0.404, 0.259, 0.8), 1.0, true)
		elif p.wid == "dc":      # C5: charge shrinking + spreading ring as it sinks on its fuse
			var sink: float = 1.0 - p.life / maxf(r._cfgs.sonar.dc_fuse, 0.001)
			r.draw_circle(p.pos, 3.5 - sink * 2.0, Color(FieldRenderer.FOAM.r, FieldRenderer.FOAM.g, FieldRenderer.FOAM.b, 0.7 - sink * 0.5))
			r.draw_arc(p.pos, 5.0 + sink * 6.0, 0.0, TAU, 20,
				Color(FieldRenderer.FOAM.r, FieldRenderer.FOAM.g, FieldRenderer.FOAM.b, 0.3 - sink * 0.2), 1.0, true)
		elif p.wid == "doorgun":   # C6: door-gun tracer — thin, hot, wild
			r.draw_line(tail, p.pos, Color(FieldRenderer.FLASH.r, FieldRenderer.FLASH.g, FieldRenderer.FLASH.b, 0.75), 1.0)
		elif p.hostile:
			r.draw_line(tail, p.pos, Color(0.914, 0.404, 0.259, 0.95), 2.0)
			r.draw_circle(p.pos, 2.4, Color(0.914, 0.404, 0.259, 0.95))
		elif p.splash > 0.0:
			r.draw_circle(p.pos, 2.6, Color(FieldRenderer.FOAM.r, FieldRenderer.FOAM.g, FieldRenderer.FOAM.b, 0.95))
			r.draw_line(tail, p.pos, Color(FieldRenderer.FOAM.r, FieldRenderer.FOAM.g, FieldRenderer.FOAM.b, 0.35), 2.0)
		elif p.wid == "aa20":
			r.draw_line(tail, p.pos, Color(0.804, 0.729, 0.557, 0.9), 1.2)
		else:
			r.draw_line(tail, p.pos, Color(FieldRenderer.FOAM.r, FieldRenderer.FOAM.g, FieldRenderer.FOAM.b, 0.85), 1.2)

static func draw_fx(r: FieldRenderer) -> void:
	var now: int = Time.get_ticks_msec()
	var i: int = r._fx.size() - 1
	while i >= 0:
		var e: Dictionary = r._fx[i]
		var life: float = FieldRenderer.FX_LIFE.get(e["type"], 0.12)
		var age: float = (now - e["t0"]) / 1000.0
		if age >= life:
			r._fx.remove_at(i)
			i -= 1
			continue
		var k: float = age / life
		match e["type"]:
			"muzzle":
				var dirv := Vector2(sin(e["ang"]), -cos(e["ang"]))
				var flen: float = FieldRenderer.FLASH_LEN[e["size"]]
				var fr: float = (6.5 if e["size"] == "L" else (3.2 if e["size"] == "M" else 2.2)) * (1.0 + k)
				r.draw_circle(e["pos"] + dirv * flen, fr,
					Color(FieldRenderer.FLASH.r, FieldRenderer.FLASH.g, FieldRenderer.FLASH.b, 0.9 * (1.0 - k)))
			"gunflash":
				var gd := Vector2(sin(e["ang"]), -cos(e["ang"]))
				r.draw_circle(e["pos"] + gd * 14.0, 3.0 * (1.0 + k), Color(0.914, 0.404, 0.259, 0.9 * (1.0 - k)))
			"airburst":   # PROXIMITY BURST (C4): amber flak cloud
				r.draw_arc(e["pos"], e["r"] * (0.4 + k * 0.6), 0.0, TAU, 24,
					Color(FieldRenderer.FLASH.r, FieldRenderer.FLASH.g, FieldRenderer.FLASH.b, 0.85 * (1.0 - k)), 1.6, true)
				r.draw_circle(e["pos"], 3.0 * (1.0 - k),
					Color(FieldRenderer.FLASH.r, FieldRenderer.FLASH.g, FieldRenderer.FLASH.b, 0.5 * (1.0 - k)))
			"ignite":     # INCENDIARY (C4): catch-fire pop
				r.draw_circle(e["pos"], 5.0 * (1.0 + k),
					Color(FieldRenderer.FLASH.r, FieldRenderer.FLASH.g, FieldRenderer.FLASH.b, 0.9 * (1.0 - k)))
			"crashturn":  # CRASH TURN (C4): amber wash off the hull
				r.draw_arc(r._world.ship_pos, 40.0 + 160.0 * k, 0.0, TAU, 48,
					Color(FieldRenderer.FLASH.r, FieldRenderer.FLASH.g, FieldRenderer.FLASH.b, 0.7 * (1.0 - k)), 3.0, true)
			"dcblast":    # C5/C9: underwater bulge — subsurface glow, pale dome swelling, dark ring chasing
				for g in range(3):
					r.draw_circle(e["pos"], e["r"] * (1.5 - g * 0.35),
						Color(0.314, 0.627, 0.667, 0.08 * (g + 1) * (1.0 - k)))
				r.draw_circle(e["pos"], e["r"] * (0.3 + k * 0.7),
					Color(FieldRenderer.FOAM.r, FieldRenderer.FOAM.g, FieldRenderer.FOAM.b, 0.35 * (1.0 - k)))
				r.draw_arc(e["pos"], maxf(0.5, e["r"] * k), 0.0, TAU, 40, Color(0.094, 0.165, 0.212, 0.8 * (1.0 - k)), 3.0, true)
			"dcvolley":   # C5: the racks roll — a foam pulse off the stern
				r.draw_arc(e["pos"], 12.0 + 30.0 * k, 0.0, TAU, 32,
					Color(FieldRenderer.FOAM.r, FieldRenderer.FOAM.g, FieldRenderer.FOAM.b, 0.6 * (1.0 - k)), 1.5, true)
			"helodrop":   # C6: the light rack lets go
				r.draw_arc(e["pos"], 8.0 + 22.0 * k, 0.0, TAU, 24,
					Color(FieldRenderer.FOAM.r, FieldRenderer.FOAM.g, FieldRenderer.FOAM.b, 0.55 * (1.0 - k)), 1.4, true)
			"helodown":   # C6: flare + touchdown puff on the pad
				r.draw_arc(e["pos"], 10.0 + 14.0 * k, 0.0, TAU, 24, Color(0.804, 0.729, 0.557, 0.5 * (1.0 - k)), 1.2, true)
			"partdown":   # C7: a machine part dies hard
				r.draw_arc(e["pos"], 6.0 + 34.0 * k, 0.0, TAU, 32,
					Color(FieldRenderer.FLASH.r, FieldRenderer.FLASH.g, FieldRenderer.FLASH.b, 0.9 * (1.0 - k)), 2.5, true)
				r.draw_circle(e["pos"], 5.0 * (1.0 - k),
					Color(FieldRenderer.FLASH.r, FieldRenderer.FLASH.g, FieldRenderer.FLASH.b, 0.5 * (1.0 - k)))
			"bossdown":   # C7: the machine goes down — a shipdeath-scale event
				for ring in range(4):
					var rk: float = maxf(0.0, k - ring * 0.1)
					r.draw_arc(e["pos"], 12.0 + 320.0 * rk, 0.0, TAU, 48,
						Color(FieldRenderer.RED.r, FieldRenderer.RED.g, FieldRenderer.RED.b, 0.9 * (1.0 - rk)), 5.0 - ring, true)
			"breach":     # C7: THE MAW erupts through the surface
				r.draw_arc(e["pos"], 20.0 + 110.0 * k, 0.0, TAU, 48,
					Color(FieldRenderer.FOAM.r, FieldRenderer.FOAM.g, FieldRenderer.FOAM.b, 0.8 * (1.0 - k)), 3.0, true)
				r.draw_circle(e["pos"], 60.0 * k,
					Color(FieldRenderer.FOAM.r, FieldRenderer.FOAM.g, FieldRenderer.FOAM.b, 0.25 * (1.0 - k)))
			"dive":       # C7: it seals and slides under
				r.draw_arc(e["pos"], 90.0 * (1.0 - k) + 10.0, 0.0, TAU, 40,
					Color(FieldRenderer.FOAM.r, FieldRenderer.FOAM.g, FieldRenderer.FOAM.b, 0.5 * (1.0 - k)), 2.0, true)
			"contact":    # C5: sonar acquisition ping — expanding diamond over the water
				var cr: float = 10.0 + 30.0 * k
				var dia := PackedVector2Array([
					e["pos"] + Vector2(0, -cr), e["pos"] + Vector2(cr, 0),
					e["pos"] + Vector2(0, cr), e["pos"] + Vector2(-cr, 0), e["pos"] + Vector2(0, -cr),
				])
				r.draw_polyline(dia, Color(FieldRenderer.FOAM.r, FieldRenderer.FOAM.g, FieldRenderer.FOAM.b, 0.8 * (1.0 - k)), 1.5, true)
			"death":
				r.draw_arc(e["pos"], 4.0 + 26.0 * k, 0.0, TAU, 32,
					Color(FieldRenderer.RED.r, FieldRenderer.RED.g, FieldRenderer.RED.b, 0.85 * (1.0 - k)), 2.0, true)
			"shiphit":
				r.draw_arc(e["pos"], 10.0 + 40.0 * k, 0.0, TAU, 32,
					Color(FieldRenderer.RED.r, FieldRenderer.RED.g, FieldRenderer.RED.b, 0.9 * (1.0 - k)), 3.0, true)
			"shipdeath":
				for ring in range(3):
					var rk: float = maxf(0.0, k - ring * 0.12)
					r.draw_arc(e["pos"], 10.0 + 220.0 * rk, 0.0, TAU, 48,
						Color(0.914, 0.404, 0.259, 0.9 * (1.0 - rk)), 4.0 - ring, true)
			"hit":
				r.draw_circle(e["pos"], 3.0, Color(FieldRenderer.FOAM.r, FieldRenderer.FOAM.g, FieldRenderer.FOAM.b, 0.8 * (1.0 - k)))
		i -= 1
