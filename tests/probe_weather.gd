extends SceneTree
# C17 acceptance probe (docs/specs/weather-fronts.md §Verify) — the weather-fronts contract:
# (1) two-world determinism with weather generated + fronts landing, (2) the ungenerated/disabled
# baseline is byte-identical (and generate() itself makes ZERO world.rng draws), (3) same seed ⇒
# same schedule with the escalation shape, (4) boss waves always read clear, (5) detection
# attenuation observable on the sonar AND the enemy side (symmetric), (6) squall+ grounds the bird
# and clear relaunches it, (7) forced fire is weather-blind.

const DT: float = 1.0 / 60.0

func _initialize() -> void:
	var fails: int = 0

	# 1 — determinism: fronts from wave 1, real director, 3600 scripted ticks ⇒ byte-identical
	var c1 := Configs.defaults()
	c1.weather.first_front_min = 1
	c1.weather.first_front_max = 1
	c1.waves.first_wave_delay = 1.0
	var wa := GameWorld.new(910)
	var wb := GameWorld.new(910)
	Weather.generate(wa, c1)
	Weather.generate(wb, c1)
	for i in range(3600):
		for w in [wa, wb]:
			w.input.thrust = 1.0 if i % 600 < 300 else -1.0
			w.input.rudder = 1.0 if i % 400 < 200 else 0.0
			Sim.step(w, DT, c1)
			w.effects.clear()
	var same: bool = wa.ship_pos == wb.ship_pos and wa.hull == wb.hull and wa.wave == wb.wave \
		and wa.wx_state == wb.wx_state and wa.enemies.size() == wb.enemies.size() \
		and wa.rng.calls == wb.rng.calls
	for i in range(wa.enemies.size()):
		same = same and wa.enemies[i].pos == wb.enemies[i].pos
	fails += _check(same and wa.wave >= 2,
		"determinism: 3600 ticks under fronts byte-identical (wave %d, wx '%s', rng.calls %d)" % [wa.wave, wa.wx_state, wa.rng.calls])

	# 2 — baseline: generate() draws ZERO from world.rng; a disabled schedule ⇒ identical to an
	#     ungenerated world through real waves (the pre-C17 twin)
	var c2 := Configs.defaults()
	c2.waves.first_wave_delay = 1.0
	var w2a := GameWorld.new(23)   # never generated — the pre-C17 shape
	var w2b := GameWorld.new(23)
	var calls_before: int = w2b.rng.calls
	var c2off := Configs.defaults()
	c2off.waves.first_wave_delay = 1.0
	c2off.weather.enabled = false
	Weather.generate(w2b, c2off)
	var zero_draws: bool = w2b.rng.calls == calls_before and w2b.wx_schedule.is_empty()
	for i in range(2400):
		for w in [w2a, w2b]:
			w.input.thrust = 1.0
			Sim.step(w, DT, c2)
			w.effects.clear()
	var base_same: bool = w2a.ship_pos == w2b.ship_pos and w2a.rng.calls == w2b.rng.calls \
		and w2a.wx_state == "clear" and w2b.wx_state == "clear" and w2a.wx_mult == 1.0
	fails += _check(zero_draws and base_same,
		"baseline: generate() made 0 world.rng draws; disabled == ungenerated == clear through %d waves" % w2a.wave)

	# 3 — schedule: same seed ⇒ same schedule; first front in [min,max]; escalation tiers hold.
	#     Shape-checked WITHOUT the ladder (every_n=0) — boss-clear legitimately eats fronts that
	#     roll onto machine waves (check 4 validates that separately with the ladder on).
	var c3 := Configs.defaults()
	c3.bosses.every_n = 0
	var w3a := GameWorld.new(777)
	var w3b := GameWorld.new(777)
	Weather.generate(w3a, c3)
	Weather.generate(w3b, c3)
	var sched_same: bool = w3a.wx_schedule.size() > 0 and w3a.wx_schedule.size() == w3b.wx_schedule.size()
	for k in w3a.wx_schedule:
		sched_same = sched_same and w3b.wx_schedule.get(k, "") == w3a.wx_schedule[k]
	var first: int = 999999
	var tiers_ok: bool = true
	for k in w3a.wx_schedule:
		first = mini(first, k)
		var st: String = String(w3a.wx_schedule[k])
		tiers_ok = tiers_ok and st in ["rain", "squall", "thunder"]
		if st == "squall": tiers_ok = tiers_ok and k >= c3.weather.squall_from
		if st == "thunder": tiers_ok = tiers_ok and k >= c3.weather.thunder_from
	var first_ok: bool = first >= c3.weather.first_front_min and first <= c3.weather.first_front_max
	fails += _check(sched_same and first_ok and tiers_ok,
		"schedule: same seed ⇒ same %d-entry schedule; first front wave %d ∈ [%d,%d]; tiers respect thresholds" \
		% [w3a.wx_schedule.size(), first, c3.weather.first_front_min, c3.weather.first_front_max])

	# 4 — boss-clear law: no schedule entry ever lands on an every-Nth machine wave
	var c4 := Configs.defaults()
	var boss_clear: bool = true
	for seed_v in [11, 222, 3333]:
		var w4 := GameWorld.new(seed_v)
		Weather.generate(w4, c4)
		for k in w4.wx_schedule:
			if c4.bosses.every_n > 0 and k % c4.bosses.every_n == 0:
				boss_clear = false
	fails += _check(boss_clear, "boss-clear: 3 seeds, zero fronts on every-%dth machine waves" % c4.bosses.every_n)

	# 5 — attenuation, both sides: a sub between squall-radius and clear-radius is heard in clear,
	#     unheard in squall, heard again closer; a gunboat between the two fire ranges holds fire
	#     in squall and opens up in clear
	var c5 := _quiet()
	c5.enemies.by_id("sub").speed = 0.0
	c5.enemies.by_id("sub").fire_range = 0.0
	var w5 := GameWorld.new(31)
	Sim.step(w5, DT, c5)
	var r_test: float = c5.sonar.radius * 0.8   # between 0.6× and 1.0×
	_place(w5, "sub", Vector2(0, -r_test), 999999, c5)
	_run(w5, c5, 0.5)
	var heard_clear: bool = Sonar.detected(w5, w5.enemies[0])
	var w5b := GameWorld.new(31)
	Sim.step(w5b, DT, c5)
	w5b.wx_state = "squall"
	w5b.wx_mult = c5.weather.detect_squall
	_place(w5b, "sub", Vector2(0, -r_test), 999999, c5)
	_run(w5b, c5, 2.0 + c5.sonar.contact_hold)   # outlive any latch
	var deaf_squall: bool = not Sonar.detected(w5b, w5b.enemies[0])
	w5b.enemies[0].pos = Vector2(0, -c5.sonar.radius * c5.weather.detect_squall * 0.8)
	_run(w5b, c5, 0.5)
	var heard_close: bool = Sonar.detected(w5b, w5b.enemies[0])
	var c5g := _quiet()
	c5g.enemies.by_id("gunboat").speed = 0.0
	var gb_r: float = c5g.enemies.by_id("gunboat").fire_range * 0.8
	var w5c := GameWorld.new(37)
	Sim.step(w5c, DT, c5g)
	w5c.wx_state = "squall"
	w5c.wx_mult = c5g.weather.detect_squall
	_place(w5c, "gunboat", Vector2(0, -gb_r), 999999, c5g)
	var held_fire: bool = _count_fx(w5c, c5g, 4.0, "gunflash") == 0
	w5c.wx_state = "clear"
	w5c.wx_mult = 1.0
	var opened_fire: bool = _count_fx(w5c, c5g, 4.0, "gunflash") > 0
	fails += _check(heard_clear and deaf_squall and heard_close and held_fire and opened_fire,
		"attenuation symmetric: sonar %s/%s/%s (%.0fu); gunboat squall-held %s, clear-opened %s" \
		% [heard_clear, deaf_squall, heard_close, r_test, held_fire, opened_fire])

	# 6 — the bird grounds: squall flips air → rtb → pad and holds; clear relaunches
	var c6 := _quiet()
	c6.tech.helo = true
	var w6 := GameWorld.new(41)
	_run(w6, c6, 2.0)
	var flew: bool = w6.helo_state == "air"
	w6.wx_state = "squall"
	w6.wx_mult = c6.weather.detect_squall
	_run(w6, c6, 30.0)
	var lashed: bool = w6.helo_state == "pad"
	_run(w6, c6, c6.airwing.turnaround_secs + 5.0)
	var held_pad: bool = w6.helo_state == "pad"
	w6.wx_state = "clear"
	w6.wx_mult = 1.0
	_run(w6, c6, c6.airwing.turnaround_secs + 5.0)
	var relaunched: bool = w6.helo_state == "air"
	fails += _check(flew and lashed and held_pad and relaunched,
		"grounding: air → rtb → pad under squall, held while it blows, relaunched in clear")

	# 7 — forced fire is weather-blind: same target beyond the ATTENUATED auto range, same order,
	#     thunder and clear fire the same number of rounds
	var m_clear: int = _forced_muzzles("clear", 1.0)
	var m_thunder: int = _forced_muzzles("thunder", Configs.defaults().weather.detect_thunder)
	fails += _check(m_clear > 0 and m_clear == m_thunder,
		"forced fire weather-blind: %d muzzles clear == %d muzzles thunder" % [m_clear, m_thunder])

	print("\nprobe_weather: %s" % ("ALL GREEN" if fails == 0 else "%d FAILED" % fails))
	quit(fails)

func _forced_muzzles(state: String, mult: float) -> int:
	var c := _quiet()
	c.enemies.by_id("gunboat").speed = 0.0
	c.enemies.by_id("gunboat").fire_range = 0.0
	var w := GameWorld.new(55)
	Sim.step(w, DT, c)
	w.wx_state = state
	w.wx_mult = mult
	var mb: WeaponDef = c.weapons.by_id(c.hardpoints.loadout["L"])
	_place(w, "gunboat", Vector2(0, -mb.range_u * 0.8), 999999, c)   # beyond thunder's auto range
	w.input.force_large = true
	w.input.aim_world = Vector2(0, -mb.range_u * 0.8)
	var n: int = 0
	for i in range(int(round(6.0 / DT))):
		Sim.step(w, DT, c)
		for e in w.effects:
			if e["type"] == "muzzle":
				n += 1
		w.effects.clear()
	return n

func _count_fx(w: GameWorld, c: Configs, secs: float, fx_type: String) -> int:
	var n: int = 0
	for i in range(int(round(secs / DT))):
		Sim.step(w, DT, c)
		for e in w.effects:
			if e["type"] == fx_type:
				n += 1
		w.effects.clear()
	return n

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
