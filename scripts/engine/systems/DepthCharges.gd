class_name DepthCharges
extends RefCounted
# C5 depth-charge racks (docs/specs/sonar-subs.md; D1.11 as refined) — after Sonar in Sim.step's
# fixed order. Free, automatic, armed ONLY by a live sonar contact: a DETECTED sub inside dc_range
# rolls a volley of dc_count scattered charges; each sinks for dc_fuse then detonates (Projectiles'
# "dc" branch — subs only feel the underwater blast). Scatter draws from world.rng in volley order.
# DC REWORK 2026-07-10 (owner: too hard to land): the plot RANGES the pattern onto the detected
# contact (up to dc_range, at least dc_ring so it clears the hull) instead of blanketing the stern
# blind. Still scattered area denial — just centered where you found the contact. rng draw count
# per volley is UNCHANGED (2 per charge), so two-world determinism holds; only WHERE they land moves.

static func step(world: GameWorld, dt: float, cfg: Configs) -> void:
	world.dc_cool -= dt
	if world.dc_cool > 0.0:
		return
	var armed: bool = false
	var target: Vector2 = world.ship_pos
	for e in world.enemies:
		if e.active and e.layer == "sub" and Sonar.detected(world, e) \
				and e.pos.distance_to(world.ship_pos) <= cfg.sonar.dc_range:
			armed = true
			target = e.pos
			break
	if not armed and world.boss != null and Bosses.domain_of(world, cfg) == "sub" \
			and world.elapsed < world.boss.detected_until \
			and world.boss.pos.distance_to(world.ship_pos) <= cfg.sonar.dc_range:
		armed = true   # C7: a detected stalking GANDAREVA arms the racks too
		target = world.boss.pos
	if not armed:
		return
	world.dc_cool = cfg.sonar.dc_cooldown
	# range the pattern onto the contact: aim = ship + (contact−ship), clamped to dc_range reach and
	# to at least dc_ring so a close contact still lands clear of the hull. Degenerate (contact on
	# the ship) throws astern.
	var to_target: Vector2 = target - world.ship_pos
	var aim: Vector2
	if to_target.length() < 0.01:
		aim = world.ship_pos - Vector2(sin(world.ship_heading), -cos(world.ship_heading)) * cfg.sonar.dc_ring
	else:
		aim = world.ship_pos + to_target.normalized() * clampf(to_target.length(), cfg.sonar.dc_ring, cfg.sonar.dc_range)
	for i in range(cfg.sonar.dc_count):
		var ox: float = (world.rng.nextf() * 2.0 - 1.0) * cfg.sonar.dc_scatter
		var oy: float = (world.rng.nextf() * 2.0 - 1.0) * cfg.sonar.dc_scatter
		var drop: Vector2 = aim + Vector2(ox, oy)
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
	world.effects.append({ "type": "dcvolley", "pos": aim })
