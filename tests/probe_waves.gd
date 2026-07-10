extends SceneTree
# C16 THE WAR, REPACKED acceptance probe (docs/specs/the-war-repacked.md §3) — re-targets the C3
# suite onto the echelon/formation director: determinism through real combat (composition now rides a
# per-wave substream, so world.rng.calls re-baselines but two-world byte-identity holds), the exact
# budget spend read off the composed PLAN (singles fill), the wave lifecycle on the REAL QUIET,
# hull damage + grace, gunboat standoff, run end, the AIR THREAT (VULTURE torpedo + WASP salvo), and
# the four C16 gates: formation cohesion, echelon separation, same-seed reproduction, ambush validity.

const DT: float = 1.0 / 60.0

func _initialize() -> void:
	var fails: int = 0

	# 1 — determinism: 3600 scripted ticks (sail + fight + all force modes) => byte-identical worlds
	var c1 := Configs.defaults()
	var wa := GameWorld.new(77)
	var wb := GameWorld.new(77)
	for i in range(3600):
		for w in [wa, wb]:
			w.input.thrust = 1.0 if i % 700 < 400 else 0.0
			w.input.rudder = 1.0 if i % 500 < 250 else -1.0
			w.input.force_all = i % 900 > 700
			w.input.force_medium = i % 1100 > 900
			w.input.aim_world = Vector2(300, -200)
			Sim.step(w, DT, c1)
			w.effects.clear()
	var same: bool = wa.ship_pos == wb.ship_pos and wa.ship_vel == wb.ship_vel \
		and wa.hull == wb.hull and wa.wave == wb.wave and wa.kills == wb.kills \
		and wa.enemies.size() == wb.enemies.size()
	for i in range(wa.mounts.size()):
		same = same and wa.mounts[i].ang == wb.mounts[i].ang
	for i in range(wa.enemies.size()):
		same = same and wa.enemies[i].pos == wb.enemies[i].pos and wa.enemies[i].hp == wb.enemies[i].hp
	fails += _check(same and wa.rng.calls == wb.rng.calls,
		"determinism: 3600 ticks byte-identical (wave %d, hull %d, kills %d, rng.calls %d)" % [wa.wave, wa.hull, wa.kills, wa.rng.calls])

	# 2+3 — budget honored / unlocks / lifecycle over six waves. C16: the wave lands in ECHELONS over
	# time, so the exact spend is read off the composed PLAN (wave_queue at the flip), not live enemies;
	# the between-wave breather is now the REAL QUIET (quiet_secs).
	var c2 := Configs.defaults()
	c2.bosses.every_n = 0   # isolate the C16 director — the C7 ladder has its own probe
	c2.waves.quiet_secs = 1.0
	c2.waves.first_wave_delay = 0.5
	c2.waves.hull_pips = 100000
	for wdef in c2.weapons.catalog:
		wdef.dmg = 500   # clear waves fast; the director is what's under test
	var w2 := GameWorld.new(31)
	var costs: Array[int] = []
	var unlock_ok: bool = true
	var seq_ok: bool = true
	var quiet_durs: Array[float] = []
	var last_state: String = "lull"
	var quiet_start: float = -1.0
	for i in range(60 * 600):
		Sim.step(w2, DT, c2)
		w2.effects.clear()
		if last_state == "lull" and w2.wave_state == "fighting":
			var cost: int = 0
			for entry in w2.wave_queue:                 # the whole wave's plan: templates + singles
				var d: EnemyDef = c2.enemies.by_id(entry["type"])
				cost += d.cost
				if w2.wave < d.unlock:
					unlock_ok = false
			costs.append(cost)
			if w2.wave != costs.size():
				seq_ok = false
			if quiet_start >= 0.0 and w2.wave > 1:
				quiet_durs.append(w2.elapsed - quiet_start)
		if last_state == "fighting" and w2.wave_state == "lull":
			quiet_start = w2.elapsed
		last_state = w2.wave_state
		if costs.size() >= 6:
			break
	var budget_ok: bool = costs.size() == 6
	for i in range(costs.size()):
		if costs[i] != c2.waves.base_budget + c2.waves.budget_per_wave * i:
			budget_ok = false
	var quiet_ok: bool = quiet_durs.size() > 0
	for d in quiet_durs:
		if absf(d - c2.waves.quiet_secs) > 0.1:
			quiet_ok = false
	fails += _check(budget_ok and unlock_ok, "budget+unlocks: six waves spent exactly (%s); no type before its unlock" % str(costs))
	fails += _check(seq_ok and quiet_ok, "lifecycle: waves 1..6 in order; quiets within 0.1s of %.1fs" % c2.waves.quiet_secs)

	# 4 — damage + grace: contact costs 1 pip; a second inside grace costs nothing; after grace it costs
	var c4 := _disarmed()
	var w4 := GameWorld.new(5)
	Sim.step(w4, DT, c4)
	_place(w4, "swarmer", Vector2(0, -140), 0, c4)
	var hull_first: int = -1
	for i in range(240):
		Sim.step(w4, DT, c4)
		w4.effects.clear()
		if w4.hull < c4.waves.hull_pips:
			hull_first = w4.hull
			break
	_place(w4, "swarmer", Vector2(0, -60), 0, c4)
	_run(w4, c4, 0.4)
	var hull_graced: int = w4.hull
	_run(w4, c4, 1.0)
	_place(w4, "swarmer", Vector2(0, -60), 0, c4)
	_run(w4, c4, 1.0)
	fails += _check(hull_first == 9 and hull_graced == 9 and w4.hull == 8,
		"damage+grace: first contact 10→%d, graced contact stays %d, post-grace →%d" % [hull_first, hull_graced, w4.hull])

	# 5 — gunboat: holds standoff, fires on period, its shell strips a pip from a stationary ship
	var c5 := _quiet()
	c5.enemies.by_id("gunboat").spread = 0.0   # stationary target — remove the only miss source
	var w5 := GameWorld.new(9)
	Sim.step(w5, DT, c5)
	_place(w5, "gunboat", Vector2(0, -650), 999999, c5)
	var g: Enemy = w5.enemies[0]
	var min_dist: float = INF
	var gunflash: int = 0
	for i in range(60 * 15):
		Sim.step(w5, DT, c5)
		for e in w5.effects:
			if e["type"] == "gunflash":
				gunflash += 1
		w5.effects.clear()
		min_dist = minf(min_dist, g.pos.distance_to(w5.ship_pos))
	var standoff: float = c5.enemies.by_id("gunboat").standoff
	fails += _check(min_dist > standoff * 0.7 and gunflash >= 2 and w5.hull < c5.waves.hull_pips,
		"gunboat: min dist %.0f (standoff %.0f), %d shots, hull %d/%d" % [min_dist, standoff, gunflash, w5.hull, c5.waves.hull_pips])

	# 6 — run end: hull 0 -> run_over, the war freezes; a fresh seed runs clean
	var c6 := _disarmed()
	c6.waves.hull_pips = 1
	var w6 := GameWorld.new(13)
	Sim.step(w6, DT, c6)
	_place(w6, "swarmer", Vector2(0, -140), 0, c6)
	_place(w6, "swarmer", Vector2(4000, 4000), 0, c6)   # far away; must freeze after the sinking
	w6.enemies[1].heading = 0.0
	_run(w6, c6, 3.0)
	var frozen_pos: Vector2 = w6.enemies[1].pos
	_run(w6, c6, 2.0)
	var frozen: bool = w6.enemies[1].pos == frozen_pos
	var w6b := GameWorld.new(14)
	var c6b := Configs.defaults()
	_run(w6b, c6b, 5.0)
	fails += _check(w6.run_over and w6.hull == 0 and frozen and not w6b.run_over and w6b.wave >= 1,
		"run end: run_over, hull 0, war frozen; fresh seed reaches wave %d" % w6b.wave)

	# 7 — AIR THREAT: the VULTURE is a torpedo bomber (standoff drop, wake-drawing torpedo with
	#     the klaxon trigger), and the WASP ripples its full rocket salvo in one trigger
	var c7 := _disarmed()
	var w7 := GameWorld.new(41)
	Sim.step(w7, DT, c7)
	_place(w7, "bomber", Vector2(0, -400), 999999, c7)
	var torps7: int = 0      # peak live torpedoes seen (they expire in ~5s — sample, don't post-count)
	var klaxon7: int = 0
	for i in range(int(round(14.0 / DT))):
		Sim.step(w7, DT, c7)
		for e in w7.effects:
			if e["type"] == "torpwater":
				klaxon7 += 1
		w7.effects.clear()
		var live7: int = 0
		for j in range(w7.projectiles.items.size()):
			var p7: Projectile = w7.projectiles.items[j]
			if p7.active and p7.hostile and p7.wid == "torpedo":
				live7 += 1
		torps7 = maxi(torps7, live7)
	var w7b := GameWorld.new(43)
	Sim.step(w7b, DT, c7)
	_place(w7b, "wasp", Vector2(0, -400), 999999, c7)
	var rockets7: int = 0    # peak live rockets = one full ripple in the air at once
	for i in range(int(round(3.0 / DT))):
		Sim.step(w7b, DT, c7)
		w7b.effects.clear()
		var live7b: int = 0
		for j in range(w7b.projectiles.items.size()):
			var p7b: Projectile = w7b.projectiles.items[j]
			if p7b.active and p7b.hostile and p7b.wid == "hostile":
				live7b += 1
		rockets7 = maxi(rockets7, live7b)
	var wasp_def: EnemyDef = c7.enemies.by_id("wasp")
	fails += _check(torps7 >= 1 and klaxon7 >= 1 and rockets7 == wasp_def.salvo,
		"AIR THREAT: VULTURE dropped %d torpedo(s) (%d klaxon); WASP rippled %d rocket(s) (salvo %d)"
		% [torps7, klaxon7, rockets7, wasp_def.salvo])

	# 8 — formation cohesion: a formation's members share ONE anchor bearing and arrive together (rel
	#     equal), spread by its shape. Wave 1 at budget 5 buys exactly one GNAT SWARM (5 swarmers, wedge).
	var c8 := Configs.defaults()
	c8.bosses.every_n = 0
	c8.waves.base_budget = 5
	c8.waves.budget_per_wave = 0
	var w8 := GameWorld.new(50)
	w8.wave = 1
	Waves._begin_wave(w8, c8)
	var q8: Array = w8.wave_queue
	var cohesion_ok: bool = q8.size() == 5
	var b8: float = float(q8[0]["bearing"]) if q8.size() > 0 else 0.0
	var r8: float = float(q8[0]["rel"]) if q8.size() > 0 else -1.0
	var spread8: bool = false
	for entry in q8:
		if String(entry["type"]) != "swarmer" or absf(float(entry["rel"]) - r8) > 1e-6 or absf(float(entry["bearing"]) - b8) > 1e-6:
			cohesion_ok = false
		if absf(float(entry["ox"])) > 1e-6 or absf(float(entry["oy"])) > 1e-6:
			spread8 = true
	fails += _check(cohesion_ok and spread8,
		"formation cohesion: GNAT SWARM = %d swarmers on one bearing, arriving together, spread in a wedge" % q8.size())

	# 9 — echelon separation: the plate's echelon clock normalizes the vanguard to 0 and spaces the
	#     main body / sting by the config delays; and a real wave lands its main body main_delay after
	#     its vanguard in the drained queue (rel 0 alongside rel main_delay).
	var c9 := Configs.defaults()
	c9.bosses.every_n = 0
	c9.waves.quiet_secs = 0.5
	c9.waves.first_wave_delay = 0.5
	c9.waves.base_budget = 60      # rich: wave-3+ buys span the echelons
	c9.waves.budget_per_wave = 0
	c9.waves.hull_pips = 100000
	for wdef in c9.weapons.catalog:
		wdef.dmg = 500
	var w9 := GameWorld.new(101)
	var ech_meta_ok: bool = false
	var ech_realized: bool = false
	var last9: String = "lull"
	for i in range(60 * 400):
		Sim.step(w9, DT, c9)
		w9.effects.clear()
		if last9 == "lull" and w9.wave_state == "fighting":
			if not w9.wave_lines["vanguard"].is_empty():
				if absf(float(w9.wave_ech_rel["main"]) - float(w9.wave_ech_rel["vanguard"]) - c9.waves.main_delay) < 1e-3 \
						and absf(float(w9.wave_ech_rel["sting"]) - float(w9.wave_ech_rel["vanguard"]) - c9.waves.sting_delay) < 1e-3:
					ech_meta_ok = true
			var has_van: bool = false
			var has_main: bool = false
			for entry in w9.wave_queue:
				if absf(float(entry["rel"])) < 1e-3:
					has_van = true
				if absf(float(entry["rel"]) - c9.waves.main_delay) < 1e-3:
					has_main = true
			if has_van and has_main and not w9.wave_lines["main"].is_empty():
				ech_realized = true
		last9 = w9.wave_state
		if ech_meta_ok and ech_realized:
			break
	fails += _check(ech_meta_ok and ech_realized,
		"echelon separation: main body lands +%.0fs / sting +%.0fs behind the vanguard" % [c9.waves.main_delay, c9.waves.sting_delay])

	# 10 — same seed = same war: two worlds on one seed compose an identical wave-3 plan despite
	#      different ship positions AND different world.rng histories (composition rides the per-wave
	#      substream, never world.rng or the player's path).
	var c10 := Configs.defaults()
	c10.bosses.every_n = 0
	var wr1 := GameWorld.new(77)
	var wr2 := GameWorld.new(77)
	wr1.ship_pos = Vector2(1234.0, -567.0)
	wr1.rng.nextf(); wr1.rng.nextf(); wr1.rng.nextf()   # advance world.rng — must NOT change the plan
	wr2.ship_pos = Vector2(-800.0, 200.0)
	wr1.wave = 3
	wr2.wave = 3
	Waves._begin_wave(wr1, c10)
	Waves._begin_wave(wr2, c10)
	var repro_ok: bool = wr1.wave_queue.size() == wr2.wave_queue.size() and wr1.wave_queue.size() > 0
	for i in range(wr1.wave_queue.size()):
		var ea: Dictionary = wr1.wave_queue[i]
		var eb: Dictionary = wr2.wave_queue[i]
		repro_ok = repro_ok and String(ea["type"]) == String(eb["type"]) \
			and absf(float(ea["rel"]) - float(eb["rel"])) < 1e-9 and absf(float(ea["bearing"]) - float(eb["bearing"])) < 1e-9 \
			and absf(float(ea["ring"]) - float(eb["ring"])) < 1e-9 \
			and absf(float(ea["ox"]) - float(eb["ox"])) < 1e-9 and absf(float(ea["oy"]) - float(eb["oy"])) < 1e-9
	fails += _check(repro_ok, "same seed = same war: seed 77 wave 3 composes identically from any ship pos / rng state (%d entries)" % wr1.wave_queue.size())

	# 11 — ambush validity: an ambush_ok formation staged behind a terrain feature spawns OUTSIDE the
	#      feature's circle and on its FAR side. Force wave 3 = one JACKAL PINCER (swarmer priced out so
	#      only the pincer is affordable) with a feature in ambush country (800u off the bow).
	var c11 := Configs.defaults()
	c11.bosses.every_n = 0
	c11.waves.ambush_chance = 1.0
	c11.waves.base_budget = 6
	c11.waves.budget_per_wave = 0
	c11.enemies.by_id("swarmer").cost = 999   # kills GNAT SWARM / SCREEN affordability — pincer only
	var w11 := GameWorld.new(1)
	w11.terrain.append({ "pos": Vector2(0.0, -800.0), "r": 100.0, "islet": false })
	w11.wave = 3
	Waves._begin_wave(w11, c11)
	var amb_entry = null
	for entry in w11.wave_queue:
		if entry["feat"] != null:
			amb_entry = entry
			break
	var composed_ambush: bool = amb_entry != null
	var outside11: bool = false
	var far11: bool = false
	if composed_ambush:
		Waves._spawn_entry(w11, c11, amb_entry)
		var e11: Enemy = w11.enemies[w11.enemies.size() - 1]
		var fp: Vector2 = amb_entry["feat"]["pos"]
		outside11 = e11.pos.distance_to(fp) > float(amb_entry["feat"]["r"])
		far11 = (e11.pos - fp).dot(fp - w11.ship_pos) > 0.0
	fails += _check(composed_ambush and outside11 and far11,
		"ambush validity: JACKAL PINCER staged behind the rock — spawns outside its circle, on the far side")

	if fails == 0:
		print("PROBE_WAVES PASSED")
	else:
		print("PROBE_WAVES FAILED (%d check(s))" % fails)
	quit(fails)

func _quiet() -> Configs:
	var c := Configs.defaults()
	c.waves.base_budget = 0
	c.waves.budget_per_wave = 0
	c.waves.first_wave_delay = 1e12
	return c

func _disarmed() -> Configs:   # quiet + our guns can't reach: contact scenarios need enemies alive
	var c := _quiet()
	for wdef in c.weapons.catalog:
		wdef.range_u = 0.0
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
