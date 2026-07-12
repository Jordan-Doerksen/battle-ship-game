class_name AmbienceRender
extends RefCounted
# C19 THE DETAIL PASS (docs/specs/detail-pass.md) — the render-domain helper that owns the "one
# more 1%" layer (C9 split family; all three approved packs live here so one file owns the layer).
# ENTIRELY one-way: reads world/cfgs, rides the render clock and r._srng (cosmetic rng), consumes
# the same effect batch as everything else via on_event. The sim never knows any of this exists —
# the acceptance gate IS every existing probe staying byte-identical.
#
# Readability law (research): this layer never out-contrasts gameplay marks — alpha ceilings live
# in AmbienceConfig. reduced_motion: bobbing/circling/spawning freeze; static marks stay.

const FOAM := Color(0.894, 0.941, 0.949)
const BRASS := Color(0.804, 0.729, 0.557)
const CLOUD_TILE: float = 4200.0
const FLOT_TILE: float = 1700.0
const WIND_BEARING: float = 205.0 * PI / 180.0   # matches WeatherRender's rail default

static func _state(r: FieldRenderer) -> Dictionary:
	if not r._amb.has("init"):
		var flot: Array = []
		for i in range(16):
			flot.append({ "x": r._srng.randf() * FLOT_TILE, "y": r._srng.randf() * FLOT_TILE,
				"rot": r._srng.randf() * TAU, "plank": r._srng.randf() < 0.5 })
		var clouds: Array = []
		for i in range(6):
			clouds.append({ "x": r._srng.randf() * CLOUD_TILE, "y": r._srng.randf() * CLOUD_TILE,
				"rx": 260.0 + r._srng.randf() * 340.0, "ry": 150.0 + r._srng.randf() * 200.0,
				"ang": r._srng.randf() * TAU })
		var gulls: Array = []
		for i in range(4):
			gulls.append({ "a": r._srng.randf() * TAU, "r": 70.0 + r._srng.randf() * 45.0,
				"w": 0.45 + r._srng.randf() * 0.3, "ph": r._srng.randf() * TAU })
		r._amb = { "init": true, "flot": flot, "clouds": clouds, "gulls": gulls,
			"slicks": [], "boils": [], "haze": [], "casings": [], "spray": [],
			"smoke": [], "smoke_ms": 0, "scare_ms": -100000,
			"lamp_ms": 0, "lamp_seq": [] }
	return r._amb

# ── the effect hook (FieldRenderer.consume_effects forwards the batch) ──────────────────────────
static func on_event(r: FieldRenderer, e: Dictionary, now: int) -> void:
	if not r._cfgs.ambience.enabled:
		return
	var amb: Dictionary = _state(r)
	match e["type"]:
		"death":
			if e.get("layer", "") == "surf":
				var bits: Array = []
				for i in range(4):
					var a: float = r._srng.randf() * TAU
					bits.append({ "dx": sin(a), "dy": -cos(a), "d": 8.0 + r._srng.randf() * 16.0,
						"plank": r._srng.randf() < 0.6 })
				amb["slicks"].append({ "pos": e["pos"], "t0": now, "bits": bits })
				if amb["slicks"].size() > 10:
					amb["slicks"].pop_front()
			elif e.get("layer", "") == "sub":
				amb["boils"].append({ "pos": e["pos"], "t0": now })
		"muzzle":
			var wamt: float = _wind(r)
			amb["haze"].append({ "pos": e["pos"], "t0": now,
				"dx": sin(WIND_BEARING) * (4.0 + wamt * 14.0), "dy": cos(WIND_BEARING) * (4.0 + wamt * 14.0) })
			if amb["haze"].size() > 40:
				amb["haze"].pop_front()
			if e.get("size", "") == "M":
				var pa: float = r._srng.randf() * TAU
				amb["casings"].append({ "pos": e["pos"], "t0": now,
					"dx": sin(pa) * (14.0 + r._srng.randf() * 10.0), "dy": -cos(pa) * (14.0 + r._srng.randf() * 10.0) })
				if amb["casings"].size() > 30:
					amb["casings"].pop_front()
			if Vector2(e["pos"]).distance_to(_stern(r)) < r._cfgs.ambience.gull_scatter_r:
				amb["scare_ms"] = now
		"gunflash":
			if Vector2(e["pos"]).distance_to(_stern(r)) < r._cfgs.ambience.gull_scatter_r:
				amb["scare_ms"] = now

# ── UNDER the wake: drifting cloud shadows (the cheapest whole-screen liveliness) ────────────────
static func draw_clouds(r: FieldRenderer) -> void:
	var ac: AmbienceConfig = r._cfgs.ambience
	if not ac.enabled or ac.cloud_alpha <= 0.005:
		return
	var amb: Dictionary = _state(r)
	var drift: float = r.sea_t * 9.0
	var view: Rect2 = r.view_rect().grow(500.0)
	for i in range(mini(ac.cloud_count, amb["clouds"].size())):
		var cl: Dictionary = amb["clouds"][i]
		var wx: float = fposmod(cl["x"] + sin(WIND_BEARING) * drift - r._world.ship_pos.x + CLOUD_TILE * 0.5, CLOUD_TILE) \
			- CLOUD_TILE * 0.5 + r._world.ship_pos.x
		var wy: float = fposmod(cl["y"] + cos(WIND_BEARING) * drift - r._world.ship_pos.y + CLOUD_TILE * 0.5, CLOUD_TILE) \
			- CLOUD_TILE * 0.5 + r._world.ship_pos.y
		if not view.has_point(Vector2(wx, wy)):
			continue
		for s in range(3):   # stepped soft ellipse — no gradient primitive needed
			var f: float = 1.0 - float(s) * 0.28
			_ellipse(r, Vector2(wx, wy), cl["rx"] * f, cl["ry"] * f, cl["ang"],
				Color(0.008, 0.03, 0.045, ac.cloud_alpha / 3.0))

# ── water furniture (pre-ship): slicks + debris, sub boils, flotsam, channel buoys ───────────────
static func draw_water(r: FieldRenderer) -> void:
	var ac: AmbienceConfig = r._cfgs.ambience
	if not ac.enabled:
		return
	var amb: Dictionary = _state(r)
	var now: int = Time.get_ticks_msec()
	var reduced: bool = r._field_cfg.reduced_motion
	# oil slicks + debris fields — the battle marks the sea
	for i in range(amb["slicks"].size() - 1, -1, -1):
		var s: Dictionary = amb["slicks"][i]
		var age: float = float(now - int(s["t0"])) / 1000.0
		if age >= ac.slick_life:
			amb["slicks"].remove_at(i)
			continue
		var fade: float = 1.0 - age / ac.slick_life
		var breathe: float = 1.0 if reduced else 1.0 + sin(r.sea_t * 0.22 + float(int(s["t0"]) % 7)) * 0.05
		var grow: float = (0.6 + 0.4 * minf(age / 8.0, 1.0)) * breathe
		var p: Vector2 = s["pos"]
		_ellipse(r, p, 40.0 * grow, 25.0 * grow, 0.5, Color(0.016, 0.035, 0.047, ac.slick_alpha * fade))
		_ellipse(r, p + Vector2(22, 13) * grow, 25.0 * grow, 15.0 * grow, 0.9, Color(0.016, 0.035, 0.047, ac.slick_alpha * 0.8 * fade))
		_ellipse(r, p + Vector2(-18, 9) * grow, 19.0 * grow, 12.0 * grow, 1.6, Color(0.016, 0.035, 0.047, ac.slick_alpha * 0.8 * fade))
		r.draw_arc(p + Vector2(4, 4), 44.0 * grow, 0.0, TAU, 24,
			Color(0.47, 0.55, 0.59, 0.13 * fade), r.lw(1.1), true)   # the faint sheen rim
		var spread: float = minf(age / 20.0, 1.0)
		for b in s["bits"]:   # debris drifting apart
			var bp: Vector2 = p + Vector2(b["dx"], b["dy"]) * (float(b["d"]) * (0.4 + spread))
			if b["plank"]:
				r.draw_rect(Rect2(bp - Vector2(3.0, 0.9), Vector2(6.0, 1.8)), Color(0.29, 0.37, 0.41, 0.8 * fade))
			else:
				r.draw_rect(Rect2(bp - Vector2(1.7, 1.7), Vector2(3.4, 3.4)), Color(0.29, 0.37, 0.41, 0.8 * fade))
	# sub-death boils — the deep gives up its air
	for i in range(amb["boils"].size() - 1, -1, -1):
		var bo: Dictionary = amb["boils"][i]
		var age2: float = float(now - int(bo["t0"])) / 1000.0
		if age2 >= ac.bubble_life:
			amb["boils"].remove_at(i)
			continue
		var kk: float = age2 / ac.bubble_life
		for ring in range(3):
			var rk: float = fposmod(kk * 2.0 + float(ring) * 0.33, 1.0)
			r.draw_arc(bo["pos"], 2.0 + rk * 16.0, 0.0, TAU, 16,
				Color(FOAM.r, FOAM.g, FOAM.b, 0.35 * (1.0 - rk) * (1.0 - kk)), r.lw(1.0), true)
	# ambient flotsam — a free speed/heading parallax cue
	if ac.flotsam_count > 0:
		for i in range(mini(ac.flotsam_count, amb["flot"].size())):
			var f: Dictionary = amb["flot"][i]
			var wx: float = fposmod(f["x"] - r._world.ship_pos.x + FLOT_TILE * 0.5, FLOT_TILE) - FLOT_TILE * 0.5 + r._world.ship_pos.x
			var wy: float = fposmod(f["y"] - r._world.ship_pos.y + FLOT_TILE * 0.5, FLOT_TILE) - FLOT_TILE * 0.5 + r._world.ship_pos.y
			var bob: float = 0.0 if reduced else sin(r.sea_t * 0.6 + f["rot"] * 3.0) * 1.2
			var fp := Vector2(wx, wy + bob)
			if not r.view_rect().grow(20.0).has_point(fp):
				continue
			var rot: float = f["rot"] + (0.0 if reduced else r.sea_t * 0.12)
			var u := Vector2(cos(rot), sin(rot))
			if f["plank"]:
				r.draw_line(fp - u * 3.2, fp + u * 3.2, Color(0.29, 0.37, 0.41, 0.8), r.lw(1.8))
			else:
				r.draw_rect(Rect2(fp - Vector2(1.8, 1.8), Vector2(3.6, 3.6)), Color(0.29, 0.37, 0.41, 0.8))
	# channel buoys — seeded off the islets, extending the nav-light language
	var placed: int = 0
	for t in r._world.terrain:
		if placed >= ac.buoy_count:
			break
		if not bool(t.get("islet", false)):
			continue
		var h: float = _hash01(float(r._world.world_seed) + float(placed) * 17.3)
		var bpos: Vector2 = Vector2(t["pos"]) + Vector2(sin(h * TAU), -cos(h * TAU)) * (float(t["r"]) + 55.0)
		var bob2: float = 0.0 if reduced else sin(r.sea_t * 0.7 + h * 9.0) * 1.6
		var bp2 := bpos + Vector2(0, bob2)
		placed += 1
		if not r.view_rect().grow(30.0).has_point(bp2):
			continue
		r.draw_circle(bp2 + Vector2(1.6, 2.2), 3.4, Color(0.008, 0.04, 0.055, 0.35))
		r.draw_circle(bp2, 3.2, Color(0.29, 0.37, 0.41, 1.0))
		r.draw_rect(Rect2(bp2 - Vector2(3.2, 1.0), Vector2(6.4, 2.0)), Color(0.851, 0.31, 0.169, 0.95))
		if reduced or fmod(r.sea_t + h * 3.0, 3.0) < 0.35:   # the lamp
			r.draw_circle(bp2 + Vector2(0, -1.4), 0.9, Color(FOAM.r, FOAM.g, FOAM.b, 0.95))
			r.draw_circle(bp2 + Vector2(0, -1.4), 3.2, Color(FOAM.r, FOAM.g, FOAM.b, 0.12))

# ── above the ship: smoke, casings, sprays, the lamp, the gulls ─────────────────────────────────
static func draw_ship_fx(r: FieldRenderer) -> void:
	var ac: AmbienceConfig = r._cfgs.ambience
	if not ac.enabled:
		return
	var amb: Dictionary = _state(r)
	var w: GameWorld = r._world
	var now: int = Time.get_ticks_msec()
	var reduced: bool = r._field_cfg.reduced_motion
	var spd01: float = clampf(w.ship_vel.length() / r._cfgs.movement.max_speed_ahead, 0.0, 1.0)
	var fwd := Vector2(sin(w.ship_heading), -cos(w.ship_heading))
	var rgt := Vector2(-fwd.y, fwd.x)
	# funnel smoke — throttle-responsive, streams downwind (C17's wind table when a front is up)
	if not reduced and not w.run_over and spd01 > 0.08 and now >= int(amb["smoke_ms"]):
		amb["smoke_ms"] = now + int((140.0 - spd01 * 60.0))
		var wamt: float = _wind(r)
		amb["smoke"].append({ "pos": w.ship_pos + fwd * -18.0 + rgt * 0.0 + fwd * 2.0, "t0": now, "s": spd01,
			"dx": sin(WIND_BEARING) * (6.0 + wamt * 22.0) - w.ship_vel.x * 0.12,
			"dy": cos(WIND_BEARING) * (6.0 + wamt * 22.0) - w.ship_vel.y * 0.12 })
		if amb["smoke"].size() > 60:
			amb["smoke"].pop_front()
	for i in range(amb["smoke"].size() - 1, -1, -1):
		var sm: Dictionary = amb["smoke"][i]
		var age: float = float(now - int(sm["t0"])) / 1000.0
		if age >= ac.smoke_life or reduced:
			amb["smoke"].remove_at(i)
			continue
		var kk: float = age / ac.smoke_life
		var sp: Vector2 = Vector2(sm["pos"]) + Vector2(sm["dx"], sm["dy"]) * age
		r.draw_circle(sp, 1.6 + kk * 5.5, Color(0.5, 0.54, 0.56, ac.smoke_alpha * float(sm["s"]) * (1.0 - kk)))
	# cordite haze — sustained fire wreathes the mounts until wind clears it
	for i in range(amb["haze"].size() - 1, -1, -1):
		var hz: Dictionary = amb["haze"][i]
		var hage: float = float(now - int(hz["t0"])) / 1000.0
		if hage >= ac.haze_life or reduced:
			amb["haze"].remove_at(i)
			continue
		var hk: float = hage / ac.haze_life
		var hp: Vector2 = Vector2(hz["pos"]) + Vector2(hz["dx"], hz["dy"]) * hage
		r.draw_circle(hp, 3.0 + hk * 9.0, Color(0.42, 0.46, 0.48, ac.haze_alpha * (1.0 - hk)))
	# ejected brass — a glint, a tumble, gone
	for i in range(amb["casings"].size() - 1, -1, -1):
		var cg: Dictionary = amb["casings"][i]
		var cage: float = float(now - int(cg["t0"])) / 1000.0
		if cage >= ac.casing_life:
			amb["casings"].remove_at(i)
			continue
		var ck: float = cage / ac.casing_life
		var cp: Vector2 = Vector2(cg["pos"]) + Vector2(cg["dx"], cg["dy"]) * cage * (1.0 - ck * 0.6)
		r.draw_rect(Rect2(cp - Vector2(0.9, 0.6), Vector2(1.8, 1.2)),
			Color(BRASS.r, BRASS.g, BRASS.b, 0.8 * (1.0 - ck)))
	# bow spray (weather + speed) and heel spray (hard rudder at speed)
	if not reduced and not w.run_over:
		var wxk: float = maxf(float(r._cfgs.weather.rain_amount.get(w.wx_state, 0.0)), _wind(r) * 0.7)
		if spd01 > ac.spray_speed_frac and wxk > 0.3 and r._srng.randf() < 0.5 * spd01:
			var side: float = 1.0 if r._srng.randf() < 0.5 else -1.0
			amb["spray"].append({ "pos": w.ship_pos + fwd * 105.0 + rgt * side * 8.0, "t0": now,
				"dx": rgt.x * side * (30.0 + r._srng.randf() * 40.0) - fwd.x * 20.0,
				"dy": rgt.y * side * (30.0 + r._srng.randf() * 40.0) - fwd.y * 20.0 })
		if absf(w.input.rudder) > ac.heel_rudder and spd01 > 0.5 and r._srng.randf() < 0.45:
			var lee: float = -signf(w.input.rudder)
			amb["spray"].append({ "pos": w.ship_pos + rgt * lee * 26.0 + fwd * (r._srng.randf() * 60.0 - 20.0), "t0": now,
				"dx": rgt.x * lee * (24.0 + r._srng.randf() * 26.0), "dy": rgt.y * lee * (24.0 + r._srng.randf() * 26.0) })
		if amb["spray"].size() > 60:
			while amb["spray"].size() > 60:
				amb["spray"].pop_front()
	for i in range(amb["spray"].size() - 1, -1, -1):
		var spr: Dictionary = amb["spray"][i]
		var sage: float = float(now - int(spr["t0"])) / 1000.0
		if sage >= 0.45 or reduced:
			amb["spray"].remove_at(i)
			continue
		var sk: float = sage / 0.45
		var pp: Vector2 = Vector2(spr["pos"]) + Vector2(spr["dx"], spr["dy"]) * sage
		r.draw_rect(Rect2(pp - Vector2(0.8, 0.8), Vector2(1.6, 1.6)), Color(FOAM.r, FOAM.g, FOAM.b, 0.65 * (1.0 - sk)))
	# the bridge signal lamp — morse-ish triplets on a lazy clock
	if not w.run_over:
		if now >= int(amb["lamp_ms"]):
			amb["lamp_ms"] = now + int(ac.lamp_period * 1000.0 * (0.7 + r._srng.randf() * 0.6))
			var seq: Array = []
			var t0: int = now + 300
			for i in range(3 + r._srng.randi() % 3):
				var dur: int = 280 if r._srng.randf() < 0.35 else 100
				seq.append([t0, t0 + dur])
				t0 += dur + 120
			amb["lamp_seq"] = seq
		var lamp_on: bool = false
		for seg in amb["lamp_seq"]:
			if now >= int(seg[0]) and now < int(seg[1]):
				lamp_on = true
				break
		if lamp_on:
			var lp: Vector2 = w.ship_pos + (Vector2(7, -45)).rotated(w.ship_heading)
			r.draw_circle(lp, 1.4, Color(FOAM.r, FOAM.g, FOAM.b, 0.95))
			r.draw_circle(lp, 5.0, Color(FOAM.r, FOAM.g, FOAM.b, 0.14))
	# the gulls — they circle the stern, scatter at gunfire, and leave in weather
	var raining: bool = float(r._cfgs.weather.rain_amount.get(w.wx_state, 0.0)) > 0.3
	var scared: bool = float(now - int(amb["scare_ms"])) / 1000.0 < ac.gull_calm_secs
	if ac.gull_count > 0 and not raining and not w.run_over:
		var stern: Vector2 = _stern(r)
		for i in range(mini(ac.gull_count, amb["gulls"].size())):
			var g: Dictionary = amb["gulls"][i]
			if not reduced:
				g["a"] = float(g["a"]) + float(g["w"]) * 0.016 * (3.0 if scared else 1.0)
			var gr: float = float(g["r"]) * (2.6 if scared else 1.0)   # scattered = a wide, fast, fading orbit
			var gp: Vector2 = stern + Vector2(sin(g["a"]), -cos(g["a"])) * gr
			var flap: float = 0.5 if reduced else sin(r.sea_t * 7.0 + float(g["ph"])) * 0.5 + 0.5
			var s: float = 2.6 + 0.8 * flap
			var ga: float = 0.35 if scared else 0.75
			var pts := PackedVector2Array([
				gp + Vector2(-s, -s * 0.35 * flap), gp + Vector2(-s * 0.4, s * 0.3), gp,
				gp + Vector2(s * 0.4, s * 0.3), gp + Vector2(s, -s * 0.35 * flap),
			])
			r.draw_polyline(pts, Color(FOAM.r, FOAM.g, FOAM.b, ga), r.lw(1.1))

static func _stern(r: FieldRenderer) -> Vector2:
	return r._world.ship_pos + Vector2(0, 80).rotated(r._world.ship_heading)

static func _wind(r: FieldRenderer) -> float:
	return float(r._cfgs.weather.wind_amount.get(r._world.wx_state, 0.25))

static func _hash01(x: float) -> float:
	var s: float = sin(x * 127.1) * 43758.5453
	return s - floor(s)

static func _ellipse(r: FieldRenderer, c: Vector2, rx: float, ry: float, ang: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(20):
		var t: float = float(i) / 20.0 * TAU
		pts.append(c + (Vector2(cos(t) * rx, sin(t) * ry)).rotated(ang))
	r.draw_colored_polygon(pts, col)
