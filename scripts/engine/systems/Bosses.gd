class_name Bosses
extends RefCounted
# C7 war machines (docs/specs/boss-ladder.md) — stepped after Enemies in Sim.step's fixed order.
# One machine at a time (world.boss): gunboat-pattern movement brain, hull-relative destructible
# PARTS, phase changes on part loss, a soft-gated core (25% while any part lives), and per-machine
# attacks — JUGGERNAUT led heavy shells (panic-fires when its director dies), CANOPY bomb bays +
# drone hive, MAW torpedo fans on a dive/breach cycle. All randomness through world.rng in fixed
# order: attack spreads, minion bearings. Rewards: xp_part on the spot, xp_core × lap + hull patch.

# which weapons may STRIKE a machine, by wid — machines respect domain tags physically (the
# CANOPY flies above flat naval fire; the deep is deaf). Drones keep D1.9 physical hits.
const WPN_DOMAINS := {
	"aa20": ["air"], "dp5": ["air", "surface"], "mb16": ["surface"],
	"doorgun": ["air", "surface"], "dc": ["sub"],
}

static func make_boss(world: GameWorld, cfg: Configs, rung: int, lap: int) -> Boss:
	var def: BossDef = cfg.bosses.defs[rung]
	var mult: float = pow(cfg.bosses.lap_hp_mult, lap - 1)
	var ang: float = world.rng.nextf() * TAU
	var dist: float = cfg.waves.spawn_ring_min \
		+ world.rng.nextf() * (cfg.waves.spawn_ring_max - cfg.waves.spawn_ring_min)
	var b := Boss.new()
	b.rung = rung
	b.lap = lap
	b.pos = world.ship_pos + Vector2(sin(ang), -cos(ang)) * dist
	b.core = def.core_hp * mult
	b.core_max = def.core_hp * mult
	for pd in def.parts:
		b.parts.append({ "hp": pd["hp"] * mult, "max": pd["hp"] * mult, "dead": false, "cool": 0.0 })
	b.submerged = def.id == "maw"
	return b

static func def_of(world: GameWorld, cfg: Configs) -> BossDef:
	return cfg.bosses.defs[world.boss.rung]

static func domain_of(world: GameWorld, cfg: Configs) -> String:
	var def := def_of(world, cfg)
	if def.id == "maw":
		return "sub" if world.boss.submerged else "surface"
	return "air" if def.layer == "air" else "surface"

static func part_pos(b: Boss, def: BossDef, i: int) -> Vector2:
	var pd: Dictionary = def.parts[i]
	return b.pos + Vector2(pd["ox"], pd["oy"]).rotated(b.heading)

static func parts_exposed(world: GameWorld, cfg: Configs) -> bool:
	return not (def_of(world, cfg).id == "maw" and world.boss.submerged)

static func damage(world: GameWorld, cfg: Configs, part_i: int, dmg: float) -> void:
	var b: Boss = world.boss
	var def := def_of(world, cfg)
	if part_i >= 0:
		var part: Dictionary = b.parts[part_i]
		part["hp"] -= dmg
		var pp := part_pos(b, def, part_i)
		if part["hp"] <= 0.0 and not part["dead"]:
			part["dead"] = true
			world.xp_run += cfg.bosses.xp_part   # banked on the spot
			world.effects.append({ "type": "partdown", "pos": pp, "name": def.parts[part_i]["pn"] })
			if def.id == "juggernaut":
				b.speed_bonus += def.phase_speed
				for i in range(def.phase_spawn_n):
					_spawn_minion(world, cfg, def.phase_spawn, pp)
			elif def.id == "canopy":
				b.rate_mult *= def.phase_rate
				if def.parts[part_i]["role"] == "hive":
					for i in range(def.hive_death_n):
						_spawn_minion(world, cfg, def.hive_death_spawn, pp)
			elif def.id == "maw":
				b.breach_bonus += def.breach_ext   # it can't seal
		elif part["hp"] > 0.0:
			world.effects.append({ "type": "hit", "pos": pp })
		return
	# the core: soft gate — 25% while any part lives (MAW cowls count even while hidden)
	var gated: bool = false
	for part in b.parts:
		if not part["dead"]:
			gated = true
			break
	b.core -= dmg * (0.25 if gated else 1.0)
	world.effects.append({ "type": "hit", "pos": b.pos })
	if b.core <= 0.0:
		world.kills += 1
		world.xp_run += cfg.bosses.xp_core * b.lap                                  # lap-scaled bounty
		world.hull = mini(cfg.waves.hull_pips, world.hull + cfg.bosses.hull_patch)  # the breather
		world.effects.append({ "type": "bossdown", "pos": b.pos, "name": def.display_name })
		world.boss = null

# friendly projectile vs the machine: exposed parts first, then the hull core. Returns true on a
# strike. Domain tags gate the strike (C7 machine rule; probe-gated).
static func strike(world: GameWorld, cfg: Configs, p_pos: Vector2, p_dmg: float, domains: Array) -> bool:
	var b: Boss = world.boss
	if b == null:
		return false
	var dom := domain_of(world, cfg)
	if dom == "sub" or not domains.has(dom):
		return false
	var def := def_of(world, cfg)
	if parts_exposed(world, cfg):
		for i in range(def.parts.size()):
			if b.parts[i]["dead"]:
				continue
			var pp := part_pos(b, def, i)
			if pp.distance_to(p_pos) <= def.parts[i]["r"] + 2.0:
				damage(world, cfg, i, p_dmg)
				return true
	if b.pos.distance_to(p_pos) <= def.radius + 2.0:
		damage(world, cfg, -1, p_dmg)
		return true
	return false

static func _spawn_minion(world: GameWorld, cfg: Configs, type_id: String, at: Vector2) -> void:
	var def: EnemyDef = cfg.enemies.by_id(type_id)
	if def == null:
		return
	var e := Enemy.new()
	e.type_id = def.id
	e.layer = def.layer
	e.active = true
	e.hp = def.hp
	e.hp_max = def.hp
	var ang: float = world.rng.nextf() * TAU
	e.pos = at + Vector2(sin(ang), -cos(ang)) * 60.0
	e.heading = atan2(world.ship_pos.x - e.pos.x, -(world.ship_pos.y - e.pos.y))
	world.enemies.append(e)

static func step(world: GameWorld, dt: float, cfg: Configs) -> void:
	var b: Boss = world.boss
	if b == null:
		return
	var def := def_of(world, cfg)
	# movement: approach, then orbit at standoff
	var dist_ship: float = b.pos.distance_to(world.ship_pos)
	var desired: float = _angle_to(b.pos, world.ship_pos) \
		+ (0.0 if dist_ship > def.standoff else PI / 2.0)
	b.heading += clampf(angle_difference(b.heading, desired), -def.turn * dt, def.turn * dt)
	b.pos += Vector2(sin(b.heading), -cos(b.heading)) * (def.speed + b.speed_bonus) * dt
	if def.id == "juggernaut":
		var director_dead: bool = b.parts[2]["dead"]
		for i in range(2):
			var part: Dictionary = b.parts[i]
			if part["dead"]:
				continue
			part["cool"] -= dt
			if dist_ship <= def.standoff + 250.0 and part["cool"] <= 0.0:
				part["cool"] = def.fire_period / (def.panic_rate if director_dead else 1.0)
				var pp := part_pos(b, def, i)
				var flight: float = dist_ship / def.shell_speed
				var aim: Vector2 = world.ship_pos + world.ship_vel * flight * def.lead
				var ang: float = _angle_to(pp, aim) + (world.rng.nextf() * 2.0 - 1.0) * def.spread
				var dir := Vector2(sin(ang), -cos(ang))
				var p: Projectile = world.projectiles.obtain()
				p.pos = pp + dir * 16.0
				p.vel = dir * def.shell_speed
				p.dmg = def.shell_dmg
				p.splash = 0.0
				p.hostile = true
				p.wid = "hostile"
				p.life = 900.0 / def.shell_speed
				world.effects.append({ "type": "gunflash", "pos": pp, "ang": ang })
	elif def.id == "canopy":
		for i in range(2):
			var part: Dictionary = b.parts[i]
			if part["dead"]:
				continue
			part["cool"] -= dt
			if dist_ship <= def.standoff + 220.0 and part["cool"] <= 0.0:
				part["cool"] = def.bay_period * b.rate_mult
				var pp := part_pos(b, def, i)
				var flight: float = dist_ship / def.bomb_speed
				var aim: Vector2 = world.ship_pos + world.ship_vel * flight * def.lead
				var ang: float = _angle_to(pp, aim) + (world.rng.nextf() * 2.0 - 1.0) * def.spread
				var dir := Vector2(sin(ang), -cos(ang))
				var p: Projectile = world.projectiles.obtain()
				p.pos = pp
				p.vel = dir * def.bomb_speed
				p.dmg = def.bomb_dmg
				p.splash = 0.0
				p.hostile = true
				p.wid = "hostile"
				p.life = minf(dist_ship, 800.0) / def.bomb_speed
				world.effects.append({ "type": "gunflash", "pos": pp, "ang": ang })
		if not b.parts[2]["dead"]:
			b.hive_cool -= dt
			if b.hive_cool <= 0.0:
				b.hive_cool = def.hive_period * b.rate_mult
				var hp := part_pos(b, def, 2)
				for i in range(def.hive_spawn_n):
					_spawn_minion(world, cfg, def.hive_spawn, hp)
	elif def.id == "maw":
		b.cycle_t += dt
		if b.submerged and b.cycle_t >= def.dive_secs:
			b.submerged = false
			b.cycle_t = 0.0
			world.effects.append({ "type": "breach", "pos": b.pos })
		elif not b.submerged and b.cycle_t >= def.breach_secs + b.breach_bonus:
			b.submerged = true
			b.cycle_t = 0.0
			world.effects.append({ "type": "dive", "pos": b.pos })
		if b.submerged:
			b.cool -= dt
			if dist_ship <= def.standoff + 300.0 and b.cool <= 0.0:
				b.cool = def.fire_period
				var flight: float = dist_ship / def.torp_speed
				var aim: Vector2 = world.ship_pos + world.ship_vel * flight * def.lead
				var base: float = _angle_to(b.pos, aim)
				for i in range(def.torp_fan):   # the fan: spread arms + per-torp wobble
					var off: float = (i - (def.torp_fan - 1) / 2.0) \
						* (def.fan_arc / maxf(1.0, def.torp_fan - 1) * 2.0)
					var ang: float = base + off + (world.rng.nextf() * 2.0 - 1.0) * def.spread
					var dir := Vector2(sin(ang), -cos(ang))
					var p: Projectile = world.projectiles.obtain()
					p.pos = b.pos + dir * 30.0
					p.vel = dir * def.torp_speed
					p.dmg = def.torp_dmg
					p.splash = 0.0
					p.hostile = true
					p.wid = "torpedo"
					p.life = def.torp_run / def.torp_speed
				if cfg.tech.helo:   # the bird heard the launch
					world.helo_mark = b.pos
					world.helo_mark_until = world.elapsed + cfg.airwing.investigate_hold

static func _angle_to(from: Vector2, to: Vector2) -> float:
	return atan2(to.x - from.x, -(to.y - from.y))
