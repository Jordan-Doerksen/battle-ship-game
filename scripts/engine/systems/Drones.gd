class_name Drones
extends RefCounted
# C2 practice-range targets (docs/specs/hardpoint-hull.md) — system #2 in Sim.step's fixed order.
# Drifting dumb drones in the air and surface layers; killed or culled slots respawn at range.
# Spawn position/heading/speed are GAMEPLAY randomness: 4 draws from world.rng per spawn, in slot
# order — the deterministic pattern the whole chunk hangs on. Slots are lazily sized to config so
# headless probes can run on a bare GameWorld.

static func step(world: GameWorld, dt: float, cfg: Configs) -> void:
	var rc: RangeConfig = cfg.gunnery
	var want: int = rc.air_count + rc.surf_count
	while world.drones.size() < want:
		var d := Drone.new()
		d.layer = "air" if world.drones.size() < rc.air_count else "surf"
		world.drones.append(d)
	if world.drones.size() > want:
		world.drones.resize(want)
	for d in world.drones:
		if not d.active:
			if world.elapsed >= d.respawn_at:
				_spawn(world, d, rc)
			continue
		d.pos += d.vel * dt
		if d.pos.distance_to(world.ship_pos) > rc.cull_dist:
			_spawn(world, d, rc)

static func _spawn(world: GameWorld, d: Drone, rc: RangeConfig) -> void:
	var ang: float = world.rng.nextf() * TAU
	var dist: float = rc.ring_min + world.rng.nextf() * (rc.ring_max - rc.ring_min)
	var head: float = world.rng.nextf() * TAU
	var spd_min: float = rc.air_spd_min if d.layer == "air" else rc.surf_spd_min
	var spd_max: float = rc.air_spd_max if d.layer == "air" else rc.surf_spd_max
	var spd: float = spd_min + world.rng.nextf() * (spd_max - spd_min)
	d.pos = world.ship_pos + Vector2(sin(ang), -cos(ang)) * dist
	d.vel = Vector2(sin(head), -cos(head)) * spd
	d.hp_max = rc.air_hp if d.layer == "air" else rc.surf_hp
	d.hp = d.hp_max
	d.active = true
