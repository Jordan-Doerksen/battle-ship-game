class_name Enemies
extends RefCounted
# C3 enemy behavior (docs/specs/wave-director.md) — system #3 in Sim.step's fixed order, slot order.
# Divers (swarmer/bomber) pursue the ship under a per-type turn cap and damage the hull capsule on
# contact, dying in the dive. Gunboats approach to standoff, then orbit tangentially and fire led,
# dodgeable shells on their period — the only enemy draw is their per-shot spread.

static func step(world: GameWorld, dt: float, cfg: Configs) -> void:
	for e in world.enemies:
		if not e.active:
			continue
		var def: EnemyDef = cfg.enemies.by_id(e.type_id)
		if def == null:
			continue
		var dist_ship: float = e.pos.distance_to(world.ship_pos)
		var desired: float
		if def.standoff > 0.0:   # gunboat: approach, then orbit
			desired = _angle_to(e.pos, world.ship_pos) + (0.0 if dist_ship > def.standoff else PI / 2.0)
		else:
			desired = _angle_to(e.pos, world.ship_pos)
		e.heading += clampf(angle_difference(e.heading, desired), -def.turn * dt, def.turn * dt)
		e.pos += Vector2(sin(e.heading), -cos(e.heading)) * def.speed * dt
		if def.standoff > 0.0:
			e.cool -= dt
			if dist_ship <= def.fire_range and e.cool <= 0.0:
				e.cool = def.fire_period
				var flight: float = dist_ship / def.shell_speed
				var aim: Vector2 = world.ship_pos + world.ship_vel * flight * def.lead
				var ang: float = _angle_to(e.pos, aim) + (world.rng.nextf() * 2.0 - 1.0) * def.spread
				var p: Projectile = world.projectiles.obtain()
				p.pos = e.pos
				p.vel = Vector2(sin(ang), -cos(ang)) * def.shell_speed
				p.dmg = def.shell_dmg
				p.splash = 0.0
				p.hostile = true
				p.wid = "hostile"
				p.life = (def.fire_range * 1.4) / def.shell_speed
				world.effects.append({ "type": "gunflash", "pos": e.pos, "ang": ang })
		elif Hull.dist_to_hull(world, e.pos) <= def.radius + Hull.RADIUS:
			e.active = false   # the dive lands: hull pays, the drone is spent
			Hull.damage(world, def.dmg, cfg)
			world.effects.append({ "type": "death", "pos": e.pos, "layer": e.layer })

static func _angle_to(from: Vector2, to: Vector2) -> float:
	return atan2(to.x - from.x, -(to.y - from.y))
