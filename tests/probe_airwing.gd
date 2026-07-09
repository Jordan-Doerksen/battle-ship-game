extends SceneTree
# C6 acceptance probe (docs/specs/air-wing.md §Acceptance) — mirrors the 10/10 validation harness
# that ran against the approved mockup: determinism with the bird hunting, zero-tech baseline
# inertness, extended ears, detector-first prosecution, the fuel loop, speed coupling (gate rev 1),
# MAD GEAR, tree derivation (incl. door gunners, gate rev 2), invulnerability by construction, and
# the door gunners' behavior (chip fire, short rounds, a deaf deep).

const DT: float = 1.0 / 60.0
const AIR_ALL := ["air1", "air2", "air3", "air4", "air5", "air6", "air7"]

func _initialize() -> void:
	var fails: int = 0

	# 1 — determinism: 3600 scripted ticks with the bird patrolling/prosecuting/dropping
	var c1 := _quiet(["air1"])
	c1.enemies.by_id("sub").speed = 20.0
	var wa := _sub_world(55, c1)
	var wb := _sub_world(55, c1)
	for i in range(3600):
		for w in [wa, wb]:
			w.input.thrust = 1.0 if i % 600 < 300 else -1.0
			w.input.rudder = 1.0 if i % 400 < 200 else 0.0
			Sim.step(w, DT, c1)
			w.effects.clear()
	var same: bool = wa.ship_pos == wb.ship_pos and wa.helo_pos == wb.helo_pos \
		and wa.helo_state == wb.helo_state and wa.helo_fuel == wb.helo_fuel \
		and wa.hull == wb.hull and wa.enemies.size() == wb.enemies.size()
	for i in range(wa.enemies.size()):
		same = same and wa.enemies[i].pos == wb.enemies[i].pos \
			and wa.enemies[i].detected_until == wb.enemies[i].detected_until
	fails += _check(same and wa.rng.calls == wb.rng.calls,
		"determinism: 3600 ticks with the bird hunting byte-identical (rng.calls %d, helo %s)" % [wa.rng.calls, wa.helo_state])

	# 2 — baseline inertness: zero tech = the system never touches state or RNG; the pad stays empty
	var c2 := _quiet([])
	c2.enemies.by_id("sub").speed = 25.0
	var w2 := _sub_world(21, c2)
	var calls_probe := GameWorld.new(21)   # twin WITHOUT the sub scenario? no — same scenario:
	for i in range(2400):
		w2.input.thrust = 1.0 if i % 500 < 250 else 0.0
		w2.input.rudder = -1.0 if i % 300 < 150 else 1.0
		Sim.step(w2, DT, c2)
		w2.effects.clear()
	var inert: bool = w2.helo_state == "pad" and w2.helo_fuel == 0.0 and w2.helo_phase == 0.0 \
		and w2.helo_pos == Vector2(0, 65) and w2.helo_mark_until == -1.0
	fails += _check(inert, "baseline: zero-tech 40s combat run leaves every helo field at init (pad stays empty)")

	# 3 — extended ears: the bird lights a sub far outside the ship's sonar ring
	var c3 := _quiet(["air1"])
	c3.enemies.by_id("sub").speed = 0.0
	var w3 := GameWorld.new(7)
	Sim.step(w3, DT, c3)
	_place(w3, "sub", Vector2(60, -500), 999999, c3)   # ~503u out; ship ears end at 350
	var contacts: int = _count_fx(w3, c3, 12.0, "contact")
	var sub3: Enemy = w3.enemies[0]
	var dist_ship: float = sub3.pos.distance_to(w3.ship_pos)
	fails += _check(contacts >= 1 and Sonar.detected(w3, sub3) and dist_ship > c3.sonar.radius,
		"extended ears: bird lit a sub at %du (ship ears %du): %d contact ping(s)" % [int(dist_ship), int(c3.sonar.radius), contacts])

	# 4 — detector-first prosecution: drops soften but never kill; the ship's racks finish it
	var c4 := _quiet(["air1"])
	c4.enemies.by_id("sub").speed = 0.0
	c4.enemies.by_id("sub").fire_range = 0.0
	var w4 := GameWorld.new(9)
	Sim.step(w4, DT, c4)
	_place(w4, "sub", Vector2(40, -c4.airwing.picket_dist), 0, c4)   # stock hp 6, on the bird's beat
	var sub4: Enemy = w4.enemies[0]
	var drops: int = _count_fx(w4, c4, 20.0, "helodrop")
	var soft_hp: int = sub4.hp
	var softened: bool = drops >= 2 and sub4.active and sub4.hp < 6 and sub4.hp > 0
	w4.ship_pos = sub4.pos + Vector2(0, -60)   # drive the hull over the contact
	var ship_kill: bool = false
	for i in range(int(round(20.0 / DT))):
		Sim.step(w4, DT, c4)
		for e in w4.effects:
			if e["type"] == "death" and e["layer"] == "sub":
				ship_kill = true
		w4.effects.clear()
	fails += _check(softened and ship_kill,
		"prosecution: %d drop(s), sub softened to hp %d but alive; ship racks finished it" % [drops, soft_hp])

	# 5 — fuel loop: ~patrol_secs airborne, ~turnaround_secs on the pad, relaunch
	var c5 := _quiet(["air1"])
	var w5 := GameWorld.new(11)
	var launch_t: float = -1.0
	var rtb_t: float = -1.0
	var land_t: float = -1.0
	var relaunch_t: float = -1.0
	var prev: String = "pad"
	for i in range(int(round(70.0 / DT))):
		Sim.step(w5, DT, c5)
		w5.effects.clear()
		if w5.helo_state != prev:
			match w5.helo_state:
				"air":
					if launch_t < 0.0: launch_t = w5.elapsed
					elif relaunch_t < 0.0: relaunch_t = w5.elapsed
				"rtb":
					if rtb_t < 0.0: rtb_t = w5.elapsed
				"pad":
					if land_t < 0.0: land_t = w5.elapsed
			prev = w5.helo_state
	var ok_air: bool = rtb_t > 0.0 and absf((rtb_t - launch_t) - c5.airwing.patrol_secs) < 0.5
	var ok_pad: bool = land_t > 0.0 and relaunch_t > 0.0 and absf((relaunch_t - land_t) - c5.airwing.turnaround_secs) < 0.5
	fails += _check(ok_air and ok_pad,
		"fuel loop: airborne %.1fs (want %.0f), pad %.1fs (want %.0f)" % [rtb_t - launch_t, c5.airwing.patrol_secs, relaunch_t - land_t, c5.airwing.turnaround_secs])

	# 6 — speed coupling (gate rev 1): 40s at flank — the bird is never LEFT astern. The weave dips
	#     transiently during its loops; the contract is recovery: from any dip it is back ahead of
	#     the bow within 5s, every time, and never further than a bounded excursion.
	var c6 := _quiet(["air1"])
	var w6 := GameWorld.new(19)
	Sim.step(w6, DT, c6)
	var min_along: float = INF
	var behind_secs: float = 0.0
	var worst_behind_secs: float = 0.0
	for i in range(int(round(40.0 / DT))):
		w6.input.thrust = 1.0
		Sim.step(w6, DT, c6)
		w6.effects.clear()
		if w6.helo_state == "air" and w6.elapsed > 8.0:
			var f := Vector2(sin(w6.ship_heading), -cos(w6.ship_heading))
			var along: float = (w6.helo_pos - w6.ship_pos).dot(f)
			min_along = minf(min_along, along)
			behind_secs = (behind_secs + DT) if along < 85.0 else 0.0   # 85 = bow (hull half-length)
			worst_behind_secs = maxf(worst_behind_secs, behind_secs)
	fails += _check(min_along < INF and min_along > -300.0 and worst_behind_secs < 5.0,
		"speed coupling: flank 40s — longest stretch behind the bow %.1fs (recovers <5s), worst dip %du (bounded)" % [worst_behind_secs, int(min_along)])

	# 7 — MAD GEAR: bird-made contacts never decay; ship-made contacts still do
	var c7 := _quiet(AIR_ALL)
	c7.enemies.by_id("sub").speed = 0.0
	c7.enemies.by_id("sub").fire_range = 0.0
	var w7 := GameWorld.new(13)
	Sim.step(w7, DT, c7)
	_place(w7, "sub", Vector2(0, -c7.airwing.picket_dist), 999999, c7)
	var bird_sub: Enemy = w7.enemies[0]
	_run(w7, c7, 8.0)
	var bird_latched: bool = Sonar.detected(w7, bird_sub)
	bird_sub.pos = Vector2(4000, 4000)
	_run(w7, c7, c7.sonar.contact_hold + 3.0)
	var bird_holds: bool = Sonar.detected(w7, bird_sub)
	_place(w7, "sub", Vector2(0, 300), 999999, c7)   # astern, inside ship ears; the bird is ahead
	var ship_sub: Enemy = w7.enemies[1]
	_run(w7, c7, 0.5)
	var ship_latched: bool = Sonar.detected(w7, ship_sub)
	ship_sub.pos = Vector2(-4000, -4000)
	_run(w7, c7, c7.sonar.contact_hold + 1.0)
	var ship_decayed: bool = not Sonar.detected(w7, ship_sub)
	fails += _check(bird_latched and bird_holds and ship_latched and ship_decayed,
		"MAD GEAR: bird contact held %.1fs past exit; ship contact decayed on schedule" % (c7.sonar.contact_hold + 3.0))

	# 8 — tree derivation (incl. gate rev 2): full column lands on spec numbers; 1-then-2 gunners
	var d := Tech.apply(Configs.defaults(), AIR_ALL)
	var d1 := Tech.apply(Configs.defaults(), ["air1", "air5"])
	var d_ok: bool = d.tech.helo and d.tech.mad_gear \
		and absf(d.airwing.dip_radius - 336.0) < 1e-4 \
		and absf(d.airwing.patrol_secs - 67.5) < 1e-4 \
		and absf(d.airwing.turnaround_secs - 6.0) < 1e-4 \
		and d.airwing.dc_count == 4 and d.airwing.gunners == 2 \
		and d1.airwing.gunners == 1
	var no_dead: bool = true
	for n in Configs.defaults().tech.catalog:
		if n.branch == "AIR WING" and (n.locked or n.cost <= 0 or n.mods.is_empty()):
			no_dead = false
	fails += _check(d_ok and no_dead,
		"tree: dip %.0f, patrol %.1f, pad %.1f, charges %d, gunners %d (1 then 2); no dead nodes" \
		% [d.airwing.dip_radius, d.airwing.patrol_secs, d.airwing.turnaround_secs, d.airwing.dc_count, d.airwing.gunners])

	# 9 — invulnerable by construction: 20s under gunboat + swarmer pressure, the helo runs its
	#     state machine untouched (no hp field exists to lose)
	var c9 := _quiet(["air1"])
	c9.enemies.by_id("gunboat").spread = 0.0
	var w9 := GameWorld.new(17)
	Sim.step(w9, DT, c9)
	_place(w9, "gunboat", Vector2(0, -600), 999999, c9)
	_place(w9, "swarmer", Vector2(200, -400), 999999, c9)
	var states_ok: bool = true
	for i in range(int(round(20.0 / DT))):
		Sim.step(w9, DT, c9)
		w9.effects.clear()
		if not (w9.helo_state == "pad" or w9.helo_state == "air" or w9.helo_state == "rtb"):
			states_ok = false
	fails += _check(states_ok, "invulnerable: 20s under fire — helo state machine only (%s)" % w9.helo_state)

	# 10 — door gunners (gate rev 2): chip fire at air/surface, short rounds slap the sea, and a
	#      sub in the same water draws ZERO damage (rack emptied for isolation; ship guns silent)
	var c10 := _quiet(["air1", "air2", "air3", "air4", "air5", "air6"])
	c10.enemies.by_id("swarmer").speed = 0.0
	c10.enemies.by_id("sub").speed = 0.0
	c10.enemies.by_id("sub").fire_range = 0.0
	c10.airwing.gun_range = 600.0   # the weave always keeps the target in reach for the test
	c10.airwing.dc_count = 0        # rack empty — gunfire is the ONLY channel that could touch the sub
	for wdef in c10.weapons.catalog:
		wdef.range_u = 0.0
	var w10 := GameWorld.new(23)
	Sim.step(w10, DT, c10)
	_place(w10, "swarmer", Vector2(0, -300), 999999, c10)
	_place(w10, "sub", Vector2(100, -300), 999999, c10)
	var splashes: int = _count_fx(w10, c10, 20.0, "gunsplash")
	var chipped: int = 999999 - w10.enemies[0].hp
	var sub_untouched: bool = w10.enemies[1].hp == 999999
	fails += _check(splashes > 0 and chipped > 0 and sub_untouched,
		"door gunners: %d rounds slapped the sea short, target chipped %d hp, the sub drew zero fire" % [splashes, chipped])

	if fails == 0:
		print("PROBE_AIRWING PASSED")
	else:
		print("PROBE_AIRWING FAILED (%d check(s))" % fails)
	quit(fails)

func _quiet(unlocked: Array) -> Configs:
	var c := Tech.apply(Configs.defaults(), unlocked)
	c.waves.base_budget = 0
	c.waves.budget_per_wave = 0
	c.waves.first_wave_delay = 1e12
	return c

func _sub_world(seed_val: int, c: Configs) -> GameWorld:
	var w := GameWorld.new(seed_val)
	Sim.step(w, DT, c)
	_place(w, "sub", Vector2(0, -500), 0, c)
	_place(w, "sub", Vector2(-600, 300), 0, c)
	return w

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
