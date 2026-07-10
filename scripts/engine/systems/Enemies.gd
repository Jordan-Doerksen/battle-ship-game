class_name Enemies
extends RefCounted
# C3/C5 enemy behavior (docs/specs/{wave-director,sonar-subs}.md) — system #3 in Sim.step's fixed
# order, slot order. Divers (swarmer/bomber) pursue the ship under a per-type turn cap and damage
# the hull capsule on contact, dying in the dive. Standoff shooters (gunboat on the surface, sub in
# the deep) approach to standoff, then orbit tangentially and fire led, dodgeable projectiles on
# their period — the only enemy draw is their per-shot spread. A sub's "shell" is a TORPEDO
# (wid "torpedo"): slow, straight-running for torp_run units, no gunflash — the deep stays silent.

static func step(world: GameWorld, dt: float, cfg: Configs) -> void:
	for e in world.enemies:
		if not e.active:
			continue
		var def: EnemyDef = cfg.enemies.by_id(e.type_id)
		if def == null:
			continue
		# INCENDIARY LOAD (C4): burn ticks laid by aa20 hits
		if e.burn_left > 0 and world.elapsed >= e.next_burn:
			e.burn_left -= 1
			e.next_burn = world.elapsed + 1.0
			Projectiles.damage_enemy(world, e, cfg.tech.burn_dmg, cfg)
			if not e.active:
				continue
		var dist_ship: float = e.pos.distance_to(world.ship_pos)
		var desired: float
		if def.standoff > 0.0:   # standoff shooter: approach, then orbit
			desired = _angle_to(e.pos, world.ship_pos) + (0.0 if dist_ship > def.standoff else PI / 2.0)
		else:
			desired = _angle_to(e.pos, world.ship_pos)
		# C15 — waterborne hulls (surf + sub) give way around terrain: the mockup's tangent
		# avoidance with its sticky-side and inside-ring fixes (Terrain.avoid_heading), applied
		# as a heading adjustment BEFORE the turn cap. Air crosses land freely; open water
		# (empty terrain) skips the whole block, byte-identical to pre-C15.
		if def.layer != "air" and not world.terrain.is_empty():
			var av: float = Terrain.avoid_heading(world, e.pos, e.heading,
				cfg.terrain.avoid_look, def.radius + cfg.terrain.avoid_clear, e)
			if av != INF:
				desired = av
		e.heading += clampf(angle_difference(e.heading, desired), -def.turn * dt, def.turn * dt)
		e.pos += Vector2(sin(e.heading), -cos(e.heading)) * def.speed * dt
		if def.layer != "air" and not world.terrain.is_empty():
			e.pos = Terrain.push_out(world, e.pos, def.radius)   # hard safety: never park in a rock
		if def.standoff > 0.0:
			e.cool -= dt
			if dist_ship <= def.fire_range and e.cool <= 0.0:
				e.cool = def.fire_period
				var flight: float = dist_ship / def.shell_speed
				var aim: Vector2 = world.ship_pos + world.ship_vel * flight * def.lead
				var torp: bool = def.torp_run > 0.0   # torpedo carrier: the C5 sub, the AIR THREAT bomber
				# AIR THREAT: salvo > 1 is the WASP's unguided rocket ripple — every rocket draws its
				# own spread (world.rng, stable order); the wide cone + the 1.4× overfly life mean
				# misses straddle the water around you and overshoots sail right overtop
				for k in range(maxi(def.salvo, 1)):
					var ang: float = _angle_to(e.pos, aim) + (world.rng.nextf() * 2.0 - 1.0) * def.spread
					var p: Projectile = world.projectiles.obtain()
					p.pos = e.pos + Vector2(sin(ang), -cos(ang)) * 14.0   # muzzle/tube, not hull center
					p.vel = Vector2(sin(ang), -cos(ang)) * def.shell_speed
					p.dmg = def.shell_dmg
					p.splash = 0.0
					p.hostile = true
					p.wid = "torpedo" if torp else "hostile"
					# C15 land rule: air-layer shots fly over terrain — except torpedoes, which run
					# IN the water once dropped and die on rock whoever dropped them (Projectiles.gd's
					# wid gate outranks this flag for them)
					p.aerial = def.layer == "air"
					p.life = (def.torp_run if torp else def.fire_range * 1.4) / def.shell_speed
					if torp:   # C12 cosmetic-only append, no rng — the torpedo klaxon needs a trigger
						world.effects.append({ "type": "torpwater", "pos": p.pos })
				if not torp:   # no gunflash from under the water; one flash per salvo
					world.effects.append({ "type": "gunflash", "pos": e.pos, "ang": _angle_to(e.pos, aim) })
				if torp and cfg.tech.helo:   # C6: the bird heard the launch — worth investigating
					world.helo_mark = e.pos
					world.helo_mark_until = world.elapsed + cfg.airwing.investigate_hold
		elif Hull.dist_to_hull(world, e.pos) <= def.radius + Hull.RADIUS:
			e.active = false   # the dive lands: hull pays, the drone is spent
			Hull.damage(world, def.dmg, cfg)
			world.effects.append({ "type": "death", "pos": e.pos, "layer": e.layer })

static func _angle_to(from: Vector2, to: Vector2) -> float:
	return atan2(to.x - from.x, -(to.y - from.y))
