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
		if e.pos.distance_to(world.ship_pos) <= cfg.sonar.radius:
			if world.elapsed >= e.detected_until:
				world.effects.append({ "type": "contact", "pos": e.pos })
			e.detected_until = world.elapsed + cfg.sonar.contact_hold

static func detected(world: GameWorld, e: Enemy) -> bool:
	return world.elapsed < e.detected_until
