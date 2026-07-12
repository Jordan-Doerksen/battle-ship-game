class_name Sonar
extends RefCounted
# C5 passive sonar (docs/specs/sonar-subs.md; D1.10) — after Enemies in Sim.step's fixed order.
# Per sub: inside the sonar radius it becomes DETECTED, and the contact latches for `contact_hold`
# seconds after it slips back out (Enemy.detected_until carries the latch — pure arithmetic, no
# world.rng draws). A `contact` effect fires on first acquisition only (the HUD ping). Everything
# the HUD/render shows about subs keys off detected(); the ripple tell is render-only per D1.10.

static func step(world: GameWorld, _dt: float, cfg: Configs) -> void:
	for e in world.enemies:
		if not e.active or e.layer != "sub":
			continue
		# C17: weather shortens everyone's ears — the front's detect multiplier rides the radius
		if e.pos.distance_to(world.ship_pos) <= cfg.sonar.radius * world.wx_mult:
			if world.elapsed >= e.detected_until:
				world.effects.append({ "type": "contact", "pos": e.pos })
			# extend, never shorten: MAD GEAR's permanent (1e12) bird latches survive ship passes
			# (docs/specs/air-wing.md — "bird latches never decay")
			e.detected_until = maxf(e.detected_until, world.elapsed + cfg.sonar.contact_hold)
	# C7: a submerged MAW is a (huge) contact like any other
	var b: Boss = world.boss
	if b != null and Bosses.domain_of(world, cfg) == "sub" \
			and b.pos.distance_to(world.ship_pos) <= cfg.sonar.radius * world.wx_mult:
		if world.elapsed >= b.detected_until:
			world.effects.append({ "type": "contact", "pos": b.pos })
		b.detected_until = maxf(b.detected_until, world.elapsed + cfg.sonar.contact_hold)

static func detected(world: GameWorld, e: Enemy) -> bool:
	return world.elapsed < e.detected_until
