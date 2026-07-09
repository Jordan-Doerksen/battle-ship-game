extends SceneTree
# C2 turret-suite probe, re-targeted at C3 enemies (the practice range retired with the wave chunk —
# docs/specs/wave-director.md decision #8). Same scenarios and thresholds as the approved mockups'
# validation harnesses: traverse ceiling, domain filter, per-weapon policies, all three force-fire
# orders + release, splash isolation + over-the-horizon trajectory (C3 gate rev 2), and AA bloom.
# Enemies are hand-placed; the wave director is silenced (zero budget, first wave never arrives).

const DT: float = 1.0 / 60.0

func _initialize() -> void:
	var fails: int = 0

	# 1 — traverse limit: no barrel ever slews faster than its weapon's traverse rate
	var c1 := _quiet()
	var w1 := GameWorld.new(7)
	Sim.step(w1, DT, c1)
	_place(w1, "swarmer", Vector2(0, -300), 999999, c1)
	var prev: Array = []
	for m in w1.mounts:
		prev.append(m.ang)
	var worst: float = 0.0
	for i in range(900):
		w1.input.thrust = 1.0
		w1.input.rudder = 1.0 if i % 150 < 75 else -1.0
		w1.input.force_all = i % 300 > 150
		w1.input.force_medium = i % 400 > 300
		w1.input.aim_world = w1.ship_pos + Vector2(-400, 100)
		Sim.step(w1, DT, c1)
		w1.effects.clear()
		for j in range(w1.mounts.size()):
			var wpn: WeaponDef = c1.weapons.by_id(c1.hardpoints.loadout[c1.hardpoints.mount_size[j]])
			worst = maxf(worst, absf(angle_difference(prev[j], w1.mounts[j].ang)) / DT - wpn.traverse)
			prev[j] = w1.mounts[j].ang
	fails += _check(worst <= 1e-6, "traverse limit: max overshoot %.9f rad/s" % worst)

	# 2 — domain filter: lone SURFACE enemy in auto -> aa20 silent, dp5 + mb16 fire
	var c2 := _quiet()
	var w2 := GameWorld.new(5)
	Sim.step(w2, DT, c2)
	_place(w2, "gunboat", Vector2(0, -300), 999999, c2)
	c2.enemies.by_id("gunboat").speed = 0.0   # anchor it
	var fired: Dictionary = {}
	for i in range(600):
		Sim.step(w2, DT, c2)
		for e in w2.effects:
			if e["type"] == "muzzle":
				fired[e["size"]] = true
		w2.effects.clear()
	fails += _check(not fired.has("S") and fired.has("M") and fired.has("L"),
		"domain filter: at a surface target, sizes fired = %s (S correctly silent)" % str(fired.keys()))

	# 3 — policy: near air + far surf, both immortal -> dp5 (CLOSE) hits near air, mb16 (STRONG,
	#     surface-only) hits far surf
	var c3 := _quiet()
	c3.enemies.by_id("swarmer").speed = 0.0
	c3.enemies.by_id("gunboat").speed = 0.0
	var w3 := GameWorld.new(9)
	Sim.step(w3, DT, c3)
	_place(w3, "swarmer", Vector2(0, -150), 999999, c3)
	_place(w3, "gunboat", Vector2(0, -500), 999999, c3)
	w3.enemies[1].cool = 1e12   # hold its fire; we're testing OUR guns
	var air_hits: int = 0
	var surf_hits: int = 0
	for i in range(900):
		Sim.step(w3, DT, c3)
		for e in w3.effects:
			if e["type"] == "hit":
				if absf(e["pos"].y - (-150.0)) < 60.0:
					air_hits += 1
				elif absf(e["pos"].y - (-500.0)) < 60.0:
					surf_hits += 1
		w3.effects.clear()
	fails += _check(air_hits > 0 and surf_hits > 0,
		"policy: dp5 CLOSE hits near air (%d), mb16 STRONG hits far surf (%d)" % [air_hits, surf_hits])

	# 4 — force-fire: LMB all mounts+sizes on cursor; RMB large only; MMB medium only; release resumes
	var c4 := _quiet()
	var w4 := GameWorld.new(21)
	Sim.step(w4, DT, c4)
	w4.input.force_all = true
	w4.input.aim_world = Vector2(400, 0)
	_run(w4, c4, 6.0)
	var east: float = PI / 2.0
	var all_east: bool = true
	for m in w4.mounts:
		all_east = all_east and absf(angle_difference(m.ang, east)) < 0.25
	var sizes: Dictionary = {}
	for i in range(120):
		Sim.step(w4, DT, c4)
		for e in w4.effects:
			if e["type"] == "muzzle":
				sizes[e["size"]] = true
		w4.effects.clear()
	var c4b := _quiet()
	c4b.enemies.by_id("gunboat").speed = 0.0
	var w4b := GameWorld.new(22)
	Sim.step(w4b, DT, c4b)
	_place(w4b, "gunboat", Vector2(-400, 0), 999999, c4b)   # west target keeps auto mounts busy
	w4b.enemies[0].cool = 1e12
	w4b.input.force_large = true
	w4b.input.aim_world = Vector2(400, 0)
	_run(w4b, c4b, 8.0)
	var west: float = -PI / 2.0
	var large_east: bool = absf(angle_difference(w4b.mounts[0].ang, east)) < 0.25 \
		and absf(angle_difference(w4b.mounts[1].ang, east)) < 0.25
	var med_west: bool = true
	for j in range(2, 6):
		med_west = med_west and absf(angle_difference(w4b.mounts[j].ang, west)) < 0.25
	w4b.input.force_large = false
	_run(w4b, c4b, 8.0)
	var mb_back: bool = absf(angle_difference(w4b.mounts[0].ang, west)) < 0.25
	var w4c := GameWorld.new(23)
	Sim.step(w4c, DT, c4)
	w4c.input.force_medium = true
	w4c.input.aim_world = Vector2(400, 0)
	_run(w4c, c4, 8.0)
	var med_east: bool = true
	for j in range(2, 6):
		med_east = med_east and absf(angle_difference(w4c.mounts[j].ang, east)) < 0.25
	var others_stowed: bool = true
	for j in [0, 1, 6, 7, 8, 9]:
		others_stowed = others_stowed and absf(angle_difference(w4c.mounts[j].ang, 0.0)) < 0.25
	fails += _check(all_east and sizes.has("S") and sizes.has("M") and sizes.has("L") \
		and large_east and med_west and mb_back and med_east and others_stowed,
		"force-fire: LMB all on cursor (all sizes firing); RMB large only; MMB medium only; release resumes auto")

	# 5 — splash isolation + over-the-horizon trajectory (C3 gate rev 2)
	var c5 := _quiet()
	c5.enemies.by_id("gunboat").speed = 0.0
	var w5 := GameWorld.new(23)
	Sim.step(w5, DT, c5)
	_place(w5, "gunboat", Vector2(0, -800), 3, c5)   # beyond dp5's reach; hp 3 <= mb16 dmg 4
	w5.enemies[0].cool = 1e12
	w5.input.force_large = true
	w5.input.aim_world = Vector2(10, -800)           # bearing 10u off — inside the proximity fuse
	var killed: bool = false
	var direct_hit: bool = false
	for i in range(1800):
		Sim.step(w5, DT, c5)
		for e in w5.effects:
			if e["type"] == "hit":
				direct_hit = true
			if e["type"] == "death":
				killed = true
		w5.effects.clear()
		if killed:
			break
	var w5b := GameWorld.new(29)
	Sim.step(w5b, DT, c5)
	w5b.input.force_large = true
	w5b.input.aim_world = Vector2(0, -200)           # cursor only 200u out — shell must overfly it
	var burst_dist: float = -1.0
	for i in range(480):
		Sim.step(w5b, DT, c5)
		for e in w5b.effects:
			if e["type"] == "splash":
				burst_dist = e["pos"].length()
		w5b.effects.clear()
		if burst_dist > 0.0:
			break
	var mb_range: float = c5.weapons.by_id("mb16").range_u
	fails += _check(killed and not direct_hit and burst_dist > mb_range * 0.9,
		"splash+trajectory: fuse kill at 10u bearing offset, no direct hits; near-aimed shell burst at %.0fu (range %.0f)" % [burst_dist, mb_range])

	# 6 — bloom: sustained aa20 fire widens toward bloom_max; resting decays it to zero
	var c6 := _quiet()
	c6.enemies.by_id("swarmer").speed = 0.0
	var w6 := GameWorld.new(24)
	Sim.step(w6, DT, c6)
	_place(w6, "swarmer", Vector2(0, -200), 999999, c6)
	_run(w6, c6, 6.0)
	var s_idx: int = c6.hardpoints.mount_size.find("S")
	var hot: float = w6.mounts[s_idx].bloom
	w6.enemies[0].active = false
	_run(w6, c6, 4.0)
	var cold: float = w6.mounts[s_idx].bloom
	var aa: WeaponDef = c6.weapons.by_id("aa20")
	fails += _check(hot > aa.bloom_max * 0.8 and cold < 0.005,
		"bloom: %.3f under sustained fire (max %.2f), %.3f after 4s rest" % [hot, aa.bloom_max, cold])

	# 7 — cadence (C1 fix): sustained aa20 fire averages the CONFIGURED rate — the old whole-tick
	#     reset (+ a ~1e-17 float residue) stretched the 5-tick period to 6, firing 10/s from a 12/s gun
	var c7 := _quiet()
	c7.enemies.by_id("swarmer").speed = 0.0
	var w7 := GameWorld.new(31)
	Sim.step(w7, DT, c7)
	_place(w7, "swarmer", Vector2(0, -200), 999999, c7)
	_run(w7, c7, 2.0)   # warm up: slew, first shot, settle into steady cadence
	var s7: int = c7.hardpoints.mount_size.find("S")
	var rate7: float = c7.weapons.by_id("aa20").rate
	var secs7: float = 10.0
	var shots7: int = 0
	for i in range(int(round(secs7 / DT))):
		Sim.step(w7, DT, c7)
		for e in w7.effects:
			if e["type"] == "muzzle" and e["idx"] == s7:
				shots7 += 1
		w7.effects.clear()
	fails += _check(absf(shots7 - rate7 * secs7) <= 1.0,
		"cadence: %d aa20 shots from one mount in %.0fs (configured %.1f/s -> expect %.0f +/- 1)"
		% [shots7, secs7, rate7, rate7 * secs7])

	# 8 — no catch-up (C1 fix): a gun idle for 10s must NOT machine-gun a banked backlog when a
	#     target finally appears — one immediate shot at most, then normal cadence from there
	var c8 := _quiet()
	c8.enemies.by_id("swarmer").speed = 0.0
	var w8 := GameWorld.new(32)
	Sim.step(w8, DT, c8)
	_run(w8, c8, 10.0)   # long no-target gap: cool must clamp near zero, not bank ~120 shots
	_place(w8, "swarmer", Vector2(0, -200), 999999, c8)
	var s8: int = c8.hardpoints.mount_size.find("S")
	var period8: int = int(floor(1.0 / (c8.weapons.by_id("aa20").rate * DT)))   # aa20: 5 ticks
	var shot_ticks: Array = []
	for i in range(120):
		Sim.step(w8, DT, c8)
		for e in w8.effects:
			if e["type"] == "muzzle" and e["idx"] == s8:
				shot_ticks.append(i)
		w8.effects.clear()
	var min_gap: int = 999999
	for i in range(1, shot_ticks.size()):
		min_gap = mini(min_gap, shot_ticks[i] - shot_ticks[i - 1])
	fails += _check(shot_ticks.size() >= 2 and min_gap >= period8,
		"no catch-up: after a 10s idle gap, %d shots in 2s, min gap %d ticks (period %d)"
		% [shot_ticks.size(), min_gap, period8])

	if fails == 0:
		print("PROBE_HARDPOINTS PASSED")
	else:
		print("PROBE_HARDPOINTS FAILED (%d check(s))" % fails)
	quit(fails)

# director silenced: nothing to spend, wave 1 never arrives — hand-placed enemies only
func _quiet() -> Configs:
	var c := Configs.defaults()
	c.waves.base_budget = 0
	c.waves.budget_per_wave = 0
	c.waves.first_wave_delay = 1e12
	return c

func _place(w: GameWorld, type_id: String, pos: Vector2, hp_override: int, c: Configs) -> void:
	var def: EnemyDef = c.enemies.by_id(type_id)
	var e := Enemy.new()
	e.type_id = def.id
	e.layer = def.layer
	e.active = true
	e.pos = pos
	e.heading = atan2(w.ship_pos.x - pos.x, -(w.ship_pos.y - pos.y))
	e.hp_max = def.hp
	e.hp = hp_override if hp_override > 0 else def.hp
	w.enemies.append(e)

func _run(w: GameWorld, c: Configs, secs: float) -> void:
	for i in range(int(round(secs / DT))):
		Sim.step(w, DT, c)
		w.effects.clear()

func _check(cond: bool, label: String) -> int:
	print(("  OK  " if cond else "  FAIL") + " — " + label)
	return 0 if cond else 1
