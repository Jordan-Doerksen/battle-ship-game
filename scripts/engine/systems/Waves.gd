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
		if not any_active:
			world.enemies.clear()
			world.xp_run += cfg.progress.xp_wave_bonus * world.wave   # wave-clear bonus (C4)
			world.effects.append({ "type": "waveclear", "wave": world.wave })
			world.wave_state = "lull"
			world.lull_until = world.elapsed + wc.lull_secs

static func _spawn_wave(world: GameWorld, cfg: Configs) -> void:
	var wc: WaveConfig = cfg.waves
	var budget: int = wc.base_budget + wc.budget_per_wave * (world.wave - 1)
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
		var e := Enemy.new()
		e.type_id = def.id
		e.layer = def.layer
		e.hp = def.hp
		e.hp_max = def.hp
		e.active = true
		e.pos = world.ship_pos + Vector2(sin(ang), -cos(ang)) * dist
		e.heading = atan2(world.ship_pos.x - e.pos.x, -(world.ship_pos.y - e.pos.y))
		world.enemies.append(e)
