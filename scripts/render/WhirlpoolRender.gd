class_name WhirlpoolRender
extends RefCounted
# C18 THE WHIRLPOOL — the render-domain helper (C9 split family). Ports the approved TEMPEST
# vortex (design/the-tempest.html, gate 2026-07-12): a subtle darkening well whose radius IS the
# influence radius (the art is the hitbox), three log-spiral arms of foam DASHES in the fleck
# language (rotation speed encodes the tide), a small eye, two circling debris motes. No giant
# hole, no glow, no in-world rings — restrained by decision. One-way reads; rotation rides the
# render sea clock (frozen under reduced motion, matching the sea itself).

static func draw(r: FieldRenderer) -> void:
	var w: GameWorld = r._world
	if w.vortex_pos.x == INF:
		return
	var wc: WhirlpoolConfig = r._cfgs.whirlpool
	var c: Vector2 = w.vortex_pos
	if not r.view_rect().grow(wc.radius + 40.0).has_point(c):
		return
	var vt: float = Whirlpool.tide(w, r._cfgs)
	var reduced: bool = r._field_cfg.reduced_motion
	var R: float = wc.radius
	# the darkening well — stepped fills stand in for a radial gradient; alpha rides the tide
	for s in range(4):
		var f: float = 1.0 - float(s) * 0.22
		r.draw_circle(c, R * 0.85 * f, Color(0.012, 0.039, 0.059, 0.028 + 0.075 * vt / 4.0 * float(s + 1)))
	# spiral arms as foam dashes; rotation speed encodes the tide (dormant = a lazy foam ring)
	var rot: float = 0.0 if reduced else r.sea_t * wc.spin * (0.3 + vt)
	for arm in range(3):
		var ph0: float = float(arm) * TAU / 3.0 + rot
		for i in range(24):
			var t: float = float(i) / 23.0
			var th: float = ph0 + t * 3.4
			var rr: float = R * (0.94 - 0.86 * t)
			var p: Vector2 = c + Vector2(sin(th), -cos(th)) * rr
			var a: float = (0.05 + 0.13 * t) * (0.35 + 0.65 * vt)
			var tg := Vector2(cos(th), sin(th))
			var half: float = 2.5 + 3.5 * (1.0 - t)
			r.draw_line(p - tg * half, p + tg * half, Color(0.894, 0.941, 0.949, a), r.lw(1.0))
	# the eye — small, never a hole
	r.draw_circle(c, 2.2, Color(0.894, 0.941, 0.949, 0.18 + 0.14 * vt))
	if not reduced:   # circling debris motes — they sell the current direction at a glance
		for m in range(2):
			var th2: float = rot * 2.2 + float(m) * PI
			var p2: Vector2 = c + Vector2(sin(th2), -cos(th2)) * R * (0.28 + 0.1 * float(m))
			r.draw_rect(Rect2(p2 - Vector2(1.5, 1.0), Vector2(3.0, 2.0)), Color(0.576, 0.655, 0.682, 0.55))
