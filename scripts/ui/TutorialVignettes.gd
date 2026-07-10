class_name TutorialVignettes
extends RefCounted
# The manual's nine live vignettes (C13) — hand-animated loops in the game's own art language,
# staged with TutorialScreen's prop shop (the ShipRender→FieldRenderer host pattern: statics
# drawing through `s`). No sim worlds: every loop is a closed-form function of the page clock
# `t`, and all jitter comes from s._hash() of a shot index — never randf. The same film plays
# every time; under reduced motion TutorialScreen holds the clock and these become stills.

const FOAM := Color(0.894, 0.941, 0.949)
const RED := Color(0.851, 0.310, 0.169)
const ORANGE := Color(0.914, 0.404, 0.259)
const BRASS := Color(0.804, 0.729, 0.557)
const BRASS_DIM := Color(0.557, 0.506, 0.373)
const FLASH := Color(0.910, 0.706, 0.431)
const DARK := Color(0.094, 0.165, 0.212)

static func draw_page(s: TutorialScreen, page: int, r: Rect2, t: float) -> void:
	match page:
		0: _helm(s, r, t)
		1: _batteries(s, r, t)
		2: _longrange(s, r, t)
		3: _crewed(s, r, t)
		4: _deep(s, r, t)
		5: _torpedo(s, r, t)
		6: _airwing(s, r, t)
		7: _machines(s, r, t)
		8: _scope(s, r, t)

# ── 1 · THE HELM — an S-course carve; keys read off the path's own derivatives ──
static func _helm_pos(c: Vector2, tt: float) -> Vector2:
	return c + Vector2(sin(tt * 0.5) * 250.0, sin(tt * 1.0) * 52.0)   # closed lissajous, ~12.6 s

static func _helm(s: TutorialScreen, r: Rect2, t: float) -> void:
	var c := r.get_center() + Vector2(0, -18.0)
	var pos := _helm_pos(c, t)
	var d := _helm_pos(c, t + 0.06) - _helm_pos(c, t - 0.06)
	for wk in range(26):   # wake astern, sampled back along the same path
		var wp := _helm_pos(c, t - 0.22 * float(wk + 1))
		s.draw_circle(wp, 1.1 + wk * 0.10, Color(FOAM.r, FOAM.g, FOAM.b, 0.34 * (1.0 - float(wk) / 26.0)))
	s._ship(pos, d.angle() + PI * 0.5, 0.55)
	# ghost inputs: rudder from the turn rate, brake from the speed trend — momentum made visible
	var d2 := _helm_pos(c, t + 0.26) - _helm_pos(c, t + 0.14)
	var turn := wrapf(d2.angle() - d.angle(), -PI, PI)
	var v_now := (pos - _helm_pos(c, t - 0.2)).length()
	var v_next := (_helm_pos(c, t + 0.2) - pos).length()
	var braking := v_next < v_now * 0.985
	var kx := r.get_center().x
	var ky := r.end.y - 26.0
	s._key(Vector2(kx - 26.0, ky), "A", turn < -0.02)
	s._key(Vector2(kx, ky - 26.0), "W", not braking)
	s._key(Vector2(kx, ky), "S", braking)
	s._key(Vector2(kx + 26.0, ky), "D", turn > 0.02)

# ── 2 · THE BATTERIES — turrets slew to a wandering cursor; orders cycle ALL → MAIN → SEC ──
static func _mount_on(phase: int, cls: String) -> bool:
	return phase == 0 or (phase == 1 and cls == "L") or (phase == 2 and cls != "L")

static func _batteries(s: TutorialScreen, r: Rect2, t: float) -> void:
	var c := r.get_center()
	var hp := c + Vector2(-200.0, 10.0)
	s._ship(hp, 0.0, 1.05)
	# the cursor weaves the right half; barrels track it half a beat behind (guns, not lasers)
	var cur := c + Vector2(150.0 + sin(t * 0.55) * 110.0, sin(t * 0.85) * 88.0)
	var lag := c + Vector2(150.0 + sin((t - 0.45) * 0.55) * 110.0, sin((t - 0.45) * 0.85) * 88.0)
	var phase := int(fposmod(t, 18.0) / 6.0)          # 0 ALL · 1 MAIN · 2 SECONDARIES
	var u := clampf(fposmod(t, 6.0) / 0.9, 0.0, 1.0)   # slew-in after each order change
	var mounts := [
		{ "off": Vector2(0, -30), "cls": "L" }, { "off": Vector2(0, 34), "cls": "L" },
		{ "off": Vector2(0, 6), "cls": "M" },
		{ "off": Vector2(-9, -8), "cls": "S" }, { "off": Vector2(9, -8), "cls": "S" },
	]
	for m in mounts:
		var mp: Vector2 = hp + m["off"]
		var cls := String(m["cls"])
		var on_now := _mount_on(phase, cls)
		var was_on := _mount_on((phase + 2) % 3, cls)
		var aim := (lag - mp).angle() + PI * 0.5
		var a := aim if on_now else 0.0
		if on_now != was_on:
			a = lerp_angle(aim if was_on else 0.0, a, u)
		s._turret(mp, a, cls, on_now)
		if on_now and u >= 1.0:
			for pj in range(3):   # tracer pulses walking the line to the point
				var f := fposmod(t * 1.7 + pj * 0.33, 1.0)
				s.draw_circle(mp.lerp(cur, 0.12 + f * 0.85), 1.5,
					Color(FOAM.r, FOAM.g, FOAM.b, 0.7 * (1.0 - f * 0.6)))
	s._reticle(cur, true)
	var cy := r.end.y - 22.0
	s._chip(Vector2(c.x - 60.0, cy), "LMB", phase == 0)
	s._chip(Vector2(c.x, cy), "RMB", phase == 1)
	s._chip(Vector2(c.x + 60.0, cy), "MMB", phase == 2)
	s._micro(Vector2(c.x - 64.0, cy - 22.0), String(["ALL GUNS", "MAIN BATTERY", "SECONDARIES"][phase]) + " ON POINT")

# ── 3 · LONG-RANGE FIRE — three salvos: short, straddle, ON. Read the splashes. ──
static func _longrange(s: TutorialScreen, r: Rect2, t: float) -> void:
	var c := r.get_center()
	var ship := c + Vector2(-300.0, 58.0)
	s._ship(ship, PI * 0.5, 0.5)
	for seg in range(20):   # the 900-unit burst line — dashed brass, past it shells fly the bearing
		if seg % 2 == 0:
			s.draw_arc(ship, 210.0, -0.55 + 0.85 * seg / 20.0, -0.55 + 0.85 * (seg + 1) / 20.0, 4,
				Color(BRASS.r, BRASS.g, BRASS.b, 0.4), 1.0, true)
	s._micro(ship + Vector2(172.0, -122.0), "900 U")
	var boat := c + Vector2(238.0, -52.0)
	var cyc := int(fposmod(t, 12.0) / 4.0)
	var ts := fposmod(t, 4.0)
	s._gunboat(boat, PI * 0.5, 1.2)
	if cyc == 2 and ts >= 1.4 and ts < 2.2:   # the hit lands
		s.draw_arc(boat, 6.0 + (ts - 1.4) * 30.0, 0.0, TAU, 24,
			Color(RED.r, RED.g, RED.b, 0.9 * (1.0 - (ts - 1.4) / 0.8)), 2.0, true)
	s._reticle(boat + Vector2(4.0, 2.0), true)
	if ts < 0.12:   # the salvo leaves
		s.draw_circle(ship + Vector2(18.0, -6.0), 5.0, Color(FLASH.r, FLASH.g, FLASH.b, 0.9))
	var offs := [[Vector2(-64, 26), Vector2(-80, -2)], [Vector2(-34, 18), Vector2(40, -14)],
		[Vector2(2, 1), Vector2(-6, 6)]]
	for sh in range(2):
		var ip: Vector2 = boat + offs[cyc][sh] \
			+ Vector2(s._hash(cyc * 7.0 + sh) - 0.5, s._hash(cyc * 13.0 + sh) - 0.5) * 10.0
		var frac := ts / 1.4
		if frac < 1.0:   # shells on the wing
			var sp := ship.lerp(ip, clampf(frac + sh * 0.04, 0.0, 1.0))
			s.draw_circle(sp, 2.2, Color(FOAM.r, FOAM.g, FOAM.b, 0.95))
			s.draw_line(sp - (ip - ship).normalized() * 7.0, sp, Color(FOAM.r, FOAM.g, FOAM.b, 0.35), 1.4)
		else:
			s._splash(ip, 10.0 if cyc == 2 else 15.0, ts - 1.4 - sh * 0.1)
	s._micro(Vector2(c.x - 34.0, r.end.y - 14.0), String(["SHORT", "STRADDLE", "ON — HIT"][cyc]))

# ── 4 · THE CREWED GUNS — bursts that miss like humans; the stitch walks onto the raft ──
static func _crewed(s: TutorialScreen, r: Rect2, t: float) -> void:
	var c := r.get_center()
	var gun := c + Vector2(-268.0, 46.0)
	var raft := c + Vector2(226.0, -34.0)
	s._turret(gun, (raft - gun).angle() + PI * 0.5, "S", false)
	s._micro(gun + Vector2(-16.0, 28.0), "20 MM")
	s.draw_set_transform(raft, 0.35, Vector2.ONE)   # the raft — a low dark hulk worth arranging
	s.draw_colored_polygon(PackedVector2Array([
		Vector2(-14, -6), Vector2(14, -6), Vector2(10, 7), Vector2(-10, 7),
	]), Color(0.118, 0.180, 0.212))
	s.draw_polyline(PackedVector2Array([
		Vector2(-14, -6), Vector2(14, -6), Vector2(10, 7), Vector2(-10, 7), Vector2(-14, -6),
	]), Color(RED.r, RED.g, RED.b, 0.8), 1.2, true)
	s.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# phase-shifted so the reduced-motion still lands mid-burst
	var cyc := int((t + 1.2) / 6.0) % 4
	var tb := fposmod(t + 1.2, 6.0)
	var shots := 20
	var cur := int(tb * 12.0)   # 12 rounds a second while the burst runs
	for j in range(mini(cur + 1, shots)):
		var age := tb - float(j) / 12.0
		if age < 0.0:
			continue
		var spread := lerpf(52.0, 7.0, float(j) / float(shots - 1))   # human error, tightening
		var jx := (s._hash(float(j) + cyc * 31.0) - 0.5) * 2.0
		var jy := (s._hash(float(j) * 3.7 + cyc * 17.0) - 0.5) * 2.0
		var ip := raft + Vector2(jx, jy) * spread
		if age < 0.09:   # the tracer itself — thin, hot, brass (the aa20 language)
			s.draw_line(gun + (ip - gun).normalized() * 16.0, ip, Color(BRASS.r, BRASS.g, BRASS.b, 0.9), 1.2)
		if ip.distance_to(raft) < 11.0:
			if age < 0.25:   # a hit, arranged
				s.draw_circle(ip, 3.0, Color(FLASH.r, FLASH.g, FLASH.b, 0.9 * (1.0 - age / 0.25)))
		elif age < 1.3:      # a miss stitching the water
			s.draw_circle(ip, 2.6 + age * 2.0, Color(FOAM.r, FOAM.g, FOAM.b, 0.4 * (1.0 - age / 1.3)))
	if cur >= shots:
		s._micro(gun + Vector2(-22.0, -22.0), "RELOADING · · ·")

# ── 5 · THE DEEP — ripple, ping, latch, drive over the diamond, the racks do the rest ──
static func _deep(s: TutorialScreen, r: Rect2, t: float) -> void:
	var c := r.get_center()
	var tt := fposmod(t, 16.0)
	var sub := c + Vector2(44.0, 10.0)
	var x0 := r.position.x + 44.0
	var ship := Vector2(x0 + tt * 46.0, sub.y)
	var t_latch := (sub.x - 126.0 - x0) / 46.0
	var t_cross := (sub.x - x0) / 46.0
	var sunk01 := clampf((tt - t_cross - 2.4) / 1.2, 0.0, 1.0)
	if tt < t_latch:   # unheard: only the water moving wrong (the HostileRender ripple tell)
		var wob := sin(t * 3.0) * 3.0
		s.draw_arc(sub, 14.0 + wob, 0.0, TAU, 24, Color(FOAM.r, FOAM.g, FOAM.b, 0.10), 1.4, true)
		s.draw_arc(sub, 24.0 - wob, 0.0, TAU, 28, Color(FOAM.r, FOAM.g, FOAM.b, 0.07), 1.4, true)
	else:
		s._sub(sub, PI * 0.5, 1.0 - sunk01)
	var ship_on := ship.x < r.end.x - 30.0
	if ship_on:
		s._ship(ship, PI * 0.5, 0.5)
		var pk := fposmod(tt, 2.5) / 2.5   # the ping — 350 units of hearing, sweeping off the hull
		s.draw_arc(ship, maxf(2.0, 126.0 * pk), 0.0, TAU, 40,
			Color(FOAM.r, FOAM.g, FOAM.b, 0.30 * (1.0 - pk)), 1.2, true)
		s.draw_arc(ship, 126.0, 0.0, TAU, 48, Color(FOAM.r, FOAM.g, FOAM.b, 0.10), 1.0, true)
		s._micro(ship + Vector2(92.0, -92.0), "SONAR 350 U")
	if tt >= t_latch and sunk01 < 1.0:   # the latch: the diamond snaps on and holds
		var la := clampf((tt - t_latch) / 0.5, 0.0, 1.0)
		s._diamond(sub, 34.0 - 22.0 * la, Color(FOAM.r, FOAM.g, FOAM.b, (0.4 + 0.55 * la) * (1.0 - sunk01)), 1.6)
		s._micro(sub + Vector2(20.0, -28.0), "CONTACT — RACKS ARMED")
	for ci in range(3):   # the crossing: charges roll, sink, and speak underwater
		var dage := tt - (t_cross - 0.25 + ci * 0.28)
		var dp := sub + Vector2(-14.0 + ci * 14.0, -8.0 + (ci % 2) * 16.0)
		if dage >= 0.0 and dage < 1.4:   # sinking: shrinking dot, spreading ring (FxRender dc)
			var k := dage / 1.4
			s.draw_circle(dp, 3.5 - k * 2.0, Color(FOAM.r, FOAM.g, FOAM.b, 0.7 - k * 0.4))
			s.draw_arc(dp, 5.0 + k * 6.0, 0.0, TAU, 16, Color(FOAM.r, FOAM.g, FOAM.b, 0.3 - k * 0.2), 1.0, true)
		elif dage >= 1.4 and dage < 2.3:   # the underwater bulge — pale dome, dark ring chasing
			var bk := (dage - 1.4) / 0.9
			s.draw_circle(dp, 26.0 * (0.3 + bk * 0.7), Color(FOAM.r, FOAM.g, FOAM.b, 0.35 * (1.0 - bk)))
			s.draw_arc(dp, maxf(0.5, 26.0 * bk), 0.0, TAU, 24, Color(DARK.r, DARK.g, DARK.b, 0.8 * (1.0 - bk)), 2.5, true)
	if sunk01 > 0.0 and sunk01 < 1.0:
		s.draw_arc(sub, 10.0 + 30.0 * sunk01, 0.0, TAU, 24, Color(RED.r, RED.g, RED.b, 0.8 * (1.0 - sunk01)), 2.0, true)

# ── 6 · TORPEDOES — the wake is the warning; the bow comes onto it, the run slides astern ──
static func _torpedo(s: TutorialScreen, r: Rect2, t: float) -> void:
	var c := r.get_center()
	var tt := fposmod(t, 10.0)
	var ship := c + Vector2(-150.0 + tt * 13.0, 40.0 - tt * 2.0)
	var torp0 := c + Vector2(330.0, -104.0)
	var tdir := (c + Vector2(-208.0, 84.0) - torp0).normalized()   # laid across the ship's OLD track
	var torp := torp0 + tdir * maxf(0.0, tt - 0.8) * 85.0
	var face := (torp0 - ship).angle() + PI * 0.5                  # bow onto the incoming run
	s._ship(ship, lerp_angle(PI * 0.5 - 0.15, face, smoothstep(3.2, 5.6, tt)), 0.62)
	if tt > 0.8 and torp.x > r.position.x + 10.0:
		for wq in range(1, 10):   # the LAMPREY's wake — the warning you get
			var wp := torp - tdir * (wq * 13.0)
			if wp.x > r.position.x + 6.0 and wp.x < r.end.x - 6.0:
				s.draw_circle(wp, 1.4 + wq * 0.3, Color(FOAM.r, FOAM.g, FOAM.b, 0.5 - wq * 0.045))
		s.draw_circle(torp, 3.0, DARK)
		s.draw_arc(torp, 3.0, 0.0, TAU, 12, Color(ORANGE.r, ORANGE.g, ORANGE.b, 0.8), 1.0, true)
		s._micro(torp0 + Vector2(-70.0, -8.0), "LAMPREY")
	if torp.distance_to(ship) < 52.0:   # the pass: churn where the miss goes by, astern
		s.draw_arc((torp + ship) * 0.5, 10.0 + s._hash(floor(t)) * 3.0, 0.0, TAU, 16,
			Color(FOAM.r, FOAM.g, FOAM.b, 0.35), 1.2, true)

# ── 7 · THE AIR WING — the bird dips, marks, softens; the stern racks close the account ──
static func _airwing(s: TutorialScreen, r: Rect2, t: float) -> void:
	var c := r.get_center()
	var tt := fposmod(t, 14.0)
	var hover := c + Vector2(128.0, -22.0)
	var mark := hover + Vector2(8.0, 34.0)
	var weave := c + Vector2(-60.0 + tt * 52.0, -46.0 + sin(tt * 1.6) * 26.0)
	var hp := weave.lerp(hover, smoothstep(2.6, 3.8, tt))
	var hang := ((hover - weave).angle() + PI * 0.5) if tt < 3.8 else PI * 0.5
	if tt >= 3.8 and tt < 11.0:   # the dip: ears in the water
		var dk := fposmod(tt, 1.4) / 1.4
		s.draw_arc(hp, maxf(1.0, 46.0 * dk), 0.0, TAU, 32, Color(FOAM.r, FOAM.g, FOAM.b, 0.25 * (1.0 - dk)), 1.2, true)
		s.draw_arc(hp, 46.0, 0.0, TAU, 32, Color(FOAM.r, FOAM.g, FOAM.b, 0.10), 1.0, true)
	var sunk01 := clampf((tt - 12.2) / 1.0, 0.0, 1.0)
	if tt >= 5.0:   # the mark
		var la := clampf((tt - 5.0) / 0.5, 0.0, 1.0)
		s._diamond(mark, 30.0 - 19.0 * la, Color(FOAM.r, FOAM.g, FOAM.b, (0.4 + 0.55 * la) * (1.0 - sunk01)), 1.6)
		if sunk01 <= 0.0:
			s._micro(mark + Vector2(16.0, 22.0), "MARKED")
	for di in range(2):   # two light drops soften it
		var dage := tt - (6.4 + di * 1.3)
		var dp := mark + Vector2(-8.0 + di * 16.0, -6.0 + di * 10.0)
		if dage >= 0.0 and dage < 0.5:
			s.draw_arc(hp.lerp(dp, dage / 0.5), 3.0, 0.0, TAU, 12, Color(FOAM.r, FOAM.g, FOAM.b, 0.8), 1.0, true)
		elif dage >= 0.5 and dage < 1.3:
			var bk := (dage - 0.5) / 0.8
			s.draw_circle(dp, 14.0 * (0.3 + bk * 0.7), Color(FOAM.r, FOAM.g, FOAM.b, 0.3 * (1.0 - bk)))
			s.draw_arc(dp, maxf(0.5, 14.0 * bk), 0.0, TAU, 20, Color(DARK.r, DARK.g, DARK.b, 0.7 * (1.0 - bk)), 2.0, true)
	if tt >= 8.0:   # the ship arrives over the mark
		var shipx := minf(r.position.x + 30.0 + (tt - 8.0) * 120.0, mark.x)
		s._ship(Vector2(shipx, mark.y), PI * 0.5, 0.5)
	for bi in range(2):   # the stern racks finish what it starts
		var bage := tt - (11.8 + bi * 0.35)
		if bage >= 0.0 and bage < 0.9:
			var kk := bage / 0.9
			var bp := mark + Vector2(-10.0 + bi * 20.0, 4.0 - bi * 8.0)
			s.draw_circle(bp, 24.0 * (0.3 + kk * 0.7), Color(FOAM.r, FOAM.g, FOAM.b, 0.35 * (1.0 - kk)))
			s.draw_arc(bp, maxf(0.5, 24.0 * kk), 0.0, TAU, 24, Color(DARK.r, DARK.g, DARK.b, 0.8 * (1.0 - kk)), 2.5, true)
	if sunk01 > 0.0 and sunk01 < 1.0:
		s.draw_arc(mark, 8.0 + 26.0 * sunk01, 0.0, TAU, 24, Color(RED.r, RED.g, RED.b, 0.8 * (1.0 - sunk01)), 2.0, true)
	s._helo(hp, hang, t)

# ── 8 · THE MACHINES — parts char out one by one; the core ring brightens; then the bloom ──
static func _machines(s: TutorialScreen, r: Rect2, t: float) -> void:
	var c := r.get_center()
	var tt := fposmod(t, 16.0)
	var jug := c + Vector2(118.0, 4.0)
	var ang := -PI * 0.5   # nosed into the incoming fire
	var deaths := [3.5, 7.0, 10.5]
	var dead_n := 0
	for di in range(3):
		if tt >= float(deaths[di]):
			dead_n += 1
	var core_kill := tt >= 14.0
	var ma := 1.0 - clampf((tt - 14.2) / 1.0, 0.0, 1.0)   # the wreck fades under the bloom
	if ma > 0.0:
		s.draw_set_transform(jug, ang, Vector2.ONE * 0.75)
		var hull := PackedVector2Array([
			Vector2(0, -56), Vector2(16, -34), Vector2(18, 30), Vector2(10, 52),
			Vector2(-10, 52), Vector2(-18, 30), Vector2(-16, -34),
		])
		s.draw_colored_polygon(hull, Color(0.075, 0.122, 0.153, ma))
		var hc := PackedVector2Array(hull)
		hc.append(hull[0])
		s.draw_polyline(hc, Color(RED.r, RED.g, RED.b, 0.85 * ma), 1.6, true)
		s.draw_rect(Rect2(-10, -18, 20, 34), Color(0.133, 0.2, 0.243, ma))
		s.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var parts := [Vector2(0, -38), Vector2(0, 2), Vector2(0, 40)]
	var roles := ["GUN", "GUN", "DIRECTOR"]
	if ma > 0.0:
		for pi in range(3):
			var pp: Vector2 = jug + (parts[pi] * 0.75).rotated(ang)
			if tt >= float(deaths[pi]):   # charred out (the HostileRender part-death language)
				s.draw_circle(pp, 8.0, Color(0.039, 0.063, 0.078, 0.9 * ma))
				s.draw_line(pp + Vector2(-5, -5), pp + Vector2(5, 5), Color(BRASS_DIM.r, BRASS_DIM.g, BRASS_DIM.b, 0.4 * ma), 1.0)
				s.draw_line(pp + Vector2(5, -5), pp + Vector2(-5, 5), Color(BRASS_DIM.r, BRASS_DIM.g, BRASS_DIM.b, 0.4 * ma), 1.0)
				var sm := fposmod(t * 0.9 + pi * 0.4, 1.0)
				s.draw_circle(pp + Vector2(sm * 5.0, -sm * 13.0), 2.5 + sm * 4.0,
					Color(0.157, 0.196, 0.22, 0.5 * (1.0 - sm) * ma))
				var da := tt - float(deaths[pi])
				if da < 0.6:   # the partdown ring
					s.draw_arc(pp, 6.0 + 34.0 * da / 0.6, 0.0, TAU, 24,
						Color(FLASH.r, FLASH.g, FLASH.b, 0.9 * (1.0 - da / 0.6)), 2.0, true)
			else:
				var hurt := clampf((tt - (float(deaths[pi]) - 3.5)) / 3.5, 0.0, 1.0)
				s.draw_circle(pp, 9.0, Color(0.173, 0.251, 0.282, ma))
				s.draw_arc(pp, 9.0, 0.0, TAU, 20, Color(RED.r, RED.g, RED.b, (0.4 + 0.5 * hurt) * ma), 1.5, true)
				s._micro(pp + Vector2(13.0, 3.0), String(roles[pi]))
		# the core: soft-gated — its ring brightens as the parts fall
		s.draw_arc(jug, 14.0, 0.0, TAU, 24, Color(RED.r, RED.g, RED.b, (0.25 + 0.25 * dead_n) * ma), 2.0, true)
		if dead_n == 3 and not core_kill:
			s._micro(jug + Vector2(18.0, -12.0), "CORE — SOFT")
	if not core_kill:   # incoming fire walks part to part (the player is off-frame left)
		var tgt: Vector2 = jug if dead_n == 3 else jug + (parts[dead_n] * 0.75).rotated(ang)
		var org := Vector2(r.position.x + 8.0, c.y + 40.0)
		for tj in range(3):
			var f := fposmod(t * 2.0 + tj * 0.33, 1.0)
			s.draw_circle(org.lerp(tgt, f), 1.6, Color(FOAM.r, FOAM.g, FOAM.b, 0.75 * (1.0 - f * 0.5)))
			if f > 0.93:
				s.draw_circle(tgt, 2.6, Color(FLASH.r, FLASH.g, FLASH.b, 0.8))
	else:   # the kill — a bossdown-scale bloom, sized to the panel
		var kk := clampf((tt - 14.0) / 1.6, 0.0, 1.0)
		for ring in range(3):
			var rk := maxf(0.0, kk - ring * 0.12)
			s.draw_arc(jug, 10.0 + 105.0 * rk, 0.0, TAU, 40,
				Color(RED.r, RED.g, RED.b, 0.9 * (1.0 - rk)), 4.0 - ring, true)

# ── 9 · THE SCOPE — each ring takes the floor in turn, then the war shows up on it ──
static func _scope_label(s: TutorialScreen, p: Vector2, text: String, hot: bool) -> void:
	s.draw_string(s.mono, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
		FOAM if hot else Color(BRASS_DIM.r, BRASS_DIM.g, BRASS_DIM.b, 0.75))

static func _scope(s: TutorialScreen, r: Rect2, t: float) -> void:
	var c := r.get_center()
	var tt := fposmod(t, 16.0)
	var rr := 118.0
	s.draw_circle(c, rr, Color(0.031, 0.094, 0.125, 0.95))
	s.draw_arc(c, rr, 0.0, TAU, 64, Color(BRASS.r, BRASS.g, BRASS.b, 0.5), 1.2, true)
	var seg := int(tt / 2.6) if tt < 10.4 else -1
	var pulse := 0.5 + 0.5 * sin(t * 6.0)
	s.draw_circle(c, 46.0, Color(FOAM.r, FOAM.g, FOAM.b, 0.05))   # solid foam — the ears
	s.draw_arc(c, 46.0, 0.0, TAU, 40, Color(FOAM.r, FOAM.g, FOAM.b, 0.28 + (0.5 * pulse if seg == 0 else 0.0)), 1.2, true)
	s._dashed_ring(c, 64.0, Color(FOAM.r, FOAM.g, FOAM.b, 0.45 + (0.5 * pulse if seg == 1 else 0.0)))   # racks
	s._dashed_ring(c, 96.0, Color(BRASS.r, BRASS.g, BRASS.b, 0.35 + (0.55 * pulse if seg == 2 else 0.0)))   # 16-in
	s.draw_rect(Rect2(c.x - 78.0, c.y - 47.0, 156.0, 94.0),
		Color(FOAM.r, FOAM.g, FOAM.b, 0.16 + (0.5 * pulse if seg == 3 else 0.0)), false, 1.0)   # what you see
	_scope_label(s, c + Vector2(4.0, -50.0), "SONAR", seg == 0)
	_scope_label(s, c + Vector2(-98.0, 4.0), "DC", seg == 1)
	_scope_label(s, c + Vector2(4.0, -100.0), "16-IN", seg == 2)
	_scope_label(s, c + Vector2(-74.0, -51.0), "VIEW", seg == 3)
	var sw := fposmod(t * 1.4, TAU)   # the sweep
	s.draw_line(c, c + Vector2(sin(sw), -cos(sw)) * rr, Color(BRASS.r, BRASS.g, BRASS.b, 0.3), 1.0)
	s.draw_line(c + Vector2(0, 4.0), c + Vector2(0, -7.0), FOAM, 1.6)   # own ship
	s.draw_circle(c, 2.0, FOAM)
	if tt >= 10.4:   # then the war shows up: blips, and a torpedo dash flying its run
		var ba := clampf((tt - 10.4) / 0.6, 0.0, 1.0)
		s.draw_rect(Rect2(c.x + 67.2, c.y - 42.8, 5.6, 5.6), Color(RED.r, RED.g, RED.b, ba))       # gunboat
		s.draw_circle(c + Vector2(-84.0, 30.0), 3.6, Color(RED.r, RED.g, RED.b, ba))               # bomber
		s.draw_circle(c + Vector2(52.0, 66.0), 2.4, Color(ORANGE.r, ORANGE.g, ORANGE.b, ba))       # swarmer
		var dp := c + Vector2(-20.0, 34.0)   # a sub diamond, inside the ears where it belongs
		s.draw_colored_polygon(PackedVector2Array([
			dp + Vector2(0, -4), dp + Vector2(4, 0), dp + Vector2(0, 4), dp + Vector2(-4, 0),
		]), Color(FOAM.r, FOAM.g, FOAM.b, 0.95 * ba))
		var tk := clampf((tt - 11.2) / 3.6, 0.0, 1.0)
		if tk > 0.0 and tk < 1.0:
			var t0 := c + Vector2(104.0, 44.0)
			var dv := (Vector2(-96.0, -52.0) - Vector2(104.0, 44.0)).normalized()
			var tp := t0.lerp(c + Vector2(-96.0, -52.0), tk)
			s.draw_line(tp - dv * 3.5, tp + dv * 3.5, Color(FOAM.r, FOAM.g, FOAM.b, 0.95), 2.0)
			var perp := Vector2(-dv.y, dv.x)
			for si in range(2):
				var jj := (s._hash(floor(t * 15.0) + si * 17.0) - 0.5) * 2.4
				var sp := tp - dv * (5.0 + 4.5 * float(si + 1)) + perp * jj
				s.draw_rect(Rect2(sp.x - 0.7, sp.y - 0.7, 1.4, 1.4),
					Color(FOAM.r, FOAM.g, FOAM.b, 0.65 - si * 0.25))
