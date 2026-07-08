extends SceneTree
# C2 acceptance probe (run with `godot --headless -s tests/probe_hardpoints.gd`) — the checks from
# docs/specs/hardpoint-hull.md §Acceptance, run headless against the real Sim systems. These mirror
# the validation harness that ran against the approved mockup's sim region — same scenarios, same
# thresholds. Input (including the force-fire cursor) is scripted by writing world.input directly.

const DT: float = 1.0 / 60.0
const NEVER: float = 1e18

func _initialize() -> void:
	var fails: int = 0

	# 1 — determinism: same seed + same scripted input (sail + both force modes) => identical state
	var c1 := Configs.defaults()
	var wa := GameWorld.new(99)
	var wb := GameWorld.new(99)
	for i in range(1200):
		for w in [wa, wb]:
			w.input.thrust = 1.0 if i < 300 else 0.0
			w.input.rudder = 1.0 if i % 200 < 100 else 0.0
			w.input.force_all = i > 400 and i < 700
			w.input.force_large = i > 800 and i < 1000
			w.input.aim_world = Vector2(300, -200)
			Sim.step(w, DT, c1)
	var same: bool = wa.ship_pos == wb.ship_pos and wa.ship_vel == wb.ship_vel \
		and wa.ship_heading == wb.ship_heading and wa.kills == wb.kills
	for i in range(wa.mounts.size()):
		same = same and wa.mounts[i].ang == wb.mounts[i].ang and wa.mounts[i].bloom == wb.mounts[i].bloom
	for i in range(wa.drones.size()):
		same = same and wa.drones[i].pos == wb.drones[i].pos and wa.drones[i].hp == wb.drones[i].hp \
			and wa.drones[i].active == wb.drones[i].active
	fails += _check(same and wa.rng.calls == wb.rng.calls,
		"determinism: 1200 scripted ticks byte-identical (rng.calls=%d both)" % wa.rng.calls)

	# 2 — traverse limit: no barrel ever slews faster than its weapon's traverse rate
	var c2 := Configs.defaults()
	var w2 := GameWorld.new(7)
	var worst: float = 0.0
	Sim.step(w2, DT, c2)   # build mounts
	var prev: Array = []
	for m in w2.mounts:
		prev.append(m.ang)
	for i in range(900):
		w2.input.thrust = 1.0
		w2.input.rudder = 1.0 if i % 150 < 75 else -1.0
		w2.input.force_all = i % 300 > 150
		w2.input.aim_world = w2.ship_pos + Vector2(-400, 100)
		Sim.step(w2, DT, c2)
		for j in range(w2.mounts.size()):
			var wpn: WeaponDef = c2.weapons.by_id(c2.hardpoints.loadout[c2.hardpoints.mount_size[j]])
			var rate: float = absf(angle_difference(prev[j], w2.mounts[j].ang)) / DT
			worst = maxf(worst, rate - wpn.traverse)
			prev[j] = w2.mounts[j].ang
	fails += _check(worst <= 1e-6, "traverse limit: max overshoot %.9f rad/s" % worst)

	# 3 — domain filter: lone SURFACE drone in auto -> aa20 silent, dp5 + mb16 fire
	var c3 := _range_cfg(0, 1)
	var w3 := _one_drone(c3, "surf", Vector2(0, -300), 999999)
	var fired: Dictionary = {}
	for i in range(600):
		Sim.step(w3, DT, c3)
		for e in w3.effects:
			if e["type"] == "muzzle":
				fired[e["size"]] = true
		w3.effects.clear()
	fails += _check(not fired.has("S") and fired.has("M") and fired.has("L"),
		"domain filter: at a surface target, sizes fired = %s (S correctly silent)" % str(fired.keys()))

	# 4 — policy: near air + far surf, both immortal -> dp5 (CLOSE) hits the near air,
	#     mb16 (STRONG, surface-only) hits the far surf
	var c4 := _range_cfg(1, 1)
	var w4 := _one_drone(c4, "air", Vector2(0, -150), 999999)
	var ds: Drone = _find_drone(w4, "surf")
	_place(ds, Vector2(0, -500), 999999, 3)
	var air_hits: int = 0
	var surf_hits: int = 0
	for i in range(900):
		Sim.step(w4, DT, c4)
		for e in w4.effects:
			if e["type"] == "hit":
				if absf(e["pos"].y - (-150.0)) < 60.0:
					air_hits += 1
				elif absf(e["pos"].y - (-500.0)) < 60.0:
					surf_hits += 1
		w4.effects.clear()
	fails += _check(air_hits > 0 and surf_hits > 0,
		"policy: dp5 CLOSE hits near air (%d), mb16 STRONG hits far surf (%d)" % [air_hits, surf_hits])

	# 5 — force-fire: LMB slews ALL mounts to the cursor (domain overridden) and all sizes fire;
	#     RMB moves LARGE only while the rest stay on their target; release resumes auto
	var c5 := _range_cfg(0, 1)
	var w5 := _one_drone(c5, "surf", Vector2(-400, 0), 999999)
	w5.input.force_all = true
	w5.input.aim_world = Vector2(400, 0)
	_run(w5, c5, 6.0)
	var east: float = PI / 2.0
	var all_east: bool = true
	for m in w5.mounts:
		all_east = all_east and absf(angle_difference(m.ang, east)) < 0.25
	w5.effects.clear()
	var sizes: Dictionary = {}
	for i in range(120):
		Sim.step(w5, DT, c5)
		for e in w5.effects:
			if e["type"] == "muzzle":
				sizes[e["size"]] = true
		w5.effects.clear()
	var all_fire: bool = sizes.has("S") and sizes.has("M") and sizes.has("L")
	var w5b := _one_drone(_range_cfg(0, 1), "surf", Vector2(-400, 0), 999999)
	w5b.input.force_large = true
	w5b.input.aim_world = Vector2(400, 0)
	_run(w5b, c5, 8.0)
	var west: float = -PI / 2.0
	var large_east: bool = absf(angle_difference(w5b.mounts[0].ang, east)) < 0.25 \
		and absf(angle_difference(w5b.mounts[1].ang, east)) < 0.25
	var med_west: bool = true
	for j in range(2, 6):
		med_west = med_west and absf(angle_difference(w5b.mounts[j].ang, west)) < 0.25
	w5b.input.force_large = false
	_run(w5b, c5, 8.0)
	var mb_back: bool = absf(angle_difference(w5b.mounts[0].ang, west)) < 0.25
	fails += _check(all_east and all_fire and large_east and med_west and mb_back,
		"force-fire: LMB all mounts+sizes on cursor; RMB large only; release resumes auto")

	# 6 — kill & respawn: drones die, slots refill after the delay, concurrency holds
	var c6 := _range_cfg(2, 2)
	var w6 := GameWorld.new(11)
	var max_active: int = 0
	var repopulated: bool = false
	for i in range(3600):
		Sim.step(w6, DT, c6)
		w6.effects.clear()
		var active: int = 0
		for d in w6.drones:
			if d.active:
				active += 1
		max_active = maxi(max_active, active)
		if w6.kills > 0 and active == 4:
			repopulated = true
	fails += _check(w6.kills > 0 and repopulated and max_active <= 4,
		"kill & respawn: kills=%d, range repopulated, concurrent<=%d" % [w6.kills, max_active])

	# 7 — splash: mb16 forced at a point 20u from a raft (< splash 36), beyond every other gun's
	#     range -> the raft dies to splash with no direct hits
	var c7 := _range_cfg(0, 1)
	var w7 := _one_drone(c7, "surf", Vector2(0, -800), 0)   # default hp (3)
	w7.input.force_large = true
	w7.input.aim_world = Vector2(20, -800)
	var direct_hit: bool = false
	var killed: bool = false
	for i in range(1800):
		Sim.step(w7, DT, c7)
		for e in w7.effects:
			if e["type"] == "hit":
				direct_hit = true
			if e["type"] == "death":
				killed = true
		w7.effects.clear()
		if killed:
			break
	fails += _check(killed and not direct_hit, "splash: raft killed at 20u offset with zero direct hits")

	# 8 — bloom: sustained aa20 fire widens toward bloom_max; resting decays it to zero
	var c8 := _range_cfg(1, 0)
	var w8 := _one_drone(c8, "air", Vector2(0, -200), 999999)
	_run(w8, c8, 6.0)
	var s_idx: int = c8.hardpoints.mount_size.find("S")
	var hot: float = w8.mounts[s_idx].bloom
	var da: Drone = _find_drone(w8, "air")
	da.active = false
	da.respawn_at = NEVER
	_run(w8, c8, 4.0)
	var cold: float = w8.mounts[s_idx].bloom
	var aa: WeaponDef = c8.weapons.by_id("aa20")
	fails += _check(hot > aa.bloom_max * 0.8 and cold < 0.005,
		"bloom: %.3f under sustained fire (max %.2f), %.3f after 4s rest" % [hot, aa.bloom_max, cold])

	if fails == 0:
		print("PROBE_HARDPOINTS PASSED")
	else:
		print("PROBE_HARDPOINTS FAILED (%d check(s))" % fails)
	quit(fails)

func _range_cfg(air: int, surf: int) -> Configs:
	var c := Configs.defaults()
	c.gunnery.air_count = air
	c.gunnery.surf_count = surf
	return c

# world with exactly one hand-placed drone; every other slot silenced
func _one_drone(c: Configs, layer: String, pos: Vector2, hp_override: int) -> GameWorld:
	var w := GameWorld.new(5)
	Sim.step(w, DT, c)   # builds slots
	for d in w.drones:
		d.active = false
		d.respawn_at = NEVER
	var d: Drone = _find_drone(w, layer)
	_place(d, pos, hp_override, 1 if layer == "air" else 3)
	w.effects.clear()
	return w

func _find_drone(w: GameWorld, layer: String) -> Drone:
	for d in w.drones:
		if d.layer == layer:
			return d
	return null

func _place(d: Drone, pos: Vector2, hp_override: int, hp_max: int) -> void:
	d.active = true
	d.pos = pos
	d.vel = Vector2.ZERO
	d.hp_max = hp_max
	d.hp = hp_override if hp_override > 0 else hp_max

func _run(w: GameWorld, c: Configs, secs: float) -> void:
	for i in range(int(round(secs / DT))):
		Sim.step(w, DT, c)
		w.effects.clear()

func _check(cond: bool, label: String) -> int:
	print(("  OK  " if cond else "  FAIL") + " — " + label)
	return 0 if cond else 1
