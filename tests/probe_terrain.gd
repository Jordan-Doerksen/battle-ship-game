extends SceneTree
# C15 THE WATERS acceptance probe (run with `godot --headless -s tests/probe_terrain.gd`) — the
# land rules from DECISIONS.md's Change Log (2026-07-10) exercised headless against the real
# Sim/Terrain code. Six suites: seeded generation determinism, the placement law, ship grounding
# (speed-scaled grind cost), the projectile blocking matrix, waterborne avoidance sanity, and the
# open-water no-op (a world that never calls Terrain.generate steps exactly like pre-C15 — the
# older probes prove the same thing implicitly, this makes it explicit).

const DT: float = 1.0 / 60.0

func _initialize() -> void:
	var fails: int = 0

	# ── 1. determinism: same seed → identical archipelago + byte-identical downstream stepping ──
	var cfgs := Configs.defaults()
	var wa := GameWorld.new(151515)
	var wb := GameWorld.new(151515)
	Terrain.generate(wa, cfgs)
	Terrain.generate(wb, cfgs)
	var same: bool = wa.terrain.size() == wb.terrain.size() and wa.terrain.size() > 0
	if same:
		for i in range(wa.terrain.size()):
			var fa: Dictionary = wa.terrain[i]
			var fb: Dictionary = wb.terrain[i]
			if fa["pos"] != fb["pos"] or fa["r"] != fb["r"] or fa["islet"] != fb["islet"]:
				same = false
				break
	fails += _check(same, "generate: same seed yields identical terrain arrays (%d features)" % wa.terrain.size())
	for i in range(600):   # 10s of the REAL sim over the rocks: waves, steering, grinding
		var ru: float = 1.0 if i % 240 < 120 else -1.0
		wa.input.thrust = 1.0
		wa.input.rudder = ru
		wb.input.thrust = 1.0
		wb.input.rudder = ru
		Sim.step(wa, DT, cfgs)
		Sim.step(wb, DT, cfgs)
	fails += _check(wa.ship_pos == wb.ship_pos and wa.ship_heading == wb.ship_heading \
		and wa.rng.calls == wb.rng.calls and wa.hull == wb.hull and wa.kills == wb.kills,
		"determinism: 600 ticks over terrain leave two worlds byte-identical (calls=%d)" % wa.rng.calls)

	# ── 2. placement law: the start clearing and the min channel hold for every feature ──
	var tc: TerrainConfig = cfgs.terrain
	var law_ok: bool = true
	for f in wa.terrain:
		if (f["pos"] as Vector2).length() - f["r"] < tc.start_clear - 0.001:
			law_ok = false
	for i in range(wa.terrain.size()):
		for j in range(i + 1, wa.terrain.size()):
			var fi: Dictionary = wa.terrain[i]
			var fj: Dictionary = wa.terrain[j]
			if (fi["pos"] as Vector2).distance_to(fj["pos"]) - fi["r"] - fj["r"] < tc.gap_min - 0.001:
				law_ok = false
	fails += _check(law_ok, "placement law: no feature edge inside start_clear=%.0f, every gap >= %.0f" \
		% [tc.start_clear, tc.gap_min])

	# ── 3. ship collision: no penetration, slides, flank contact = 1 pip, slow contact = 0 ──
	var quiet := Configs.defaults()   # silence the director — grounding in isolation (probe_movement idiom)
	quiet.waves.base_budget = 0
	quiet.waves.budget_per_wave = 0
	quiet.waves.first_wave_delay = 1e12
	var w := GameWorld.new(1)
	var rock := { "pos": Vector2(25, -1600), "r": 40.0, "islet": false }
	w.terrain = [rock]
	var pen_ok: bool = true
	for i in range(int(25.0 / DT)):   # full ahead straight at the hand-placed rock
		w.input.thrust = 1.0
		Sim.step(w, DT, quiet)
		if _keel_dist(w, rock["pos"]) < rock["r"] + Hull.RADIUS - 0.5:
			pen_ok = false
	fails += _check(pen_ok, "grounding: keel capsule never penetrates the rock (post-step clearance held)")
	fails += _check(w.hull == quiet.waves.hull_pips - 1,
		"grounding: flank-speed contact costs exactly 1 pip, graced (hull=%d)" % w.hull)
	fails += _check(w.ship_pos.x < -5.0 and w.ship_pos.y < rock["pos"].y - rock["r"],
		"grounding: she slides off the contact normal and passes the rock (pos=%.0f,%.0f)" \
		% [w.ship_pos.x, w.ship_pos.y])
	w = GameWorld.new(2)
	w.terrain = [{ "pos": Vector2(0, -220), "r": 40.0, "islet": false }]
	for i in range(int(6.0 / DT)):   # short runway — the bow kisses the rock well under the grind threshold
		w.input.thrust = 1.0
		Sim.step(w, DT, quiet)
	fails += _check(w.hull == quiet.waves.hull_pips,
		"grounding: slow contact is friction, 0 pips (hull=%d)" % w.hull)

	# ── 4. the blocking matrix (the owner's land rule, verbatim in DECISIONS) ──
	w = GameWorld.new(3)
	w.terrain = [{ "pos": Vector2(0, -400), "r": 50.0, "islet": false }]
	Sim.step(w, DT, quiet)   # one step: Waves inits the hull pips
	var full: int = w.hull
	# gunboat shell — flat hostile fire dies on rock; the hull behind the island is untouched
	var res: Dictionary = _fly(w, quiet, "hostile", true, false, 0.0, Vector2(0, -800), Vector2(0, 0), 150.0)
	fails += _check(res["died"] and res["rockhit"] and w.hull == full and res["max_y"] < -430.0,
		"matrix: gunboat shell dies on the rock, hull untouched (y=%.0f)" % res["max_y"])
	# torpedo — always dies on rock, whoever dropped it
	res = _fly(w, quiet, "torpedo", true, false, 0.0, Vector2(0, -800), Vector2(0, 0), 130.0)
	fails += _check(res["died"] and res["rockhit"], "matrix: torpedo dies on the rock")
	# friendly mb16 forced shot — islands are hard cover BOTH ways (supersedes arc-over); no burst
	res = _fly(w, quiet, "mb16", false, false, 30.0, Vector2(0, 0), Vector2(0, -800), 500.0)
	fails += _check(res["died"] and res["rockhit"] and not res["splash"],
		"matrix: friendly mb16 dies on the rock, no burst beyond it")
	# aa20 — the AA guns are unaffected: the round crosses the island (it flies toward -y here,
	# so min_y is how deep it got)
	res = _fly(w, quiet, "aa20", false, false, 0.0, Vector2(0, 0), Vector2(0, -800), 900.0)
	fails += _check(not res["rockhit"] and res["min_y"] < -460.0,
		"matrix: aa20 round passes over (reached y=%.0f)" % res["min_y"])
	# WASP rocket — aerial ordnance is unaffected (aimed wide of the hull, over the rock; it
	# flies toward +y, so max_y past the rock's near edge proves the crossing)
	res = _fly(w, quiet, "hostile", true, true, 0.0, Vector2(0, -800), Vector2(60, 0), 320.0)
	fails += _check(not res["rockhit"] and res["max_y"] > -340.0 and w.hull == full,
		"matrix: WASP rocket (aerial) passes over (reached y=%.0f)" % res["max_y"])

	# ── 5. avoidance sanity: a gunboat working past a rock never ends up inside a feature ──
	w = GameWorld.new(4)
	w.terrain = [{ "pos": Vector2(0, -450), "r": 60.0, "islet": false }]
	var gb := Enemy.new()
	gb.type_id = "gunboat"
	gb.layer = "surf"
	gb.hp = 5
	gb.hp_max = 5
	gb.active = true
	gb.pos = Vector2(0, -900)   # dead astern of the rock — the sticky-side fix's worst case
	gb.heading = PI
	w.enemies.append(gb)
	var never_inside: bool = true
	for i in range(int(20.0 / DT)):
		Sim.step(w, DT, quiet)
		if Terrain.blocked(w, gb.pos):
			never_inside = false
	fails += _check(never_inside and gb.pos.distance_to(w.ship_pos) < 750.0,
		"avoidance: 20s vs a blocking rock — never inside terrain, reaches station (d=%.0f)" \
		% gb.pos.distance_to(w.ship_pos))

	# ── 6. open-water no-op: worlds that never generate step in lockstep with empty terrain ──
	var oa := GameWorld.new(606060)
	var ob := GameWorld.new(606060)
	for i in range(600):
		Sim.step(oa, DT, cfgs)
		Sim.step(ob, DT, cfgs)
	fails += _check(oa.terrain.is_empty() and ob.terrain.is_empty() \
		and oa.rng.calls == ob.rng.calls and oa.ship_pos == ob.ship_pos \
		and oa.hull == ob.hull and oa.kills == ob.kills and oa.tick == 600,
		"open water: no generate → empty terrain, 10s lockstep (calls=%d hull=%d kills=%d)" \
		% [oa.rng.calls, oa.hull, oa.kills])

	if fails == 0:
		print("PROBE_TERRAIN PASSED")
	else:
		print("PROBE_TERRAIN FAILED (%d check(s))" % fails)
	quit(fails)

# Closest approach of the keel segment to a point — mirrors Movement's capsule test, read-only.
func _keel_dist(w: GameWorld, p: Vector2) -> float:
	var fwd := Vector2(sin(w.ship_heading), -cos(w.ship_heading))
	var t: float = clampf((p - w.ship_pos).dot(fwd), -Hull.HALF_LEN, Hull.HALF_LEN)
	return p.distance_to(w.ship_pos + fwd * t)

# Hand-fire one projectile down a bearing and step the world until it dies (or 8s). Reports
# whether it died, what effects the flight emitted, and the y-extremes it reached while live.
func _fly(w: GameWorld, cfgs: Configs, wid: String, hostile: bool, aerial: bool, splash: float,
		from: Vector2, to: Vector2, speed: float) -> Dictionary:
	w.effects.clear()
	var dir: Vector2 = (to - from).normalized()
	var p: Projectile = w.projectiles.obtain()
	p.pos = from
	p.vel = dir * speed
	p.dmg = 1
	p.splash = splash
	p.hostile = hostile
	p.wid = wid
	p.aerial = aerial
	p.life = from.distance_to(to) / speed
	var saw_rock: bool = false
	var saw_splash: bool = false
	var max_y: float = from.y
	var min_y: float = from.y
	for i in range(int(8.0 / DT)):
		Sim.step(w, DT, cfgs)
		if p.active:
			max_y = maxf(max_y, p.pos.y)
			min_y = minf(min_y, p.pos.y)
		for fx in w.effects:
			if fx["type"] == "rockhit":
				saw_rock = true
			elif fx["type"] == "splash":
				saw_splash = true
		w.effects.clear()
		if not p.active:
			break
	return { "died": not p.active, "rockhit": saw_rock, "splash": saw_splash,
		"max_y": max_y, "min_y": min_y }

func _check(cond: bool, label: String) -> int:
	print(("  OK  " if cond else "  FAIL") + " — " + label)
	return 0 if cond else 1
