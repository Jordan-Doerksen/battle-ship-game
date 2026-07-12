class_name WeatherRender
extends RefCounted
# C17 WEATHER FRONTS — the render-domain helper (the C9 split family). Ports the approved TEMPEST
# mockup's weather layers (design/the-tempest.html, gate 2026-07-12): wind-angled rain streaks,
# sea dimple rings, a visibility veil, and THUNDERHEAD lightning under hard photosensitivity caps
# (flash ≤ 0.16 alpha, ≥ 4 s between strikes, bolts pre-jagged so nothing shimmers frame to frame).
# Reads world.wx_state + the WeatherConfig render tables ONE-WAY; all randomness is r._srng
# (cosmetic — never world.rng). Strike timing/placement lives HERE, not in the sim: lightning is
# spectacle by owner decision, so the sim never knows a bolt happened.
#
# reduced_motion law: streaks, dimples, and the flash DIE; the static veil and the strike-point
# water glow stay (they carry the state without motion or flashing).

const DROPS: int = 240            # streak pool (density scales how many draw)
const FLASH_CAP: float = 0.16     # WCAG guard — the full-screen lift never exceeds this alpha
const BOLT_MIN_GAP: float = 4.0   # hard floor between strikes, whatever the config period says

static func draw(r: FieldRenderer) -> void:
	var w: GameWorld = r._world
	var wc: WeatherConfig = r._cfgs.weather
	var state: String = w.wx_state
	var rain: float = float(wc.rain_amount.get(state, 0.0))
	var veil: float = float(wc.veil_amount.get(state, 0.0))
	var wind: float = float(wc.wind_amount.get(state, 0.25))
	var reduced: bool = r._field_cfg.reduced_motion
	var wx: Dictionary = _state(r)
	var view: Rect2 = r.view_rect()
	var now_ms: int = Time.get_ticks_msec()
	if state == "clear":
		wx["flash"] = 0.0
		wx["bolts"].clear()
		wx["dimples"].clear()
		return
	# ── sea dimples: short-lived rings where drops land (world-space, sparse) ──
	if not reduced and rain > 0.02:
		for k in range(int(ceil(rain * 3.0))):
			if r._srng.randf() < rain * 0.8:
				wx["dimples"].append({ "pos": Vector2(view.position.x + r._srng.randf() * view.size.x,
					view.position.y + r._srng.randf() * view.size.y), "t0": now_ms })
		while wx["dimples"].size() > 130:
			wx["dimples"].pop_front()
		for d in wx["dimples"]:
			var age: float = float(now_ms - int(d["t0"])) / 500.0
			if age >= 1.0:
				continue
			r.draw_arc(d["pos"], 0.6 + age * 3.2, 0.0, TAU, 10,
				Color(0.894, 0.941, 0.949, 0.22 * (1.0 - age)), r.lw(1.0), true)
		while wx["dimples"].size() > 0 and float(now_ms - int(wx["dimples"][0]["t0"])) >= 500.0:
			wx["dimples"].pop_front()
	# ── lightning: seeded-cosmetic strike clock; bolt + water glow + capped flash ──
	if state == "thunder":
		wx["flash"] = float(wx["flash"]) * exp(-0.15)   # per-frame decay ≈ exp(-9·dt) at 60 fps
		if now_ms >= int(wx["next_bolt_ms"]):
			var period: float = maxf(BOLT_MIN_GAP, wc.bolt_period) * (0.7 + r._srng.randf() * 0.7)
			wx["next_bolt_ms"] = now_ms + int(period * 1000.0)
			var ang: float = r._srng.randf() * TAU
			var dist: float = 260.0 + r._srng.randf() * 420.0
			var segs: Array = []
			for s in range(7):
				segs.append((r._srng.randf() - 0.5) * 92.0)   # pre-rolled jag — no per-frame shimmer
			wx["bolts"].append({ "pos": w.ship_pos + Vector2(sin(ang), -cos(ang)) * dist,
				"t0": now_ms, "segs": segs, "branch": 2 + (r._srng.randi() % 2) })
			if not reduced:
				wx["flash"] = 1.0
		for i in range(wx["bolts"].size() - 1, -1, -1):
			var b: Dictionary = wx["bolts"][i]
			var age: float = float(now_ms - int(b["t0"])) / 1000.0
			if age > 1.1:
				wx["bolts"].remove_at(i)
				continue
			var bp: Vector2 = b["pos"]
			if age < 0.9:   # strike-point water glow + ring (stays under reduced motion)
				var kk: float = age / 0.9
				r.draw_circle(bp, 60.0, Color(0.82, 0.9, 0.92, 0.10 * (1.0 - kk)))
				r.draw_arc(bp, 4.0 + 40.0 * kk, 0.0, TAU, 24,
					Color(0.894, 0.941, 0.949, 0.4 * (1.0 - kk)), r.lw(1.2), true)
			if reduced or age > 0.26:
				continue
			var a: float = 1.0 - age / 0.26   # the bolt itself — two frames of sky
			var up: float = view.size.y * 0.075
			for wpass in [[3.4, 0.18], [1.4, 0.8]]:
				var pts := PackedVector2Array([bp])
				var bx: float = bp.x
				for s in range(7):
					bx = bp.x + float(b["segs"][s])
					pts.append(Vector2(bx, bp.y - float(s + 1) * up))
				r.draw_polyline(pts, Color(0.894, 0.941, 0.949, float(wpass[1]) * a), r.lw(float(wpass[0])))
	else:
		wx["flash"] = 0.0
		wx["bolts"].clear()
	# ── rain streaks: screen-anchored pool scrolled by the wind vector (world-space draw) ──
	if not reduced and rain > 0.02:
		var bearing: float = 205.0 * PI / 180.0             # the TEMPEST rail default wind bearing
		var spd: float = (620.0 + 520.0 * wind) / maxf(r.zoom(), 0.001) * 0.001   # world-u per ms
		var vx: float = sin(bearing) * spd
		var vy: float = cos(bearing) * spd
		var n: int = int(float(DROPS) * rain)
		var drops: Array = wx["drops"]
		for i in range(n):
			var dr: Dictionary = drops[i]
			var px: float = view.position.x + fposmod(float(dr["u"]) * view.size.x + float(now_ms) * vx * float(dr["s"]), view.size.x)
			var py: float = view.position.y + fposmod(float(dr["v"]) * view.size.y + float(now_ms) * vy * float(dr["s"]), view.size.y)
			var al: float = 0.05 + 0.11 * rain
			r.draw_line(Vector2(px, py), Vector2(px - vx * 14.0 * float(dr["s"]) * 1000.0 * 0.014,
				py - vy * 14.0 * float(dr["s"]) * 1000.0 * 0.014),
				Color(0.894, 0.941, 0.949, al), r.lw(1.0))
	# ── the veil + the capped flash — always last, over everything ──
	if veil > 0.01:
		r.draw_rect(view, Color(0.023, 0.063, 0.086, veil * 0.38))
	var flash_a: float = minf(FLASH_CAP, float(wx["flash"]) * FLASH_CAP)
	if not reduced and flash_a > 0.01:
		r.draw_rect(view, Color(0.82, 0.9, 0.92, flash_a))

# Lazily build the render-side pool on the host (the C9 split pattern: state lives on FieldRenderer).
static func _state(r: FieldRenderer) -> Dictionary:
	if not r._wx.has("drops"):
		var drops: Array = []
		for i in range(DROPS):
			drops.append({ "u": r._srng.randf(), "v": r._srng.randf(), "s": 0.75 + r._srng.randf() * 0.5 })
		r._wx = { "drops": drops, "dimples": [], "bolts": [], "flash": 0.0, "next_bolt_ms": 0 }
	return r._wx
