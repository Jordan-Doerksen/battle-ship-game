extends SceneTree
# C5 acceptance probe (docs/specs/sonar-subs.md §Acceptance) — mirrors the validation harness that
# ran against the approved mockup: determinism with subs/torpedoes/DC volleys in play, deaf guns
# (domain exclusion), detection + contact latch, the owner's DC trigger law (contact-gated), the
# DC kill with surface/hull isolation, torpedo behavior, SONAR tree derivation, zero-tech
# baseline (waves 1–6 stay sub-free; the director CAN field subs once unlocked), and latch
# precedence (a MAD GEAR permanent latch survives ship-sonar passes — extend, never shorten).

const DT: float = 1.0 / 60.0

func _initialize() -> void:
	var fails: int = 0

	# 1 — determinism: 3600 scripted ticks with subs, torpedoes, and DC volleys => byte-identical
	var c1 := _quiet()
	c1.enemies.by_id("sub").speed = 20.0
	var wa := _sub_world(55, c1)
	var wb := _sub_world(55, c1)
	for i in range(3600):
		for w in [wa, wb]:
			w.input.thrust = 1.0 if i % 600 < 300 else -1.0
			w.input.rudder = 1.0 if i % 400 < 200 else 0.0
			Sim.step(w, DT, c1)
			w.effects.clear()
	var same: bool = wa.ship_pos == wb.ship_pos and wa.hull == wb.hull and wa.xp_run == wb.xp_run \
		and wa.dc_cool == wb.dc_cool and wa.enemies.size() == wb.enemies.size()
	for i in range(wa.enemies.size()):
		same = same and wa.enemies[i].pos == wb.enemies[i].pos \
			and wa.enemies[i].detected_until == wb.enemies[i].detected_until
	fails += _check(same and wa.rng.calls == wb.rng.calls,
		"determinism: 3600 ticks with subs/torpedoes/DC byte-identical (rng.calls %d, hull %d)" % [wa.rng.calls, wa.hull])

	# 2 — deaf guns: a lone sub inside every gun's range draws ZERO muzzle effects in auto, AND
	#     shells force-fired straight through it pass over (physical immunity — the deep is deaf)
	var c2 := _quiet()
	c2.enemies.by_id("sub").speed = 0.0
	c2.enemies.by_id("sub").fire_range = 0.0
	var w2 := GameWorld.new(5)
	Sim.step(w2, DT, c2)
	_place(w2, "sub", Vector2(0, -200), 999999, c2)
	var muzzles: int = _count_fx(w2, c2, 8.0, "muzzle")
	w2.input.force_all = true
	w2.input.aim_world = Vector2(0, -200)
	_run(w2, c2, 6.0)
	w2.input.force_all = false
	var sub_hp: int = w2.enemies[0].hp
	fails += _check(muzzles == 0 and sub_hp == 999999,
		"deaf guns: %d muzzles in auto; force-fire through the sub left hp %d (shells fly over the deep)" % [muzzles, sub_hp])

	# 3 — detection + latch: outside radius = silent; inside = one contact ping; latch holds
	#     contact_hold after it vanishes, then drops
	var c3 := _quiet()
	c3.enemies.by_id("sub").speed = 0.0
	var w3 := GameWorld.new(7)
	Sim.step(w3, DT, c3)
	_place(w3, "sub", Vector2(0, -600), 999999, c3)   # outside radius 350
	var sub3: Enemy = w3.enemies[0]
	var contacts: int = _count_fx(w3, c3, 2.0, "contact")
	var before: bool = Sonar.detected(w3, sub3) or contacts > 0
	sub3.pos = Vector2(0, -200)                        # step inside
	contacts += _count_fx(w3, c3, 0.5, "contact")
	var inside: bool = Sonar.detected(w3, sub3) and contacts == 1
	sub3.pos = Vector2(0, -3000)                       # vanish beyond everything
	_run(w3, c3, c3.sonar.contact_hold - 0.3)
	var held: bool = Sonar.detected(w3, sub3)
	_run(w3, c3, 0.6)
	var dropped: bool = not Sonar.detected(w3, sub3)
	fails += _check(not before and inside and held and dropped,
		"detection+latch: silent outside; 1 ping inside; latch held %.1fs after exit then dropped" % c3.sonar.contact_hold)

	# 4 — DC trigger law (owner rule): an UNDETECTED sub at point-blank never triggers a volley;
	#     a detected one volleys on cadence; detonation lands at dc_fuse
	var blind := _quiet()
	blind.enemies.by_id("sub").speed = 0.0
	blind.sonar.radius = 0.0   # deaf ship
	var w4a := GameWorld.new(9)
	Sim.step(w4a, DT, blind)
	_place(w4a, "sub", Vector2(0, -100), 999999, blind)
	var v_blind: int = _count_fx(w4a, blind, 12.0, "dcvolley")
	var c4 := _quiet()
	c4.enemies.by_id("sub").speed = 0.0
	var w4 := GameWorld.new(9)
	Sim.step(w4, DT, c4)
	_place(w4, "sub", Vector2(0, -100), 999999, c4)
	var volleys: int = 0
	var blasts: int = 0
	var volley_at: float = -1.0
	var blast_at: float = -1.0
	for i in range(int(round(9.0 / DT))):
		Sim.step(w4, DT, c4)
		for e in w4.effects:
			if e["type"] == "dcvolley":
				volleys += 1
				if volley_at < 0.0:
					volley_at = w4.elapsed
			if e["type"] == "dcblast":
				blasts += 1
				if blast_at < 0.0:
					blast_at = w4.elapsed
		w4.effects.clear()
	# the final volley's charges may still be sinking at the window's edge — only full-fuse
	# volleys are guaranteed detonated
	var cadence_ok: bool = volleys >= 2 and volleys <= 3   # 9s / 4s cooldown
	var fuse_ok: bool = absf((blast_at - volley_at) - c4.sonar.dc_fuse) < 0.1
	fails += _check(v_blind == 0 and cadence_ok and blasts >= 2 * c4.sonar.dc_count and fuse_ok,
		"DC law: blind ship 0 volleys point-blank; sighted %d volleys, %d blasts, fuse %.2fs" % [volleys, blasts, blast_at - volley_at])

	# 5 — DC kill + isolation: volleys kill the sub (banking its 80 XP); a surface gunboat in the
	#     same water and the ship's hull are untouched. Guns + all enemy fire disarmed so the ONLY
	#     damage source in the water is the depth-charge blasts.
	var c5 := _quiet()
	c5.enemies.by_id("sub").speed = 0.0
	c5.enemies.by_id("sub").fire_range = 0.0
	c5.enemies.by_id("gunboat").speed = 0.0
	c5.enemies.by_id("gunboat").fire_range = 0.0
	for wdef in c5.weapons.catalog:
		wdef.range_u = 0.0
	var w5 := GameWorld.new(11)
	Sim.step(w5, DT, c5)
	_place(w5, "sub", Vector2(0, 120), 0, c5)            # astern, in dc_range — stock hp 6
	_place(w5, "gunboat", Vector2(30, 120), 0, c5)
	var gb: Enemy = w5.enemies[1]
	var sub_dead: bool = false
	for i in range(int(round(20.0 / DT))):
		Sim.step(w5, DT, c5)
		for e in w5.effects:
			if e["type"] == "death" and e["layer"] == "sub":
				sub_dead = true
		w5.effects.clear()
	fails += _check(sub_dead and gb.active and gb.hp == c5.enemies.by_id("gunboat").hp \
		and w5.hull == c5.waves.hull_pips and w5.xp_run == c5.progress.xp_sub,
		"DC kill+isolation: sub killed (+%d XP); gunboat untouched (hp %d); hull %d/%d" % [w5.xp_run, gb.hp, w5.hull, c5.waves.hull_pips])

	# 6 — torpedo: fires on period, a hit costs exactly 2 pips through grace; a stern chase at
	#     full ahead never connects (130 u/s torpedo vs 220 u/s ship)
	var c6 := _quiet()
	c6.enemies.by_id("sub").speed = 0.0
	var w6 := GameWorld.new(13)
	Sim.step(w6, DT, c6)
	_place(w6, "sub", Vector2(0, -600), 999999, c6)
	_run(w6, c6, 14.0)
	var hits: int = c6.waves.hull_pips - w6.hull
	var torpedo_ok: bool = hits >= 2 and hits % 2 == 0
	var c6b := _quiet()
	c6b.enemies.by_id("sub").speed = 0.0
	var w6b := GameWorld.new(15)
	Sim.step(w6b, DT, c6b)
	_place(w6b, "sub", Vector2(0, 700), 999999, c6b)     # dead astern
	for i in range(int(round(20.0 / DT))):
		w6b.input.thrust = 1.0
		Sim.step(w6b, DT, c6b)
		w6b.effects.clear()
	fails += _check(torpedo_ok and w6b.hull == c6b.waves.hull_pips,
		"torpedo: stationary ship lost %d pips in 14s (2 per hit); full-ahead stern chase hull %d/%d" % [hits, w6b.hull, c6b.waves.hull_pips])

	# 7 — SONAR tree derivation: son1..son5 land exactly on the spec numbers
	var derived := Tech.apply(Configs.defaults(), ["son1", "son2", "son3", "son4", "son5"])
	var d_ok: bool = absf(derived.sonar.radius - 437.5) < 1e-4 \
		and absf(derived.sonar.contact_hold - 4.5) < 1e-4 \
		and derived.sonar.dc_count == 6 \
		and absf(derived.sonar.dc_cooldown - 2.8) < 1e-4 \
		and absf(derived.sonar.dc_scatter - 45.0) < 1e-4 \
		and absf(derived.sonar.dc_blast - 71.5) < 1e-4
	fails += _check(d_ok, "SONAR tree: radius %.1f, hold %.1f, count %d, cd %.1f, scatter %.0f, blast %.1f" \
		% [derived.sonar.radius, derived.sonar.contact_hold, derived.sonar.dc_count, derived.sonar.dc_cooldown, derived.sonar.dc_scatter, derived.sonar.dc_blast])

	# 8 — zero-tech baseline: waves 1–6 stay sub-free (unlock 7), so pre-C5 runs are untouched;
	#     and the director CAN field subs once the unlock gate opens (no dead roster entry)
	var c8 := Configs.defaults()
	c8.waves.lull_secs = 1.0
	c8.waves.first_wave_delay = 0.5
	c8.waves.hull_pips = 100000
	for wdef in c8.weapons.catalog:
		wdef.dmg = 500
	var w8 := GameWorld.new(31)
	var sub_early: bool = false
	var last_state: String = "lull"
	var waves_seen: int = 0
	for i in range(60 * 600):
		Sim.step(w8, DT, c8)
		w8.effects.clear()
		if last_state == "lull" and w8.wave_state == "fighting":
			waves_seen = w8.wave
			for e in w8.enemies:
				if e.type_id == "sub" and w8.wave < c8.enemies.by_id("sub").unlock:
					sub_early = true
		last_state = w8.wave_state
		if waves_seen >= 6:
			break
	var c8b := Configs.defaults()
	c8b.waves.first_wave_delay = 0.1
	c8b.waves.base_budget = 6
	c8b.waves.budget_per_wave = 0
	for def in c8b.enemies.roster:   # only the sub is affordable AND unlocked at wave 1
		if def.id != "sub":
			def.cost = 999999
	c8b.enemies.by_id("sub").unlock = 1
	var w8b := GameWorld.new(3)
	_run(w8b, c8b, 1.0)
	var subs_fielded: int = 0
	for e in w8b.enemies:
		if e.type_id == "sub" and e.active:
			subs_fielded += 1
	fails += _check(waves_seen >= 6 and not sub_early and subs_fielded == 1,
		"baseline: %d waves sub-free before unlock; director fields %d sub when it's the only pick (cost 6/budget 6)" % [waves_seen, subs_fielded])

	# 9 — latch precedence: a far-future latch (MAD GEAR's permanent 1e12 bird mark, AirWing.gd)
	#     survives ship-sonar passes over the same contact at BOTH write sites (enemy sub + submerged
	#     MAW) — the ship's ears may extend a latch, never shorten it ("bird latches never decay")
	var c9 := _quiet()
	c9.enemies.by_id("sub").speed = 0.0
	var w9 := GameWorld.new(17)
	Sim.step(w9, DT, c9)
	_place(w9, "sub", Vector2(0, -200), 999999, c9)          # inside radius 350 — pinged every tick
	var sub9: Enemy = w9.enemies[0]
	sub9.detected_until = 1e12                                # as AirWing writes under tech.mad_gear
	var maw9: Boss = _place_boss(w9, c9, 2, 1, Vector2(0, 200))
	maw9.cycle_t = -1e9                                       # pinned submerged — stays domain "sub"
	maw9.detected_until = 1e12
	_run(w9, c9, 2.0)
	fails += _check(sub9.detected_until >= 1e12 and maw9.detected_until >= 1e12,
		"latch precedence: 1e12 MAD latches survive 2s of ship sonar (sub %.0f, MAW %.0f)" \
		% [sub9.detected_until, maw9.detected_until])

	if fails == 0:
		print("PROBE_SONAR PASSED")
	else:
		print("PROBE_SONAR FAILED (%d check(s))" % fails)
	quit(fails)

func _quiet() -> Configs:
	var c := Configs.defaults()
	c.waves.base_budget = 0
	c.waves.budget_per_wave = 0
	c.waves.first_wave_delay = 1e12
	return c

func _sub_world(seed_val: int, c: Configs) -> GameWorld:
	var w := GameWorld.new(seed_val)
	Sim.step(w, DT, c)
	_place(w, "sub", Vector2(0, -300), 0, c)
	_place(w, "sub", Vector2(-500, 200), 0, c)
	return w

func _place_boss(w: GameWorld, c: Configs, rung: int, lap: int, pos: Vector2) -> Boss:
	var def: BossDef = c.bosses.defs[rung]
	var mult: float = pow(c.bosses.lap_hp_mult, lap - 1)
	var b := Boss.new()
	b.rung = rung
	b.lap = lap
	b.pos = pos
	b.core = def.core_hp * mult
	b.core_max = def.core_hp * mult
	for pd in def.parts:
		b.parts.append({ "hp": pd["hp"] * mult, "max": pd["hp"] * mult, "dead": false, "cool": 0.0 })
	b.submerged = def.id == "maw"
	w.boss = b
	return b

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

func _count_fx(w: GameWorld, c: Configs, secs: float, fx_type: String) -> int:
	var n: int = 0
	for i in range(int(round(secs / DT))):
		Sim.step(w, DT, c)
		for e in w.effects:
			if e["type"] == fx_type:
				n += 1
		w.effects.clear()
	return n

func _check(cond: bool, label: String) -> int:
	print(("  OK  " if cond else "  FAIL") + " — " + label)
	return 0 if cond else 1
