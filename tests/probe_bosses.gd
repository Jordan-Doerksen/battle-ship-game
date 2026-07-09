extends SceneTree
# C7 acceptance probe (docs/specs/boss-ladder.md §Acceptance) — mirrors the 8/8 validation harness
# that ran against the approved mockup: determinism through boss waves, the ladder cadence + lap
# scaling + waves-1-4 baseline, soft-gated cores, parts + phases + rewards, the domain tour, the
# lifecycle hold, and the naming pass. Also gates the C7 owner tune: the K-gun spread pattern.
# Checks 9-11 gate the post-build projectile-vs-machine fixes: burst-point part attribution,
# dp5 flak fusing off a machine (never a submerged one), and the CANOPY's bay-bomb splash.

const DT: float = 1.0 / 60.0

func _initialize() -> void:
	var fails: int = 0

	# 1 — determinism: fight through the wave-5 machine, byte-identical twin worlds
	var c1 := Configs.defaults()
	c1.waves.first_wave_delay = 0.5
	c1.waves.lull_secs = 1.0
	c1.waves.hull_pips = 100000
	for wdef in c1.weapons.catalog:
		wdef.dmg = 60
	var wa := GameWorld.new(41)
	var wb := GameWorld.new(41)
	for i in range(60 * 240):
		var thrust: float = 1.0 if i % 400 < 120 else 0.0
		for w in [wa, wb]:
			w.input.thrust = thrust
			w.input.rudder = 1.0   # circle the fight: every wave stays catchable
			Sim.step(w, DT, c1)
			w.effects.clear()
		if wa.wave > 6:
			break
	var same: bool = wa.ship_pos == wb.ship_pos and wa.xp_run == wb.xp_run \
		and wa.kills == wb.kills and wa.hull == wb.hull \
		and (wa.boss == null) == (wb.boss == null)
	if wa.boss != null and wb.boss != null:
		same = same and wa.boss.pos == wb.boss.pos and wa.boss.core == wb.boss.core
	fails += _check(same and wa.rng.calls == wb.rng.calls and wa.wave > 5,
		"determinism: boss waves fought to wave %d byte-identical (rng.calls %d, kills %d)" % [wa.wave, wa.rng.calls, wa.kills])

	# 2 — cadence + ladder + baseline: 5/10/15 field the rungs, 20 laps at x1.5; waves 1-4 boss-free
	var c2 := Configs.defaults()
	c2.waves.first_wave_delay = 0.5
	c2.waves.lull_secs = 0.5
	c2.waves.hull_pips = 100000
	c2.enemies.by_id("sub").cost = 999999   # an idle ship can't prosecute subs — cadence is the test
	for wdef in c2.weapons.catalog:
		wdef.dmg = 4000
	var w2 := GameWorld.new(31)
	var seen := {}
	var last_wave: int = 0
	var boss_early: bool = false
	for i in range(60 * 900):
		Sim.step(w2, DT, c2)
		w2.effects.clear()
		if w2.boss != null and w2.wave != last_wave:
			seen[w2.wave] = { "id": Bosses.def_of(w2, c2).id, "lap": w2.boss.lap, "hp": w2.boss.core_max }
			last_wave = w2.wave
			if w2.wave % c2.bosses.every_n != 0:
				boss_early = true
		if w2.wave > 20:
			break
	var ok2: bool = seen.has(5) and seen[5]["id"] == "juggernaut" and seen[5]["lap"] == 1 \
		and seen.has(10) and seen[10]["id"] == "canopy" \
		and seen.has(15) and seen[15]["id"] == "maw" \
		and seen.has(20) and seen[20]["id"] == "juggernaut" and seen[20]["lap"] == 2 \
		and absf(seen[20]["hp"] - seen[5]["hp"] * 1.5) < 1e-4 and not boss_early
	fails += _check(ok2, "cadence+ladder: w5 %s, w10 %s, w15 %s, w20 %s lap2 hp x1.5; waves 1-4 boss-free" \
		% [seen.get(5, {}).get("id", "?"), seen.get(10, {}).get("id", "?"), seen.get(15, {}).get("id", "?"), seen.get(20, {}).get("id", "?")])

	# 3 — soft gate: 25% while a part lives, 100% once parts are gone
	var c3 := _quiet()
	var w3 := GameWorld.new(5)
	Sim.step(w3, DT, c3)
	var b3 := _place_boss(w3, c3, 0, 1, Vector2(0, -400))
	Bosses.damage(w3, c3, -1, 8.0)
	var gated: float = 40.0 - b3.core     # 2
	for i in range(b3.parts.size()):
		if not b3.parts[i]["dead"]:
			b3.parts[i]["hp"] = 0.0001
			Bosses.damage(w3, c3, i, 1.0)
	w3.effects.clear()
	var before: float = b3.core
	Bosses.damage(w3, c3, -1, 8.0)
	fails += _check(absf(gated - 2.0) < 1e-4 and absf((before - b3.core) - 8.0) < 1e-4,
		"soft gate: 8 dmg -> %.1f gated; 8 dmg -> %.1f with parts gone" % [gated, before - b3.core])

	# 4 — parts + phases: part death banks 60 XP, adds phase speed, vomits minions
	var c4 := _quiet()
	var w4 := GameWorld.new(7)
	Sim.step(w4, DT, c4)
	var b4 := _place_boss(w4, c4, 0, 1, Vector2(0, -400))
	var xp0: int = w4.xp_run
	var partfx: int = 0
	b4.parts[0]["hp"] = 0.001
	Bosses.damage(w4, c4, 0, 1.0)
	for e in w4.effects:
		if e["type"] == "partdown":
			partfx += 1
	w4.effects.clear()
	var minions: int = 0
	for e in w4.enemies:
		if e.active:
			minions += 1
	fails += _check(w4.xp_run - xp0 == c4.bosses.xp_part and partfx == 1 \
		and b4.speed_bonus == c4.bosses.defs[0].phase_speed and minions == c4.bosses.defs[0].phase_spawn_n,
		"parts+phases: +%d XP, +%.0f speed, %d GNATs vomited" % [w4.xp_run - xp0, b4.speed_bonus, minions])

	# 5 — domain tour: mb16 can't touch THE CANOPY; the deep answers to the racks alone
	var c5 := _quiet()
	c5.weapons.by_id("aa20").range_u = 0.0
	c5.weapons.by_id("dp5").range_u = 0.0
	var w5 := GameWorld.new(9)
	Sim.step(w5, DT, c5)
	var canopy := _place_boss(w5, c5, 1, 1, Vector2(0, -300))
	var hp0: float = canopy.core
	for i in range(int(round(10.0 / DT))):
		w5.input.force_large = true
		w5.input.aim_world = canopy.pos
		Sim.step(w5, DT, c5)
		w5.effects.clear()
	var canopy_safe: bool = canopy.core == hp0 and canopy.parts.all(func(p: Dictionary) -> bool: return p["hp"] == p["max"])
	var c5b := _quiet()
	var w5b := GameWorld.new(9)
	Sim.step(w5b, DT, c5b)
	_place_boss(w5b, c5b, 1, 1, Vector2(0, -300))
	_run(w5b, c5b, 10.0)
	var aa_bites: bool = w5b.boss == null or w5b.boss.core < w5b.boss.core_max \
		or w5b.boss.parts.any(func(p: Dictionary) -> bool: return p["hp"] < p["max"])
	var c5c := _quiet()
	c5c.sonar.dc_cooldown = 2.0
	var w5c := GameWorld.new(11)
	Sim.step(w5c, DT, c5c)
	var maw := _place_boss(w5c, c5c, 2, 1, Vector2(0, 150))   # astern — it will be heard
	maw.cycle_t = -1e9                                         # pinned submerged
	for i in range(int(round(12.0 / DT))):
		w5c.input.force_all = true
		w5c.input.aim_world = maw.pos
		Sim.step(w5c, DT, c5c)
		w5c.effects.clear()
	var guns_deaf: bool = maw.parts.all(func(p: Dictionary) -> bool: return p["hp"] == p["max"])
	var racks_bite: bool = maw.core < maw.core_max
	fails += _check(canopy_safe and aa_bites and guns_deaf and racks_bite,
		"domain tour: mb16 vs CANOPY 0 dmg; AA bites; submerged MAW cowls untouched, core chipped %.1f by the racks" % (maw.core_max - maw.core))

	# 6 — rewards: 250 x lap bounty + exactly +2 pips, capped; machine cleared
	var c6 := _quiet()
	var w6 := GameWorld.new(13)
	Sim.step(w6, DT, c6)
	var b6 := _place_boss(w6, c6, 0, 2, Vector2(0, -400))
	w6.hull = 5
	for part in b6.parts:
		part["dead"] = true
	var xp6: int = w6.xp_run
	Bosses.damage(w6, c6, -1, 99999.0)
	var paid: int = w6.xp_run - xp6
	var patched: int = w6.hull
	var w6b := GameWorld.new(13)
	Sim.step(w6b, DT, c6)
	var b6b := _place_boss(w6b, c6, 0, 1, Vector2(0, -400))
	for part in b6b.parts:
		part["dead"] = true
	Bosses.damage(w6b, c6, -1, 99999.0)
	fails += _check(paid == 500 and patched == 7 and w6b.hull == c6.waves.hull_pips and w6.boss == null,
		"rewards: lap-2 bounty %d XP; hull 5 -> %d (+2); patch capped; machine cleared" % [paid, patched])

	# 7 — K-gun spread (C7 owner tune): the volley blankets the aft arc — stations port beam →
	#     stern → starboard beam, none forward of amidships, spread across both sides
	var c7 := _quiet()
	c7.enemies.by_id("sub").speed = 0.0
	c7.enemies.by_id("sub").fire_range = 0.0
	c7.sonar.dc_scatter = 0.0   # stations only — the geometry is the test
	var w7 := GameWorld.new(15)
	Sim.step(w7, DT, c7)
	_place(w7, "sub", Vector2(0, 120), 999999, c7)
	_run(w7, c7, 1.0)   # one volley
	var port_side: int = 0
	var stbd_side: int = 0
	var forward: int = 0
	var n_dc: int = 0
	for i in range(w7.projectiles.items.size()):
		var p: Projectile = w7.projectiles.items[i]
		if not p.active or p.wid != "dc":
			continue
		n_dc += 1
		if p.pos.y < w7.ship_pos.y - 1.0:   # heading 0: forward = -y
			forward += 1
		if p.pos.x < -1.0:
			port_side += 1
		if p.pos.x > 1.0:
			stbd_side += 1
	fails += _check(n_dc == c7.sonar.dc_count and forward == 0 and port_side >= 1 and stbd_side >= 1,
		"K-gun spread: %d charges — %d port / %d starboard / %d forward of beam (want 0)" % [n_dc, port_side, stbd_side, forward])

	# 8 — names: every roster entry + machine carries its reporting name
	var c8 := Configs.defaults()
	var reps: Array[String] = []
	for d in c8.enemies.roster:
		reps.append(d.rep)
	var names_ok: bool = "/".join(reps) == "GNAT/JACKAL/VULTURE/LAMPREY"
	for d in c8.bosses.defs:
		names_ok = names_ok and d.display_name.begins_with("THE ")
	fails += _check(names_ok, "names: %s; machines %s, %s, %s" \
		% ["/".join(reps), c8.bosses.defs[0].display_name, c8.bosses.defs[1].display_name, c8.bosses.defs[2].display_name])

	# 9 — burst attribution: a splash burst AT an off-center part damages THAT part (the aft
	#     turret sits outside the 30u core disc), core + other parts untouched
	var c9 := _quiet()
	var w9 := GameWorld.new(17)
	Sim.step(w9, DT, c9)
	var b9 := _place_boss(w9, c9, 0, 1, Vector2(0, -400))
	var pp9 := Bosses.part_pos(b9, c9.bosses.defs[0], 1)   # AFT TURRET, hull-local (0, 34)
	_shell(w9, "mb16", pp9, 4, c9.weapons.by_id("mb16").splash, 0.0001, false)
	Projectiles.step(w9, DT, c9)
	var aft_hit: bool = absf(b9.parts[1]["hp"] - (b9.parts[1]["max"] - 4.0)) < 1e-4
	var rest9: bool = b9.parts[0]["hp"] == b9.parts[0]["max"] \
		and b9.parts[2]["hp"] == b9.parts[2]["max"] and b9.core == b9.core_max
	fails += _check(aft_hit and rest9,
		"burst attribution: mb16 burst at the aft turret -> that part -%.0f hp, core + others untouched" \
		% (b9.parts[1]["max"] - b9.parts[1]["hp"]))

	# 10 — dp5 flak vs the machines: the proximity fuse triggers off a surfaced/air machine and
	#      the burst bites (soft-gated 25%); the submerged MAW neither triggers nor feels it
	var c10 := _quiet()
	c10.tech.airburst = true
	var w10 := GameWorld.new(19)
	Sim.step(w10, DT, c10)
	var b10 := _place_boss(w10, c10, 1, 1, Vector2(0, -400))   # THE CANOPY — air domain
	var p10 := _shell(w10, "dp5", b10.pos + Vector2(0, c10.bosses.defs[1].radius + 4.0), 2, 0.0, 5.0, false)
	Projectiles.step(w10, DT, c10)
	var flak_bites: bool = absf((b10.core_max - b10.core) - 2.0 * 0.25) < 1e-4 and not p10.active
	var c10b := _quiet()
	c10b.tech.airburst = true
	var w10b := GameWorld.new(19)
	Sim.step(w10b, DT, c10b)
	var maw10 := _place_boss(w10b, c10b, 2, 1, Vector2(0, -400))   # THE MAW — spawns submerged
	var p10b := _shell(w10b, "dp5", maw10.pos, 2, 0.0, 5.0, false)
	Projectiles.step(w10b, DT, c10b)
	var deep_deaf: bool = maw10.core == maw10.core_max and p10b.active \
		and maw10.parts.all(func(p: Dictionary) -> bool: return p["hp"] == p["max"])
	fails += _check(flak_bites and deep_deaf,
		"dp5 flak vs machines: CANOPY core chipped %.2f by an airburst; submerged MAW ignored (shell flies on)" \
		% (b10.core_max - b10.core))

	# 11 — bay-bomb splash: a burst inside the blast radius hurts the hull, outside does not;
	#      and the CANOPY's bays actually lob splash bombs
	var c11 := _quiet()
	var bomb_splash: float = c11.bosses.defs[1].bomb_splash   # THE CANOPY's blast radius, from config
	var w11 := GameWorld.new(21)
	Sim.step(w11, DT, c11)
	_shell(w11, "hostile", Vector2(Hull.RADIUS + bomb_splash - 2.0, 0.0), 2, bomb_splash, 0.0001, true)
	var hull0: int = w11.hull
	Projectiles.step(w11, DT, c11)
	var splashed: bool = w11.hull == hull0 - 2
	var w11b := GameWorld.new(21)
	Sim.step(w11b, DT, c11)
	_shell(w11b, "hostile", Vector2(Hull.RADIUS + bomb_splash + 30.0, 0.0), 2, bomb_splash, 0.0001, true)
	var hull0b: int = w11b.hull
	Projectiles.step(w11b, DT, c11)
	var missed: bool = w11b.hull == hull0b
	var w11c := GameWorld.new(23)
	Sim.step(w11c, DT, c11)
	_place_boss(w11c, c11, 1, 1, Vector2(0, -300))   # in bay range — both bays fire next step
	Sim.step(w11c, DT, c11)
	var bombs: int = 0
	for i in range(w11c.projectiles.items.size()):
		var pb: Projectile = w11c.projectiles.items[i]
		if pb.active and pb.hostile and pb.splash == bomb_splash:
			bombs += 1
	fails += _check(splashed and missed and bombs == 2,
		"bay-bomb splash: hull %d -> %d inside the blast, untouched outside; %d splash bombs lobbed" \
		% [hull0, w11.hull, bombs])

	if fails == 0:
		print("PROBE_BOSSES PASSED")
	else:
		print("PROBE_BOSSES FAILED (%d check(s))" % fails)
	quit(fails)

func _quiet() -> Configs:
	var c := Configs.defaults()
	c.waves.base_budget = 0
	c.waves.budget_per_wave = 0
	c.waves.first_wave_delay = 1e12
	return c

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

# craft a stationary in-flight shell straight into the pool — checks 9-11 place bursts exactly
func _shell(w: GameWorld, wid: String, pos: Vector2, dmg: int, splash: float, life: float, hostile: bool) -> Projectile:
	var p: Projectile = w.projectiles.obtain()
	p.pos = pos
	p.vel = Vector2.ZERO
	p.dmg = dmg
	p.splash = splash
	p.life = life
	p.wid = wid
	p.hostile = hostile
	return p

func _run(w: GameWorld, c: Configs, secs: float) -> void:
	for i in range(int(round(secs / DT))):
		Sim.step(w, DT, c)
		w.effects.clear()

func _check(cond: bool, label: String) -> int:
	print(("  OK  " if cond else "  FAIL") + " — " + label)
	return 0 if cond else 1
