class_name DepthCharges
extends RefCounted
# C5 depth-charge racks (docs/specs/sonar-subs.md; D1.11 as refined by the owner at interview) —
# after Sonar in Sim.step's fixed order. Free, automatic, deliberately inaccurate — and armed ONLY
# by a live sonar contact: a DETECTED sub inside dc_range rolls a volley of dc_count charges at
# seeded scatter around the stern; each sinks for dc_fuse seconds then detonates (Projectiles.gd's
# "dc" branch — subs only feel the underwater blast). Scatter draws from world.rng in volley order.

const STERN_OFFSET: float = 80.0   # drop point aft of ship center, along the keel (hull geometry)

static func step(world: GameWorld, dt: float, cfg: Configs) -> void:
	world.dc_cool -= dt
	if world.dc_cool > 0.0:
		return
	var armed: bool = false
	for e in world.enemies:
		if e.active and e.layer == "sub" and Sonar.detected(world, e) \
				and e.pos.distance_to(world.ship_pos) <= cfg.sonar.dc_range:
			armed = true
			break
	if not armed and world.boss != null and Bosses.domain_of(world, cfg) == "sub" \
			and world.elapsed < world.boss.detected_until \
			and world.boss.pos.distance_to(world.ship_pos) <= cfg.sonar.dc_range:
		armed = true   # C7: a detected stalking MAW arms the racks too
	if not armed:
		return
	world.dc_cool = cfg.sonar.dc_cooldown
	var fwd := Vector2(sin(world.ship_heading), -cos(world.ship_heading))
	var stern: Vector2 = world.ship_pos - fwd * STERN_OFFSET
	# owner tune (C7 gate): a K-GUN SPREAD — throw stations evenly around the beams and stern
	# (port beam → stern → starboard beam), scatter jittering each station. The racks auto-fire
	# blind, so the pattern must blanket the aft arc, not pile on one point.
	for i in range(cfg.sonar.dc_count):
		var arc: float = PI / 2.0 + PI * (float(i) + 0.5) / float(cfg.sonar.dc_count)   # ship-local, 0 = bow
		var station: Vector2 = world.ship_pos \
			+ Vector2(sin(arc), -cos(arc)).rotated(world.ship_heading) * cfg.sonar.dc_ring
		var ox: float = (world.rng.nextf() * 2.0 - 1.0) * cfg.sonar.dc_scatter
		var oy: float = (world.rng.nextf() * 2.0 - 1.0) * cfg.sonar.dc_scatter
		var drop: Vector2 = station + Vector2(ox, oy)
		# C15 — a throw that lands ON a rock is a DUD: the charge never spawns. Deterministic —
		# the scatter draws above happen regardless, so the stream stays stable; a pure position
		# check adds no rng. Open water: blocked() is always false, byte-identical to pre-C15.
		if Terrain.blocked(world, drop):
			continue
		var p: Projectile = world.projectiles.obtain()
		p.pos = drop
		p.vel = world.ship_vel * 0.3   # charges carry a little way with the ship, then sink
		p.dmg = cfg.sonar.dc_dmg
		p.splash = 0.0
		p.hostile = false
		p.wid = "dc"
		p.aerial = false   # C15: charges live in the water; the dud rule above owns their land case
		p.life = cfg.sonar.dc_fuse
	world.effects.append({ "type": "dcvolley", "pos": stern })
