class_name Projectiles
extends RefCounted
# C2 shells in flight (docs/specs/hardpoint-hull.md) — system #4 in Sim.step's fixed order.
# Direct shells hit whatever they physically reach (domain tags gate TARGETING only, D1.9);
# splash shells burst at their aim point and damage surface-layer drones in radius. Kills bank
# world.kills and start the slot's respawn timer. Pure arithmetic — no RNG draws.

const HIT_R_AIR: float = 8.0
const HIT_R_SURF: float = 12.0

static func step(world: GameWorld, dt: float, cfg: Configs) -> void:
	var pool: Pool = world.projectiles
	for i in range(pool.items.size()):
		var p: Projectile = pool.items[i]
		if not p.active:
			continue
		p.pos += p.vel * dt
		p.life -= dt
		var dead: bool = p.life <= 0.0
		if p.splash > 0.0:
			if dead:   # burst at the aim point
				world.effects.append({ "type": "splash", "pos": p.pos, "r": p.splash })
				for d in world.drones:
					if d.active and d.layer == "surf" and d.pos.distance_to(p.pos) <= p.splash:
						_damage(world, d, p.dmg, cfg.gunnery)
		else:
			for d in world.drones:
				if not d.active:
					continue
				var hit_r: float = HIT_R_AIR if d.layer == "air" else HIT_R_SURF
				if d.pos.distance_to(p.pos) <= hit_r:
					_damage(world, d, p.dmg, cfg.gunnery)
					dead = true
					break
		if dead:
			pool.release(p)

static func _damage(world: GameWorld, d: Drone, dmg: int, rc: RangeConfig) -> void:
	d.hp -= dmg
	if d.hp <= 0:
		d.active = false
		d.respawn_at = world.elapsed + rc.respawn
		world.kills += 1
		world.effects.append({ "type": "death", "pos": d.pos, "layer": d.layer })
	else:
		world.effects.append({ "type": "hit", "pos": d.pos })
