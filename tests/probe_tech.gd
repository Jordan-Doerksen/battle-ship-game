extends SceneTree
# C4 acceptance probe (docs/specs/tech-tree.md §Acceptance) — mirrors the mockup's validation
# harness: baseline invariance (zero tech = the exact base config), derivation determinism, the
# XP/level curve, all four marquee effects behaviorally, the spend rules, and the Profile save
# roundtrip (to a probe-only path — a real career file is never touched).

const DT: float = 1.0 / 60.0

func _initialize() -> void:
	var fails: int = 0

	# 1 — baseline invariance: zero nodes -> derived config equals base; marquee flags all off
	var base := Configs.defaults()
	var zero := Tech.apply(base, [])
	var inv: bool = zero.movement.max_speed_ahead == base.movement.max_speed_ahead \
		and zero.movement.turn_speed_floor == base.movement.turn_speed_floor \
		and zero.weapons.by_id("aa20").rate == base.weapons.by_id("aa20").rate \
		and zero.weapons.by_id("dp5").dmg == base.weapons.by_id("dp5").dmg \
		and zero.weapons.by_id("mb16").splash == base.weapons.by_id("mb16").splash \
		and zero.waves.hull_pips == base.waves.hull_pips \
		and not zero.tech.crash_turn and not zero.tech.incendiary \
		and not zero.tech.airburst and not zero.tech.salvo
	# and the base was never mutated by a real unlock set
	var _full := Tech.apply(base, ["sea1", "sea5", "gun5", "ord6"])
	inv = inv and base.movement.max_speed_ahead == 220.0 and base.waves.hull_pips == 10 \
		and base.weapons.by_id("dp5").dmg == 2 and not base.tech.salvo
	fails += _check(inv, "baseline invariance: zero-tech derives base exactly; base never mutated")

	# 2 — derivation determinism + modded-run determinism
	var unlocks := ["sea1", "sea2", "flk1", "gun5", "ord6", "sea6"]
	var a := Tech.apply(base, unlocks)
	var b := Tech.apply(base, unlocks)
	var cfg_same: bool = a.movement.max_speed_ahead == b.movement.max_speed_ahead \
		and a.weapons.by_id("dp5").dmg == b.weapons.by_id("dp5").dmg \
		and a.tech.salvo == b.tech.salvo and a.tech.crash_turn == b.tech.crash_turn
	var mods_ok: bool = absf(a.movement.max_speed_ahead - 242.0) < 1e-6 \
		and a.weapons.by_id("dp5").dmg == 3 and a.tech.salvo and a.tech.crash_turn
	var w1 := GameWorld.new(42)
	var w2 := GameWorld.new(42)
	for i in range(1800):
		for w in [w1, w2]:
			w.input.thrust = 1.0 if i < 400 else -1.0
			w.input.rudder = 1.0 if i % 300 < 150 else 0.0
			Sim.step(w, DT, a if w == w1 else b)
			w.effects.clear()
	var run_same: bool = w1.ship_pos == w2.ship_pos and w1.xp_run == w2.xp_run \
		and w1.wave == w2.wave and w1.rng.calls == w2.rng.calls
	fails += _check(cfg_same and mods_ok and run_same,
		"derivation determinism: same unlocks => same configs + byte-identical modded run (rng.calls=%d)" % w1.rng.calls)

	# 3 — XP accounting + level curve + wave bonus
	var c3 := _quiet(base, [])
	var w3 := GameWorld.new(3)
	Sim.step(w3, DT, c3)
	_place(w3, "swarmer", Vector2(0, -200), 1, c3)
	_place(w3, "swarmer", Vector2(100, -200), 1, c3)
	var gb := _place(w3, "gunboat", Vector2(0, -400), 1, c3)
	gb.cool = 1e12
	_run(w3, c3, 12.0)
	var pc: ProgressConfig = base.progress
	var kills_ok: bool = w3.xp_run == 2 * pc.xp_swarmer + pc.xp_gunboat
	var curve_ok: bool = pc.level_info(0)["level"] == 1 and pc.level_info(150)["level"] == 2 \
		and pc.level_info(400)["level"] == 3 and pc.level_info(399)["level"] == 2
	var c3b := Tech.apply(base, [])
	c3b.waves.first_wave_delay = 0.5
	c3b.waves.hull_pips = 100000
	for wd in c3b.weapons.catalog:
		wd.dmg = 500
	var w3b := GameWorld.new(31)
	var xp_at_clear: int = -1
	for i in range(60 * 60):
		Sim.step(w3b, DT, c3b)
		for e in w3b.effects:
			if e["type"] == "waveclear":
				xp_at_clear = w3b.xp_run
		w3b.effects.clear()
		if xp_at_clear >= 0:
			break
	var bonus_ok: bool = xp_at_clear == w3b.kills * pc.xp_swarmer + pc.xp_wave_bonus * 1
	fails += _check(kills_ok and curve_ok and bonus_ok,
		"xp+levels: kill XP %d (want %d); curve 0→L1/150→L2/400→L3/399→L2; wave-1 clear banked %d" % [w3.xp_run, 2 * pc.xp_swarmer + pc.xp_gunboat, xp_at_clear])

	# 4a — FULL SALVO: both barrels per trigger
	var c4 := _quiet(base, ["ord1", "ord2", "ord3", "ord4", "ord5", "ord6"])
	var w4 := GameWorld.new(7)
	Sim.step(w4, DT, c4)
	w4.input.force_large = true
	w4.input.aim_world = Vector2(0, -600)
	var muzzles: int = 0
	var shells: int = 0
	for i in range(600):
		Sim.step(w4, DT, c4)
		for e in w4.effects:
			if e["type"] == "muzzle" and e["size"] == "L":
				muzzles += 1
		w4.effects.clear()
		var airborne: int = 0
		for j in range(w4.projectiles.items.size()):
			var p: Projectile = w4.projectiles.items[j]
			if p.active and p.wid == "mb16":
				airborne += 1
		shells = maxi(shells, airborne)
		if muzzles >= 2:
			break
	fails += _check(muzzles >= 1 and shells >= 3,
		"full salvo: %d L muzzles, %d mb16 shells airborne (2 barrels x 2 mounts)" % [muzzles, shells])

	# 4b — INCENDIARY: aa hit ignites; the burn does the killing
	var c4b := _quiet(base, ["flk1", "flk2", "flk3", "flk4", "flk5", "flk6"])
	c4b.enemies.by_id("swarmer").speed = 0.0
	c4b.weapons.by_id("aa20").rate = 0.15   # one round every ~6.7s
	var w4b := GameWorld.new(9)
	Sim.step(w4b, DT, c4b)
	_place(w4b, "swarmer", Vector2(0, -200), 4, c4b)   # hp 4: 1 direct + 3 burn ticks = dead
	var ignited: bool = false
	var died: bool = false
	for i in range(60 * 8):
		Sim.step(w4b, DT, c4b)
		for e in w4b.effects:
			if e["type"] == "ignite":
				ignited = true
			if e["type"] == "death":
				died = true
		w4b.effects.clear()
		if died:
			break
	fails += _check(ignited and died, "incendiary: ignited then burned down an hp-4 swarmer")

	# 4c — PROXIMITY BURST: dp5 airbursts damage an air enemy it never touched
	var c4c := _quiet(base, ["gun1", "gun2", "gun3", "gun4", "gun5", "gun6"])
	c4c.enemies.by_id("swarmer").speed = 0.0
	c4c.weapons.by_id("aa20").range_u = 0.0   # only the 5-in may engage
	var w4c := GameWorld.new(11)
	Sim.step(w4c, DT, c4c)
	_place(w4c, "swarmer", Vector2(0, -350), 999999, c4c)
	var bursts: int = 0
	var flak_hits: int = 0
	for i in range(600):
		Sim.step(w4c, DT, c4c)
		for e in w4c.effects:
			if e["type"] == "airburst":
				bursts += 1
			if e["type"] == "hit":
				flak_hits += 1
		w4c.effects.clear()
	fails += _check(bursts > 0 and flak_hits > 0, "airburst: %d bursts, %d flak-cloud damage events" % [bursts, flak_hits])

	# 4d — CRASH TURN: window multiplies turn rate; cooldown holds
	var c4d0 := _quiet(base, [])
	var c4d := _quiet(base, ["sea1", "sea2", "sea3", "sea4", "sea5", "sea6"])
	c4d.movement = c4d0.movement.duplicate()   # isolate the marquee from the stat nodes
	c4d.waves.hull_pips = c4d0.waves.hull_pips
	var d0: float = _turn_delta(c4d0)
	var d1: float = _turn_delta(c4d)
	var ratio: float = d1 / d0
	var w4d := GameWorld.new(13)
	_run_input(w4d, c4d, 12.0, 1.0, 0.0)
	_run_input(w4d, c4d, 0.5, -1.0, 0.0)
	var ready_first: float = w4d.crash_ready
	_run_input(w4d, c4d, 1.0, -1.0, 0.0)
	fails += _check(ratio > 1.4 and ratio < 2.0 and w4d.crash_ready == ready_first,
		"crash turn: window delta x%.2f (~1.8); cooldown not re-armed mid-window" % ratio)

	# 5 — spend rules + AIR WING lock
	var pc5: ProgressConfig = base.progress
	var prof := Profile.new()
	prof.xp = _xp_for_level(pc5, 3)   # 2 points
	var order_ok: bool = not Tech.can_buy(prof, "sea2", base.tech, pc5) and Tech.can_buy(prof, "sea1", base.tech, pc5)
	prof.unlocked = ["sea1", "sea2"]
	var broke_ok: bool = not Tech.can_buy(prof, "sea3", base.tech, pc5) and Tech.points_available(prof, base.tech, pc5) == 0
	prof.xp = _xp_for_level(pc5, 12)   # 11 points
	var chain_ok: bool = not Tech.can_buy(prof, "sea6", base.tech, pc5)
	prof.unlocked = ["sea1", "sea2", "sea3", "sea4", "sea5"]
	var marquee_ok: bool = Tech.can_buy(prof, "sea6", base.tech, pc5)
	var air_ok: bool = not Tech.can_buy(prof, "air1", base.tech, pc5)
	fails += _check(order_ok and broke_ok and chain_ok and marquee_ok and air_ok,
		"spend rules: in-branch order, point gating, marquee chain, AIR WING locked")

	# 6 — profile roundtrip (probe-only path)
	var probe_path := "user://profile_probe.cfg"
	var p1 := Profile.new()
	p1.xp = 1234
	p1.unlocked = ["sea1", "flk1", "ord6"]
	p1.save(probe_path)
	var p2 := Profile.load_profile(probe_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(probe_path))
	fails += _check(p2.xp == 1234 and p2.unlocked == ["sea1", "flk1", "ord6"],
		"profile roundtrip: save → load restores xp + unlocks exactly")

	if fails == 0:
		print("PROBE_TECH PASSED")
	else:
		print("PROBE_TECH FAILED (%d check(s))" % fails)
	quit(fails)

func _quiet(base: Configs, unlocks: Array) -> Configs:
	var c := Tech.apply(base, unlocks)
	c.waves.base_budget = 0
	c.waves.budget_per_wave = 0
	c.waves.first_wave_delay = 1e12
	return c

func _place(w: GameWorld, type_id: String, pos: Vector2, hp_override: int, c: Configs) -> Enemy:
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
	return e

func _run(w: GameWorld, c: Configs, secs: float) -> void:
	for i in range(int(round(secs / DT))):
		Sim.step(w, DT, c)
		w.effects.clear()

func _run_input(w: GameWorld, c: Configs, secs: float, thrust: float, rudder: float) -> void:
	for i in range(int(round(secs / DT))):
		w.input.thrust = thrust
		w.input.rudder = rudder
		Sim.step(w, DT, c)
		w.effects.clear()

func _turn_delta(c: Configs) -> float:
	var w := GameWorld.new(13)
	_run_input(w, c, 12.0, 1.0, 0.0)
	var h0: float = w.ship_heading
	_run_input(w, c, 2.0, -1.0, 1.0)
	return w.ship_heading - h0

func _xp_for_level(pc: ProgressConfig, level: int) -> int:
	var xp: int = 0
	for n in range(1, level):
		xp += pc.xp_for_next(n)
	return xp

func _check(cond: bool, label: String) -> int:
	print(("  OK  " if cond else "  FAIL") + " — " + label)
	return 0 if cond else 1
