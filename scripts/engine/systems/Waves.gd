class_name Waves
extends RefCounted
# C3 wave director (docs/specs/wave-director.md) — system #2 in Sim.step's fixed order. A seeded
# BUDGET DIRECTOR: each wave gets base + growth×(wave−1) threat points and spends them across
# unlocked enemy types with world.rng draws in ONE defined order (cluster count, cluster bearings,
# then per enemy: type, cluster, bearing jitter, ring distance). Enemies arrive beyond the view ring
# and physically close in (owner decision #7 — no warp telegraph; seeing them come IS the warning).
# Wave clears when every enemy dies; a lull follows; the next wave spends a bigger budget.

static func step(world: GameWorld, dt: float, cfg: Configs) -> void:
	var wc: WaveConfig = cfg.waves
	if world.hull < 0:                        # lazy one-time init from config (worlds start bare)
		world.hull = wc.hull_pips
	if world.lull_until < 0.0:
		world.lull_until = world.elapsed + wc.first_wave_delay
	if world.freeze_waves:                    # DEV test kit (debug builds): director paused
		return
	if world.wave_state == "lull":
		if world.elapsed >= world.lull_until:
			world.wave += 1
			_spawn_wave(world, cfg)
			world.wave_state = "fighting"
	else:
		var any_active: bool = false
		for e in world.enemies:
			if e.active:
				any_active = true
				break
		if not any_active and world.boss == null:   # a boss wave holds until the machine dies (C7)
			world.enemies.clear()
			world.xp_run += cfg.progress.xp_wave_bonus * world.wave   # wave-clear bonus (C4)
			world.effects.append({ "type": "waveclear", "wave": world.wave })
			world.wave_state = "lull"
			world.lull_until = world.elapsed + wc.lull_secs

static func _spawn_wave(world: GameWorld, cfg: Configs) -> void:
	var wc: WaveConfig = cfg.waves
	var budget: int = wc.base_budget + wc.budget_per_wave * (world.wave - 1)
	# C7 ladder: every Nth wave fields a war machine + a reduced escort
	var boss_wave: bool = cfg.bosses.every_n > 0 and world.wave % cfg.bosses.every_n == 0
	if boss_wave:
		var k: int = world.wave / cfg.bosses.every_n - 1
		var rung: int = k % cfg.bosses.defs.size()
		var lap: int = k / cfg.bosses.defs.size() + 1
		world.boss = Bosses.make_boss(world, cfg, rung, lap)
		world.effects.append({ "type": "klaxon", "name": cfg.bosses.defs[rung].display_name })
		budget = int(floor(budget * cfg.bosses.escort_frac))   # the machine has outriders
	var clusters: int = wc.cluster_min + int(floor(world.rng.nextf() * float(wc.cluster_max - wc.cluster_min + 1)))
	var bearings: Array[float] = []
	for i in range(clusters):
		bearings.append(world.rng.nextf() * TAU)
	while true:
		var unlocked: Array[EnemyDef] = []
		for d in cfg.enemies.roster:              # roster order is part of determinism
			if d.unlock <= world.wave and d.cost <= budget:
				unlocked.append(d)
		if unlocked.is_empty():
			break
		var def: EnemyDef = unlocked[int(floor(world.rng.nextf() * float(unlocked.size())))]
		budget -= def.cost
		var bearing: float = bearings[int(floor(world.rng.nextf() * float(clusters)))]
		var ang: float = bearing + (world.rng.nextf() - 0.5) * 0.5
		var dist: float = wc.spawn_ring_min + world.rng.nextf() * (wc.spawn_ring_max - wc.spawn_ring_min)
		var pos: Vector2 = world.ship_pos + Vector2(sin(ang), -cos(ang)) * dist
		# C15 — nothing arrives ON the rocks (or within 60 u of an edge): re-roll the along-ring
		# jitter + ring distance up to 8 times (world.rng draws, stable order — open water never
		# re-rolls, so pre-C15 streams are untouched), then nudge radially outward until clear
		# (pure arithmetic, capped — the field ends at ±extent, so outward always opens up).
		var rerolls: int = 0
		while rerolls < 8 and not Terrain.clear_of(world, pos, 60.0):
			rerolls += 1
			ang = bearing + (world.rng.nextf() - 0.5) * 0.5
			dist = wc.spawn_ring_min + world.rng.nextf() * (wc.spawn_ring_max - wc.spawn_ring_min)
			pos = world.ship_pos + Vector2(sin(ang), -cos(ang)) * dist
		var nudges: int = 0
		while nudges < 80 and not Terrain.clear_of(world, pos, 60.0):
			nudges += 1
			dist += 40.0
			pos = world.ship_pos + Vector2(sin(ang), -cos(ang)) * dist
		var e := Enemy.new()
		e.type_id = def.id
		e.layer = def.layer
		e.hp = def.hp
		e.hp_max = def.hp
		e.active = true
		e.pos = pos
		e.heading = atan2(world.ship_pos.x - e.pos.x, -(world.ship_pos.y - e.pos.y))
		world.enemies.append(e)
