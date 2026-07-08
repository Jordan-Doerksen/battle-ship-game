class_name Projectiles
extends RefCounted
# Shells in flight (C2 spec + C3 revisions) — last system in Sim.step's fixed order.
# Friendly direct shells hit whatever enemy they physically reach (domain tags gate TARGETING only,
# D1.9). Friendly splash shells carry a PROXIMITY FUSE (C3 gate rev 2): they detonate on a close
# flyby of a surface enemy, else burst when their flight time expires (auto: at the intercept;
# forced: at full range along the bearing). Hostile shells test the hull capsule and go through
# Hull.damage (grace window applies). Kill bookkeeping banks world.kills and emits effects.

static func step(world: GameWorld, dt: float, cfg: Configs) -> void:
	var pool: Pool = world.projectiles
	for i in range(pool.items.size()):
		var p: Projectile = pool.items[i]
		if not p.active:
			continue
		p.pos += p.vel * dt
		p.life -= dt
		var dead: bool = p.life <= 0.0
		if p.hostile:
			if Hull.dist_to_hull(world, p.pos) <= Hull.RADIUS:
				Hull.damage(world, p.dmg, cfg)
				world.effects.append({ "type": "shiphit", "pos": p.pos })
				dead = true
		elif p.splash > 0.0:
			if not dead:   # proximity fuse: detonate on a close flyby of a surface enemy
				for e in world.enemies:
					if e.active and e.layer == "surf" \
						and e.pos.distance_to(p.pos) <= cfg.enemies.by_id(e.type_id).radius + 4.0:
						dead = true
						break
			if dead:
				world.effects.append({ "type": "splash", "pos": p.pos, "r": p.splash })
				for e in world.enemies:
					if e.active and e.layer == "surf" and e.pos.distance_to(p.pos) <= p.splash:
						_damage_enemy(world, e, p.dmg)
		else:
			for e in world.enemies:
				if not e.active:
					continue
				if e.pos.distance_to(p.pos) <= cfg.enemies.by_id(e.type_id).radius + 2.0:
					_damage_enemy(world, e, p.dmg)
					dead = true
					break
		if dead:
			pool.release(p)

static func _damage_enemy(world: GameWorld, e: Enemy, dmg: int) -> void:
	e.hp -= dmg
	if e.hp <= 0:
		e.active = false
		world.kills += 1
		world.effects.append({ "type": "death", "pos": e.pos, "layer": e.layer })
	else:
		world.effects.append({ "type": "hit", "pos": e.pos })
