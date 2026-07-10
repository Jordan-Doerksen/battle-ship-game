class_name SeaRender
extends RefCounted
# C9 sea/field layer — grid, crest-biased flecks, crest-foam streaks, wake, and the analytic
# swell that drives ride/bias (the GDScript twin of sea.gdshader's band recipe: shared direction
# and tempo, approximate phase — the approved mockup documents this as acceptable at these
# amplitudes). Static draw funcs called by FieldRenderer's _draw in its locked order; all state
# lives on the renderer. Render-only: reads the world, mutates nothing but render arrays.

# Analytic swell height (−1…1) at a world point — heave/roll/crest-bias sample this.
static func swell_h(cfg: FieldConfig, wx: float, wy: float, t: float) -> float:
	var k: float = 0.0035 / maxf(0.2, cfg.sea_scale)
	var sp: float = cfg.sea_drift
	return 0.6 * sin((wx * 0.71 + wy * 0.71) * k + t * 0.25 * sp) \
	     + 0.4 * sin((wx * 0.44 - wy * 0.90) * k * 1.9 - t * 0.37 * sp)

# High-frequency layers fade as the camera pulls back (the C10 contract) — shared with the shader.
static func hf_fade(zoom: float) -> float:
	var t: float = clampf((zoom - 0.42) / (0.75 - 0.42), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

static func draw_grid(r: FieldRenderer) -> void:
	var view: Rect2 = r.view_rect()
	for layer in [[r._field_cfg.grid_minor, 0.035], [r._field_cfg.grid_major, 0.07]]:
		var step: float = layer[0]
		var col := Color(FieldRenderer.FOAM.r, FieldRenderer.FOAM.g, FieldRenderer.FOAM.b, layer[1])
		var gx: float = floorf(view.position.x / step) * step
		while gx <= view.end.x:
			r.draw_line(Vector2(gx, view.position.y), Vector2(gx, view.end.y), col, 1.0)
			gx += step
		var gy: float = floorf(view.position.y / step) * step
		while gy <= view.end.y:
			r.draw_line(Vector2(view.position.x, gy), Vector2(view.end.x, gy), col, 1.0)
			gy += step

static func draw_flecks(r: FieldRenderer) -> void:
	var cfg: FieldConfig = r._field_cfg
	var tile: float = cfg.field_tile
	var cam_pos: Vector2 = r._world.ship_pos
	var fade: float = 0.45 + 0.55 * hf_fade(r.target_zoom)
	var bias: float = cfg.crest_bias
	for f in r._flecks:
		var wx: float = fposmod(f["x"] - cam_pos.x + tile * 0.5, tile) - tile * 0.5 + cam_pos.x
		var wy: float = fposmod(f["y"] - cam_pos.y + tile * 0.5, tile) - tile * 0.5 + cam_pos.y
		var crest: float = clampf((swell_h(cfg, wx, wy, r.sea_t) + 1.0) * 0.5, 0.0, 1.0)
		crest = crest * crest * (3.0 - 2.0 * crest)
		var a: float = 0.16 * (1.0 - bias * 0.65 + bias * 1.3 * crest) * fade
		if a <= 0.01:
			continue
		var bob: float = 0.0 if cfg.reduced_motion else sin(r.sea_t * 0.6 + f["ph"]) * 1.5
		var len: float = f["len"] * (0.8 + 0.5 * crest)
		r.draw_line(Vector2(wx - len * 0.5, wy + bob), Vector2(wx + len * 0.5, wy + bob),
			Color(FieldRenderer.FOAM.r, FieldRenderer.FOAM.g, FieldRenderer.FOAM.b, a), 1.0)

# Crest-foam streaks (direction B's weather): thin white lines forming and breaking along swell
# crests. Cosmetic spawn via the renderer's seeded cosmetic RNG — never world.rng (D1.4).
static func step_streaks(r: FieldRenderer) -> void:
	var cfg: FieldConfig = r._field_cfg
	if cfg.reduced_motion or cfg.crest_streaks <= 0.02:
		r._streaks.clear()
		return
	var view: Rect2 = r.view_rect()
	for k in range(3):
		if r._srng.randf() > cfg.crest_streaks * 0.75:
			continue
		var wx: float = view.position.x + r._srng.randf() * view.size.x
		var wy: float = view.position.y + r._srng.randf() * view.size.y
		if swell_h(cfg, wx, wy, r.sea_t) < 0.55:
			continue
		r._streaks.append({
			"pos": Vector2(wx, wy), "t0": r.sea_t,
			"life": 1.6 + r._srng.randf() * 1.2,
			"len": 18.0 + r._srng.randf() * 26.0,
			"ang": -PI / 4.0 + (r._srng.randf() - 0.5) * 0.5,
		})
		if r._streaks.size() > 90:
			r._streaks.pop_front()

static func draw_streaks(r: FieldRenderer) -> void:
	var cfg: FieldConfig = r._field_cfg
	var fade: float = (0.45 + 0.55 * hf_fade(r.target_zoom)) * cfg.crest_streaks
	var i: int = r._streaks.size() - 1
	while i >= 0:
		var s: Dictionary = r._streaks[i]
		var k: float = (r.sea_t - s["t0"]) / s["life"]
		if k >= 1.0 or k < 0.0:
			r._streaks.remove_at(i)
			i -= 1
			continue
		var a: float = 0.30 * sin(PI * k) * fade
		if a > 0.01:
			var d := Vector2(cos(s["ang"]), sin(s["ang"]))
			var half: float = s["len"] * (0.5 + 0.7 * k) * 0.5
			var mid: Vector2 = s["pos"] + Vector2(-d.y, d.x) * 4.0   # slight arc via a bent midpoint
			var pts := PackedVector2Array()
			for j in range(9):
				var t: float = j / 8.0
				var p0: Vector2 = s["pos"] - d * half
				var p1: Vector2 = s["pos"] + d * half
				pts.append(p0.lerp(mid, t).lerp(mid.lerp(p1, t), t))
			r.draw_polyline(pts, Color(FieldRenderer.FOAM.r, FieldRenderer.FOAM.g, FieldRenderer.FOAM.b, a), r.lw(1.3), true)
		i -= 1

# Wake (C9): prop churn + widening V shoulders that drift outboard — persistent churned foam.
static func emit_wake(r: FieldRenderer) -> void:
	if r._world.run_over:
		return
	var speed: float = r._world.ship_vel.length()
	var along: float = Movement.keel_speeds(r._world).x
	var braking: bool = r._world.input.thrust < 0.0 and along > 5.0
	if speed < 6.0 and not braking:
		return
	var fwd := Vector2(sin(r._world.ship_heading), -cos(r._world.ship_heading))
	var rgt := Vector2(-fwd.y, fwd.x)
	var w: float = minf(1.0, speed / r._cfgs.movement.max_speed_ahead) + (0.7 if braking else 0.0)
	var stern: Vector2 = r._world.ship_pos - fwd * 115.0   # just aft of the C14 hull
	r._wake.append({ "pos": stern, "t": r._world.elapsed, "w": w,
		"ang": r._world.ship_heading, "drift": Vector2.ZERO })            # prop churn
	for side in [-1.0, 1.0]:                                              # shoulders widen the V
		r._wake.append({ "pos": stern + rgt * side * 14.0, "t": r._world.elapsed, "w": w * 0.7,
			"ang": r._world.ship_heading, "drift": rgt * side * 7.0 })
	while r._wake.size() > r._field_cfg.wake_max_points:
		r._wake.pop_front()

static func draw_wake(r: FieldRenderer) -> void:
	var cfg: FieldConfig = r._field_cfg
	for p in r._wake:
		var dt: float = r._world.elapsed - p["t"]
		var age: float = dt / cfg.wake_life
		if age >= 1.0:
			continue
		var churn: bool = p["drift"] == Vector2.ZERO
		var rad: float = (1.6 + p["w"] * 3.0 + age * 6.0 * p["w"]) * cfg.wake_width
		var a: float = (0.20 if churn and age < 0.12 else 0.12) * p["w"] * pow(1.0 - age, 1.6)
		if a <= 0.01:
			continue
		r.draw_set_transform(p["pos"] + p["drift"] * dt, p["ang"], Vector2(1.0, 1.7))
		r.draw_circle(Vector2.ZERO, rad, Color(FieldRenderer.FOAM.r, FieldRenderer.FOAM.g, FieldRenderer.FOAM.b, a))
	r.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
